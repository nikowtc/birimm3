// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/currency.dart';
import '../models/market_data.dart';
import '../models/rate_status.dart';
import '../services/app_storage.dart';
import '../services/equity_market_service.dart';
import '../services/market_service.dart';
import '../services/metal_market_service.dart';
import '../services/rate_service_exception.dart';

class MarketHistoryState {
  const MarketHistoryState({
    this.history,
    this.status = const RateOriginInfo.unavailable(),
    this.isLoading = false,
    this.errorMessage,
  });

  final PriceHistory? history;
  final RateOriginInfo status;
  final bool isLoading;
  final String? errorMessage;

  MarketHistoryState copyWith({
    PriceHistory? history,
    RateOriginInfo? status,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MarketHistoryState(
      history: history ?? this.history,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Independent state for paged crypto markets, stock/index and metal quotes,
/// and every chart cache.
///
/// Each provider keeps its own snapshot and status so one unavailable source
/// never hides the data other sources still return. [combinedSnapshot] and
/// [combinedStatus] are what the calculator consumes for conversion rates.
class MarketsController extends ChangeNotifier {
  MarketsController({
    required MarketDataService service,
    required AppStorage storage,
    EquityMarketService? equityService,
    MetalMarketService? metalService,
    this.autoRefreshInterval,
    DateTime Function()? clock,
  }) : _service = service,
       _storage = storage,
       _equityService = equityService,
       _metalService = metalService,
       _clock = clock ?? DateTime.now;

  static const int pageSize = 100;
  static const int maxPages = 5;

  final MarketDataService _service;
  final AppStorage _storage;
  final EquityMarketService? _equityService;
  final MetalMarketService? _metalService;
  final DateTime Function() _clock;
  final Duration? autoRefreshInterval;

  Timer? _autoRefreshTimer;
  bool _disposed = false;
  bool _initialized = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingEquities = false;
  bool _isLoadingMetals = false;

  MarketSnapshot? _snapshot;
  MarketSnapshot? _equitySnapshot;
  MarketSnapshot? _metalSnapshot;

  RateOriginInfo _status = const RateOriginInfo.unavailable();
  RateOriginInfo _equityStatus = const RateOriginInfo.unavailable();
  RateOriginInfo _metalStatus = const RateOriginInfo.unavailable();

  String? _errorMessage;
  String? _equityError;
  String? _metalError;
  MarketFailure? _equityFailure;
  MarketFailure? _metalFailure;

  final Map<String, MarketHistoryState> _historyStates = {};
  final Map<String, Future<PriceHistory?>> _historyRequests = {};

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingEquities => _isLoadingEquities;
  bool get isLoadingMetals => _isLoadingMetals;

  MarketSnapshot? get snapshot => _snapshot;
  MarketSnapshot? get equitySnapshot => _equitySnapshot;
  MarketSnapshot? get metalSnapshot => _metalSnapshot;

  List<MarketQuote> get quotes => _snapshot?.quotes ?? const [];
  List<MarketQuote> get equityQuotes => _equitySnapshot?.quotes ?? const [];
  List<MarketQuote> get metalQuotes => _metalSnapshot?.quotes ?? const [];

  /// Every live/cached quote across crypto, equities, indices, and metals.
  List<MarketQuote> get allQuotes => _mergeQuotes([
    ...quotes,
    ...equityQuotes,
    ...metalQuotes,
  ]);

  RateOriginInfo get status => _status;
  RateOriginInfo get equityStatus => _equityStatus;
  RateOriginInfo get metalStatus => _metalStatus;

  String? get errorMessage => _errorMessage;
  String? get equityError => _equityError;
  String? get metalError => _metalError;

  /// Why the latest equity/metal request failed, when known. Lets the UI show
  /// a specific proxy or rate-limit explanation instead of a generic error.
  MarketFailure? get equityFailure => _equityFailure;
  MarketFailure? get metalFailure => _metalFailure;
  bool get equitiesNeedProxy => _equityFailure == MarketFailure.needProxy;
  bool get metalsNeedProxy => _metalFailure == MarketFailure.needProxy;

  bool get hasQuotes => allQuotes.isNotEmpty;
  bool get hasEquityQuotes => equityQuotes.isNotEmpty;
  bool get hasMetalQuotes => metalQuotes.isNotEmpty;
  bool get isUsingCachedData => combinedStatus.isCached;
  DateTime? get fetchedAt => combinedSnapshot?.fetchedAt;
  bool get hasMore => _snapshot?.hasMore ?? true;
  int get loadedQuoteCount => quotes.length;
  int get loadedAssetCount => allQuotes.length;

  /// A single snapshot that contains every available asset quote. Crypto paging
  /// details are preserved when a crypto snapshot exists.
  MarketSnapshot? get combinedSnapshot {
    final combined = allQuotes;
    if (combined.isEmpty) return null;
    final crypto = _snapshot;
    return MarketSnapshot(
      quotes: combined,
      fetchedAt: _latestFetchedAt(),
      providerUpdatedAt: _latestProviderUpdate([
        ?_snapshot,
        ?_equitySnapshot,
        ?_metalSnapshot,
      ]),
      nextPage: crypto?.nextPage ?? 2,
      hasMore: crypto?.hasMore ?? false,
    );
  }

  /// Conservative status for the calculator: partial or failed provider data
  /// is reported as cached, never as fully live.
  RateOriginInfo get combinedStatus {
    final combined = allQuotes;
    if (combined.isEmpty) {
      return RateOriginInfo(
        origin: RateOrigin.unavailable,
        errorMessage: combinedError,
      );
    }
    final statuses = _availableStatuses();
    final anyCached = statuses.any((status) => status.isCached);
    final allLive = statuses.isNotEmpty && statuses.every((s) => s.isLive);
    final origin = !anyCached && allLive && !_hasAnyError
        ? RateOrigin.live
        : RateOrigin.cached;
    return RateOriginInfo(
      origin: origin,
      updatedAt: _latestStatusUpdate(statuses) ?? _latestFetchedAt(),
      errorMessage: origin == RateOrigin.live ? null : combinedError,
    );
  }

  String? get combinedError {
    final messages = <String>[
      ?_errorMessage,
      ?_equityError,
      ?_metalError,
    ].where((message) => message.trim().isNotEmpty).toSet().toList();
    return messages.isEmpty ? null : messages.join(' ');
  }

  bool get _hasAnyError =>
      _equityError != null || _metalError != null || _errorMessage != null;

  MarketQuote? quoteFor(String code) {
    final normalized = code.toUpperCase();
    for (final quote in allQuotes) {
      if (quote.code == normalized) return quote;
    }
    return null;
  }

  Currency? currencyByCode(String code) => quoteFor(code)?.currency;

  MarketHistoryState historyState(Currency currency, PriceHistoryRange range) {
    return _historyStates[_key(currency.code, range)] ??
        const MarketHistoryState();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([
      _loadCryptoCache(),
      if (_equityService != null) _loadEquityCache(),
      if (_metalService != null) _loadMetalCache(),
    ]);
    _notify();
    _startAutoRefreshTimer();
  }

  Future<void> _loadCryptoCache() async {
    try {
      final cached = await _storage.loadMarketCache();
      if (cached != null) {
        _snapshot = cached;
        _status = RateOriginInfo(
          origin: RateOrigin.cached,
          updatedAt: cached.providerUpdatedAt ?? cached.fetchedAt,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not load cached market data.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = 'Cached market data could not be loaded.';
    }
  }

  Future<void> _loadEquityCache() async {
    try {
      final cached = await _storage.loadEquityCache();
      if (cached != null) {
        _equitySnapshot = cached;
        _equityStatus = RateOriginInfo(
          origin: RateOrigin.cached,
          updatedAt: cached.providerUpdatedAt ?? cached.fetchedAt,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not load cached equity data.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _equityError = 'Cached stock and index data could not be loaded.';
    }
  }

  Future<void> _loadMetalCache() async {
    try {
      final cached = await _storage.loadMetalCache();
      if (cached != null) {
        _metalSnapshot = cached;
        _metalStatus = RateOriginInfo(
          origin: RateOrigin.cached,
          updatedAt: cached.providerUpdatedAt ?? cached.fetchedAt,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not load cached metal data.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _metalError = 'Cached metal prices could not be loaded.';
    }
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final fetchedAt = combinedSnapshot?.fetchedAt;
    if (fetchedAt != null) {
      final age = _clock().toUtc().difference(fetchedAt.toUtc());
      if (age < maxAge) return;
    }
    await refresh();
  }

  /// Refreshes every configured provider concurrently. A failure in one source
  /// keeps that source's previous snapshot while the others update normally.
  Future<void> refresh() async {
    await Future.wait([
      _refreshCrypto(),
      if (_equityService != null) _refreshEquities(),
      if (_metalService != null) _refreshMetals(),
    ]);
  }

  /// Refreshes every page that has already been loaded so timestamps remain
  /// coherent. If any page fails, the previous snapshot is kept intact.
  Future<void> _refreshCrypto() async {
    if (_isLoading || _isLoadingMore) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();

    final loadedPages = _loadedPages();
    try {
      final pages = await Future.wait([
        for (var page = 1; page <= loadedPages; page++)
          _service.fetchMarkets(page: page, perPage: pageSize),
      ]);
      final combined = _mergePages(pages);
      final lastPage = pages.last;
      _snapshot = MarketSnapshot(
        quotes: combined,
        fetchedAt: _clock().toUtc(),
        providerUpdatedAt: _latestProviderUpdate(pages),
        nextPage: loadedPages + 1,
        hasMore: lastPage.quotes.length >= pageSize && loadedPages < maxPages,
      );
      _status = RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: _snapshot!.providerUpdatedAt ?? _snapshot!.fetchedAt,
      );
      _errorMessage = null;
      await _persistSafely();
    } catch (error, stackTrace) {
      developer.log(
        'Market refresh failed.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = _friendlyError(error);
      final snapshot = _snapshot;
      if (snapshot != null) {
        _status = RateOriginInfo(
          origin: RateOrigin.cached,
          updatedAt: snapshot.providerUpdatedAt ?? snapshot.fetchedAt,
          errorMessage: _errorMessage,
        );
      } else {
        _status = RateOriginInfo.unavailable(errorMessage: _errorMessage);
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _refreshEquities() async {
    final service = _equityService;
    if (service == null || _isLoadingEquities) return;
    _isLoadingEquities = true;
    _equityError = null;
    _equityFailure = null;
    _notify();
    try {
      final snapshot = await service.fetchQuotes();
      _equitySnapshot = snapshot;
      _equityStatus = RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: snapshot.providerUpdatedAt ?? snapshot.fetchedAt,
      );
      _equityFailure = null;
      await _persistEquitySafely();
    } catch (error, stackTrace) {
      developer.log(
        'Equity refresh failed.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _equityError = _friendlyError(error);
      _equityFailure = error is MarketServiceException ? error.reason : null;
      final snapshot = _equitySnapshot;
      _equityStatus = snapshot == null
          ? RateOriginInfo.unavailable(errorMessage: _equityError)
          : RateOriginInfo(
              origin: RateOrigin.cached,
              updatedAt: snapshot.providerUpdatedAt ?? snapshot.fetchedAt,
              errorMessage: _equityError,
            );
    } finally {
      _isLoadingEquities = false;
      _notify();
    }
  }

  Future<void> _refreshMetals() async {
    final service = _metalService;
    if (service == null || _isLoadingMetals) return;
    _isLoadingMetals = true;
    _metalError = null;
    _metalFailure = null;
    _notify();
    try {
      final snapshot = await service.fetchQuotes();
      _metalSnapshot = snapshot;
      _metalStatus = RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: snapshot.providerUpdatedAt ?? snapshot.fetchedAt,
      );
      _metalFailure = null;
      await _persistMetalSafely();
    } catch (error, stackTrace) {
      developer.log(
        'Metal refresh failed.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _metalError = _friendlyError(error);
      _metalFailure = error is MarketServiceException ? error.reason : null;
      final snapshot = _metalSnapshot;
      _metalStatus = snapshot == null
          ? RateOriginInfo.unavailable(errorMessage: _metalError)
          : RateOriginInfo(
              origin: RateOrigin.cached,
              updatedAt: snapshot.providerUpdatedAt ?? snapshot.fetchedAt,
              errorMessage: _metalError,
            );
    } finally {
      _isLoadingMetals = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) return;
    final current = _snapshot;
    if (current == null) {
      await _refreshCrypto();
      return;
    }
    final page = current.nextPage;
    _isLoadingMore = true;
    _errorMessage = null;
    _notify();

    try {
      final next = await _service.fetchMarkets(page: page, perPage: pageSize);
      final combined = _mergeQuotes([...current.quotes, ...next.quotes]);
      _snapshot = MarketSnapshot(
        quotes: combined,
        fetchedAt: _clock().toUtc(),
        providerUpdatedAt: _latestProviderUpdate([current, next]),
        nextPage: page + 1,
        hasMore: next.quotes.length >= pageSize && page < maxPages,
      );
      _status = RateOriginInfo(
        origin: _status.isCached ? RateOrigin.cached : RateOrigin.live,
        updatedAt: _snapshot!.providerUpdatedAt ?? _snapshot!.fetchedAt,
      );
      await _persistSafely();
    } catch (error, stackTrace) {
      developer.log(
        'Loading more market pages failed.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = _friendlyError(error);
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  Future<PriceHistory?> loadHistory(
    Currency currency,
    PriceHistoryRange range, {
    bool forceRefresh = false,
  }) {
    final key = _key(currency.code, range);
    final current = _historyStates[key];
    if (!forceRefresh &&
        current != null &&
        current.history != null &&
        current.status.isLive) {
      return Future.value(current.history);
    }
    final inflight = _historyRequests[key];
    if (inflight != null) return inflight;

    final request = _loadHistoryInternal(currency, range, key);
    _historyRequests[key] = request;
    return request.whenComplete(() {
      _historyRequests.remove(key);
    });
  }

  Future<PriceHistory?> _loadHistoryInternal(
    Currency currency,
    PriceHistoryRange range,
    String key,
  ) async {
    var state = _historyStates[key] ?? const MarketHistoryState();
    if (state.history == null) {
      try {
        final cached = await _storage.loadPriceHistory(currency.code, range);
        if (cached != null) {
          state = MarketHistoryState(
            history: cached,
            status: RateOriginInfo(
              origin: RateOrigin.cached,
              updatedAt: cached.fetchedAt,
            ),
          );
          _historyStates[key] = state;
          _notify();
        }
      } catch (error, stackTrace) {
        developer.log(
          'Could not load cached price history.',
          name: 'MarketsController',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);
    _historyStates[key] = state;
    _notify();

    try {
      final history = await _fetchHistory(currency, range);
      state = MarketHistoryState(
        history: history,
        status: RateOriginInfo(
          origin: RateOrigin.live,
          updatedAt: history.fetchedAt,
        ),
      );
      _historyStates[key] = state;
      _notify();
      try {
        await _storage.savePriceHistory(history);
      } catch (error, stackTrace) {
        developer.log(
          'Could not persist price history.',
          name: 'MarketsController',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return history;
    } catch (error, stackTrace) {
      developer.log(
        'Price history refresh failed.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
      final message = _friendlyError(error);
      final existing = state.history;
      state = MarketHistoryState(
        history: existing,
        status: existing == null
            ? RateOriginInfo.unavailable(errorMessage: message)
            : RateOriginInfo(
                origin: RateOrigin.cached,
                updatedAt: state.status.updatedAt,
                errorMessage: message,
              ),
        errorMessage: message,
      );
      _historyStates[key] = state;
      _notify();
      return existing;
    }
  }

  Future<PriceHistory> _fetchHistory(
    Currency currency,
    PriceHistoryRange range,
  ) {
    if (currency.isFiat) {
      throw MarketServiceException(
        'Fiat rates do not have price history in this app.',
        reason: MarketFailure.provider,
      );
    }
    if (currency.isCrypto) {
      return _service.fetchPriceHistory(currency: currency, range: range);
    }
    final equity = _equityService;
    if (equity == null) {
      throw MarketServiceException(
        'Charts for ${currency.code} are not configured in this build.',
        reason: MarketFailure.provider,
      );
    }
    return equity.fetchPriceHistory(currency: currency, range: range);
  }

  int _loadedPages() {
    final current = _snapshot;
    if (current == null) return 1;
    return (current.nextPage - 1).clamp(1, maxPages);
  }

  List<MarketQuote> _mergePages(List<MarketSnapshot> pages) {
    return _mergeQuotes([for (final page in pages) ...page.quotes]);
  }

  List<MarketQuote> _mergeQuotes(List<MarketQuote> quotes) {
    final merged = <MarketQuote>[];
    final seen = <String>{};
    for (final quote in quotes) {
      if (!seen.add(quote.code)) continue;
      merged.add(quote);
    }
    return List.unmodifiable(merged);
  }

  List<RateOriginInfo> _availableStatuses() {
    return [
      if (_snapshot != null) _status,
      if (_equitySnapshot != null) _equityStatus,
      if (_metalSnapshot != null) _metalStatus,
    ];
  }

  DateTime _latestFetchedAt() {
    DateTime? latest;
    for (final snapshot in [_snapshot, _equitySnapshot, _metalSnapshot]) {
      final value = snapshot?.fetchedAt;
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest ?? _clock().toUtc();
  }

  DateTime? _latestStatusUpdate(List<RateOriginInfo> statuses) {
    DateTime? latest;
    for (final status in statuses) {
      final value = status.updatedAt;
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest;
  }

  DateTime? _latestProviderUpdate(List<MarketSnapshot> snapshots) {
    DateTime? latest;
    for (final snapshot in snapshots) {
      final value = snapshot.providerUpdatedAt;
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest;
  }

  Future<void> _persistSafely() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    try {
      await _storage.saveMarketCache(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Could not persist the market cache.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persistEquitySafely() async {
    final snapshot = _equitySnapshot;
    if (snapshot == null) return;
    try {
      await _storage.saveEquityCache(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Could not persist the equity cache.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persistMetalSafely() async {
    final snapshot = _metalSnapshot;
    if (snapshot == null) return;
    try {
      await _storage.saveMetalCache(snapshot);
    } catch (error, stackTrace) {
      developer.log(
        'Could not persist the metal cache.',
        name: 'MarketsController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _friendlyError(Object error) {
    return error is Exception
        ? error.toString().replaceFirst(RegExp(r'^Exception: '), '')
        : 'The market service failed unexpectedly.';
  }

  String _key(String code, PriceHistoryRange range) =>
      '${code.toUpperCase()}:${range.name}';

  void _startAutoRefreshTimer() {
    final interval = autoRefreshInterval;
    if (interval == null || interval <= Duration.zero) return;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) {
      unawaited(refresh());
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
