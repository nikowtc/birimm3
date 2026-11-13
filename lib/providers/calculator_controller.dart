// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../logic/asset_search.dart';
import '../logic/conversion_phrase_parser.dart';
import '../logic/row_calculator.dart';
import '../models/app_preferences.dart';
import '../models/calculation_history.dart';
import '../models/calculation_row.dart';
import '../models/currency.dart';
import '../models/currency_catalog.dart';
import '../models/market_data.dart';
import '../models/quick_conversion.dart';
import '../models/rate_bundle.dart';
import '../models/rate_status.dart';
import '../models/user_favorites.dart';
import '../services/app_storage.dart';
import '../services/exchange_rate_repository.dart';

/// Calculator-first app state: rows, output currency, live rates, favorites,
/// history, and persisted appearance choices.
class CalculatorController extends ChangeNotifier {
  CalculatorController({
    required RatesRepository ratesRepository,
    required AppStorage storage,
    this.autoRefreshInterval,
    DateTime Function()? clock,
    RowCalculator rowCalculator = const RowCalculator(),
  }) : _ratesRepository = ratesRepository,
       _storage = storage,
       _clock = clock ?? DateTime.now,
       _rowCalculator = rowCalculator;

  static const int maxHistoryEntries = 100;
  static const int maxQuickRecent = 8;
  static const int maxQuickPairs = 12;

  final RatesRepository _ratesRepository;
  final AppStorage _storage;
  final DateTime Function() _clock;
  final RowCalculator _rowCalculator;
  final Duration? autoRefreshInterval;

  Timer? _autoRefreshTimer;
  bool _disposed = false;
  bool _initialized = false;

  final List<CalculationRow> _rows = [
    CalculationRow(
      id: 'row-0',
      amount: '100',
      currency: CurrencyCatalog.fiatCurrency('USD'),
    ),
  ];
  Currency _outputCurrency = CurrencyCatalog.fiatCurrency('EUR');
  List<Currency> _currencies = CurrencyCatalog.build();
  final Map<String, Currency> _catalogByCode = {};
  UserFavorites _favorites = const UserFavorites();
  List<CalculationHistoryEntry> _history = const [];
  AppThemePreference _theme = AppThemePreference.dark;
  AppLanguage _language = AppLanguage.en;

  RateBundle? _rates;
  RateOriginInfo _fiatStatus = const RateOriginInfo.unavailable();
  RateOriginInfo _cryptoStatus = const RateOriginInfo.unavailable();
  RateOriginInfo _marketStatus = const RateOriginInfo.unavailable();
  String? _marketError;
  DateTime? _marketFetchedAt;
  Map<String, MarketQuote> _marketQuotes = const {};
  MarketSnapshot? _lastMarketSnapshot;
  bool _isLoadingRates = false;
  String? _rateRefreshError;
  String? _persistenceError;
  int _idCounter = 0;

  String _quickAmount = '1';
  Currency _quickFrom = CurrencyCatalog.fiatCurrency('USD');
  Currency _quickTo = CurrencyCatalog.fiatCurrency('EUR');
  List<QuickConversionPair> _quickPairs = const [];
  List<QuickConversionRecord> _quickRecent = const [];

  /// Optional hook used by the shell to refresh market pages together with
  /// the fiat/crypto rate snapshot from the settings screen.
  Future<void> Function()? refreshMarketData;

  List<CalculationRow> get rows => List.unmodifiable(_rows);
  Currency get outputCurrency => _outputCurrency;
  List<Currency> get currencies => _currencies;
  UserFavorites get favorites => _favorites;
  List<CalculationHistoryEntry> get history => _history;
  AppThemePreference get theme => _theme;
  AppLanguage get language => _language;
  bool get isInitialized => _initialized;
  bool get isLoadingRates => _isLoadingRates;
  String? get persistenceError => _persistenceError;
  RateOriginInfo get fiatStatus => _fiatStatus;
  RateOriginInfo get cryptoStatus => _cryptoStatus;
  RateOriginInfo get marketStatus => _marketStatus;
  String? get marketError => _marketError;
  RateBundle? get rateBundle => _rates;
  bool get hasRates => unitsPerUsd.length > 1;

  String get quickAmount => _quickAmount;
  Currency get quickFrom => _quickFrom;
  Currency get quickTo => _quickTo;
  List<QuickConversionPair> get quickSavedPairs => _quickPairs;
  List<QuickConversionRecord> get quickRecent => _quickRecent;

  bool get quickPairIsSaved => _quickPairs.any(
    (pair) =>
        pair.fromCode == _quickFrom.code && pair.toCode == _quickTo.code,
  );

  double? get quickRate =>
      conversionRate(_quickFrom.code, _quickTo.code);

  double? get quickResult {
    final amount = parseLocalizedAmount(_quickAmount);
    final rate = quickRate;
    if (amount == null || rate == null) return null;
    final result = amount * rate;
    return result.isFinite ? result : null;
  }

  DateTime? get ratesFetchedAt {
    final bundleAt = _rates?.fetchedAt;
    final marketAt = _marketFetchedAt;
    if (bundleAt == null) return marketAt;
    if (marketAt == null) return bundleAt;
    return marketAt.isAfter(bundleAt) ? marketAt : bundleAt;
  }

  /// The status shown for CoinGecko's crypto rates and market-derived rates.
  /// It is deliberately conservative: if either source is cached, the combined
  /// state is cached.
  RateOriginInfo get cryptoMarketStatus {
    final baseAvailable = _rates?.hasCrypto ?? false;
    final marketAvailable = _marketQuotes.isNotEmpty;
    if (!baseAvailable && !marketAvailable) {
      return _cryptoStatus.isUnavailable || _marketStatus.isUnavailable
          ? RateOriginInfo.unavailable(
              errorMessage: _joinMessages([
                _cryptoStatus.errorMessage,
                _marketError,
              ]),
            )
          : _cryptoStatus;
    }
    if (!marketAvailable) return _cryptoStatus;
    if (!baseAvailable) return _marketStatus;

    final statuses = [_cryptoStatus, _marketStatus];
    final origin = statuses.any((status) => status.isCached)
        ? RateOrigin.cached
        : statuses.every((status) => status.isLive)
        ? RateOrigin.live
        : RateOrigin.cached;
    DateTime? latest;
    for (final status in statuses) {
      final value = status.updatedAt;
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return RateOriginInfo(
      origin: origin,
      updatedAt: latest ?? ratesFetchedAt,
      errorMessage: origin == RateOrigin.live
          ? null
          : _joinMessages([_cryptoStatus.errorMessage, _marketError]),
    );
  }

  bool get isUsingCachedRates =>
      _fiatStatus.isCached || cryptoMarketStatus.isCached;

  String? get rateRefreshError {
    final messages = <String>[
      ?_fiatStatus.errorMessage,
      ?_cryptoStatus.errorMessage,
      ?_marketError,
      ?_rateRefreshError,
    ];
    return messages.isEmpty ? null : messages.toSet().join(' ');
  }

  Map<String, double> get unitsPerUsd {
    final units = <String, double>{'USD': 1};
    final fiat = _rates?.fiatUnitsPerUsd;
    if (fiat != null) units.addAll(fiat);
    final crypto = _rates?.cryptoUnitsPerUsd;
    if (crypto != null) {
      for (final entry in crypto.entries) {
        units.putIfAbsent(entry.key, () => entry.value);
      }
    }
    for (final entry in _marketQuotes.entries) {
      if (units.containsKey(entry.key)) continue;
      final price = entry.value.usdPrice;
      if (!price.isFinite || price <= 0) continue;
      final rate = 1 / price;
      if (!rate.isFinite || rate <= 0) continue;
      units[entry.key] = rate;
    }
    return units;
  }

  RowCalculationResult get calculation => _rowCalculator.calculate(
    rows: _rows,
    outputCurrency: _outputCurrency,
    unitsPerUsd: unitsPerUsd,
  );

  bool get canSaveCalculation {
    final result = calculation;
    return result.isValid && _rows.any((row) => row.hasInput);
  }

  double? get outputUnitRate => conversionRate('USD', _outputCurrency.code);

  List<Currency> get favoriteCurrencies {
    final result = <Currency>[];
    final seen = <String>{};
    for (final stored in _favorites.currencies) {
      final resolved = _catalogByCode[stored.code] ?? stored;
      if (!seen.add(resolved.code)) continue;
      result.add(resolved);
    }
    return List.unmodifiable(result);
  }

  MarketQuote? quoteFor(String code) => _marketQuotes[code.toUpperCase()];

  Currency? currencyByCode(String code) {
    final normalized = code.trim().toUpperCase();
    return _catalogByCode[normalized] ?? CurrencyCatalog.byCode(normalized);
  }

  bool isCurrencyFavorite(String code) => _favorites.hasCurrency(code);

  Future<void> initialize() async {
    if (_initialized) return;

    var preferredOutputCode = 'EUR';
    try {
      final preferences = await _storage.loadPreferences();
      _theme = preferences.theme;
      _language = preferences.language;
      preferredOutputCode = preferences.outputCurrencyCode;
      _outputCurrency = _currencyForPreference(preferredOutputCode);
    } catch (error, stackTrace) {
      _log('Could not load local preferences.', error, stackTrace);
      _persistenceError = 'Local preferences could not be loaded.';
    }

    try {
      _favorites = await _storage.loadFavorites();
    } catch (error, stackTrace) {
      _log('Could not load favorites.', error, stackTrace);
      _persistenceError = 'Favorites could not be loaded.';
    }

    try {
      _history = await _storage.loadHistory();
    } catch (error, stackTrace) {
      _log('Could not load calculation history.', error, stackTrace);
      _persistenceError = 'Calculation history could not be loaded.';
    }

    try {
      final quick = await _storage.loadQuickConversions();
      _quickPairs = quick.pairs;
      _quickRecent = quick.recent;
    } catch (error, stackTrace) {
      _log('Could not load quick conversions.', error, stackTrace);
    }

    _quickFrom = CurrencyCatalog.fiatCurrency('USD');
    final preferredTo = _currencyForPreference(preferredOutputCode);
    _quickTo = preferredTo.code == _quickFrom.code
        ? CurrencyCatalog.fiatCurrency('EUR')
        : preferredTo;

    try {
      final cached = await _ratesRepository.loadCachedRates();
      if (cached != null) {
        _rates = cached;
        _fiatStatus = _cachedStatusFor(
          cached.fiatUpdatedAt ?? cached.fetchedAt,
        );
        _cryptoStatus = _cachedStatusFor(
          cached.cryptoUpdatedAt ?? cached.fetchedAt,
        );
      }
    } catch (error, stackTrace) {
      _log('Could not load cached rates.', error, stackTrace);
      _rateRefreshError = 'Cached rates could not be loaded.';
    }

    try {
      final cachedMarket = await _storage.loadMarketCache();
      if (cachedMarket != null) {
        _applyMarketSnapshot(cachedMarket);
        _marketStatus = RateOriginInfo(
          origin: RateOrigin.cached,
          updatedAt: cachedMarket.providerUpdatedAt ?? cachedMarket.fetchedAt,
        );
        _lastMarketSnapshot = cachedMarket;
      }
    } catch (error, stackTrace) {
      _log('Could not load cached market data.', error, stackTrace);
    }

    _outputCurrency = _currencyForPreference(preferredOutputCode);
    _refreshCurrencyCatalog();
    _initialized = true;
    _notify();
    _startAutoRefreshTimer();
  }

  /// Called by the app shell whenever [MarketsController] publishes a new
  /// snapshot or status. Only the latest complete snapshot is used.
  void syncMarketData(
    MarketSnapshot? snapshot, {
    required RateOriginInfo status,
    String? error,
  }) {
    final snapshotChanged = !identical(_lastMarketSnapshot, snapshot);
    final statusChanged =
        _marketStatus.origin != status.origin ||
        _marketStatus.updatedAt != status.updatedAt ||
        _marketError != error;
    if (!snapshotChanged && !statusChanged) return;

    if (snapshotChanged) {
      _lastMarketSnapshot = snapshot;
      _applyMarketSnapshot(snapshot);
    }
    _marketStatus = status;
    _marketError = error;
    _refreshCurrencyCatalog();
    _notify();
  }

  Future<void> refreshRatesIfStale({
    Duration maxAge = const Duration(minutes: 10),
  }) async {
    final fetchedAt = _rates?.fetchedAt;
    if (fetchedAt != null) {
      final age = _clock().toUtc().difference(fetchedAt.toUtc());
      if (age < maxAge) return;
    }
    await refreshRates();
  }

  Future<void> refreshRates() async {
    if (_isLoadingRates) return;
    _isLoadingRates = true;
    _rateRefreshError = null;
    _notify();

    try {
      final result = await _ratesRepository.refresh(cached: _rates);
      _rates = result.bundle ?? _rates;
      _fiatStatus = result.fiat;
      _cryptoStatus = result.crypto;
      _rateRefreshError = null;
      _refreshCurrencyCatalog();
    } catch (error, stackTrace) {
      _log('Unexpected rate refresh failure.', error, stackTrace);
      _rateRefreshError = 'Could not update rates. Existing data was kept.';
      final rates = _rates;
      if (rates != null) {
        _fiatStatus = _markCached(_fiatStatus, rates);
        _cryptoStatus = _markCached(_cryptoStatus, rates);
      }
    } finally {
      _isLoadingRates = false;
      _notify();
    }
  }

  Future<void> refreshAllData() async {
    await Future.wait([
      refreshRates(),
      if (refreshMarketData != null) refreshMarketData!(),
    ]);
  }

  void updateRowAmount(String id, String value) {
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0) return;
    final row = _rows[index];
    if (row.amount == value) return;
    _rows[index] = row.copyWith(amount: value);
    _notify();
  }

  void setRowCurrency(String id, Currency currency) {
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0) return;
    final row = _rows[index];
    if (row.currency.code == currency.code) return;
    _rows[index] = row.copyWith(currency: currency);
    _refreshCurrencyCatalog();
    _notify();
  }

  String addRow({Currency? currency, String amount = ''}) {
    final selected = currency ?? _rows.lastOrNull?.currency ?? _outputCurrency;
    final row = CalculationRow(
      id: _nextId('row'),
      amount: amount,
      currency: selected,
    );
    _rows.add(row);
    _refreshCurrencyCatalog();
    _notify();
    return row.id;
  }

  void removeRow(String id) {
    if (_rows.length <= 1) return;
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0) return;
    _rows.removeAt(index);
    _notify();
  }

  void resetRows() {
    _rows
      ..clear()
      ..add(
        CalculationRow(
          id: _nextId('row'),
          amount: '',
          currency: CurrencyCatalog.fiatCurrency('USD'),
        ),
      );
    _notify();
  }

  void setOutputCurrency(Currency currency) {
    if (_outputCurrency.code == currency.code) return;
    _outputCurrency = currency;
    _refreshCurrencyCatalog();
    _notify();
    _persistPreferencesSafely();
  }

  void useCurrencyInCalculator(Currency currency) {
    addRow(currency: currency, amount: '1');
  }

  Future<bool> toggleCurrencyFavorite(Currency currency) async {
    final normalized = currency.code.toUpperCase();
    final currencies = [..._favorites.currencies];
    final index = currencies.indexWhere((item) => item.code == normalized);
    final existed = index >= 0;
    if (existed) {
      currencies.removeAt(index);
    } else {
      currencies.insert(0, currency);
    }
    _favorites = _favorites.copyWith(currencies: List.unmodifiable(currencies));
    _refreshCurrencyCatalog();
    _notify();
    await _saveFavoritesSafely();
    return !existed;
  }

  Future<bool> saveCurrentCalculationToHistory() async {
    final outcome = calculation;
    if (!outcome.isValid || outcome.total == null || outcome.totalUsd == null) {
      return false;
    }
    if (!_rows.any((row) => row.hasInput)) return false;

    final units = <String, double>{'USD': 1};
    final allUnits = unitsPerUsd;
    for (final row in _rows) {
      final rate = allUnits[row.currency.code];
      if (rate != null && rate.isFinite && rate > 0) {
        units[row.currency.code] = rate;
      }
    }
    final outputRate = allUnits[_outputCurrency.code];
    if (outputRate != null && outputRate.isFinite && outputRate > 0) {
      units[_outputCurrency.code] = outputRate;
    }

    final entry = CalculationHistoryEntry(
      id: _nextId('history'),
      rows: List.unmodifiable([
        for (final row in _rows)
          CalculationRow(
            id: row.id,
            amount: row.amount.trim(),
            currency: row.currency,
          ),
      ]),
      outputCurrency: _outputCurrency,
      result: outcome.total!,
      resultUsd: outcome.totalUsd!,
      unitsPerUsd: Map.unmodifiable(units),
      rateMeta: HistoryRateMeta(
        fetchedAt: ratesFetchedAt,
        fiatOrigin: _fiatStatus.origin,
        cryptoOrigin: cryptoMarketStatus.origin,
        fiatUpdatedAt: _fiatStatus.updatedAt,
        cryptoUpdatedAt: cryptoMarketStatus.updatedAt,
      ),
      createdAt: _clock().toUtc(),
    );

    _history = List.unmodifiable([entry, ..._history].take(maxHistoryEntries));
    _notify();
    try {
      await _storage.saveHistory(_history);
      if (_persistenceError != null) {
        _persistenceError = null;
        _notify();
      }
      return true;
    } catch (error, stackTrace) {
      _log('Could not persist calculation history.', error, stackTrace);
      _persistenceError = 'Calculation history could not be saved locally.';
      _notify();
      return false;
    }
  }

  RowCalculationResult recalculateHistory(CalculationHistoryEntry entry) {
    return _rowCalculator.calculate(
      rows: entry.rows,
      outputCurrency: entry.outputCurrency,
      unitsPerUsd: unitsPerUsd,
    );
  }

  void restoreHistory(CalculationHistoryEntry entry) {
    _rows
      ..clear()
      ..addAll([
        for (final row in entry.rows)
          CalculationRow(
            id: _nextId('row'),
            amount: row.amount,
            currency: row.currency,
          ),
      ]);
    _outputCurrency = entry.outputCurrency;
    _refreshCurrencyCatalog();
    _notify();
    _persistPreferencesSafely();
  }

  Future<void> removeHistoryEntry(String id) async {
    final next = _history.where((entry) => entry.id != id).toList();
    if (next.length == _history.length) return;
    _history = List.unmodifiable(next);
    _notify();
    await _saveHistorySafely();
  }

  Future<void> clearHistory() async {
    if (_history.isEmpty) return;
    _history = const [];
    _notify();
    await _saveHistorySafely();
  }

  void setTheme(AppThemePreference preference) {
    if (preference == _theme) return;
    _theme = preference;
    _notify();
    _persistPreferencesSafely();
  }

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    _notify();
    _persistPreferencesSafely();
  }

  void setQuickAmount(String value) {
    if (value == _quickAmount) return;
    _quickAmount = value;
    _notify();
  }

  void setQuickFrom(Currency currency) {
    if (currency.code == _quickFrom.code) return;
    final previousFrom = _quickFrom;
    _quickFrom = currency;
    if (_quickTo.code == currency.code) _quickTo = previousFrom;
    _notify();
  }

  void setQuickTo(Currency currency) {
    if (currency.code == _quickTo.code) return;
    final previousTo = _quickTo;
    _quickTo = currency;
    if (_quickFrom.code == currency.code) _quickFrom = previousTo;
    _notify();
  }

  void swapQuickPair() {
    final from = _quickFrom;
    _quickFrom = _quickTo;
    _quickTo = from;
    _notify();
  }

  void applyQuickPair(QuickConversionPair pair) {
    final from = currencyByCode(pair.fromCode);
    final to = currencyByCode(pair.toCode);
    if (from == null || to == null || from.code == to.code) return;
    if (_quickFrom.code == from.code && _quickTo.code == to.code) return;
    _quickFrom = from;
    _quickTo = to;
    _notify();
  }

  void applyQuickRecord(QuickConversionRecord record) {
    final from = currencyByCode(record.fromCode);
    final to = currencyByCode(record.toCode);
    if (from == null || to == null || from.code == to.code) return;
    _quickAmount = record.amount;
    _quickFrom = from;
    _quickTo = to;
    _notify();
  }

  Future<bool> rememberQuickConversion() async {
    if (quickResult == null || _quickAmount.trim().isEmpty) return false;
    final record = QuickConversionRecord(
      amount: _quickAmount.trim(),
      fromCode: _quickFrom.code,
      toCode: _quickTo.code,
      createdAt: _clock().toUtc(),
    );
    _quickRecent = List.unmodifiable([
      record,
      ..._quickRecent.where(
        (item) =>
            !(item.amount == record.amount &&
                item.fromCode == record.fromCode &&
                item.toCode == record.toCode),
      ),
    ].take(maxQuickRecent));
    _notify();
    await _saveQuickConversionsSafely();
    return true;
  }

  Future<void> clearQuickRecent() async {
    if (_quickRecent.isEmpty) return;
    _quickRecent = const [];
    _notify();
    await _saveQuickConversionsSafely();
  }

  Future<bool> toggleQuickPairSaved() async {
    final pair = QuickConversionPair(
      fromCode: _quickFrom.code,
      toCode: _quickTo.code,
    );
    final exists = _quickPairs.any((item) => item.key == pair.key);
    _quickPairs = List.unmodifiable(
      exists
          ? _quickPairs.where((item) => item.key != pair.key)
          : [
              pair,
              ..._quickPairs.where((item) => item.key != pair.key),
            ].take(maxQuickPairs),
    );
    _notify();
    await _saveQuickConversionsSafely();
    return !exists;
  }

  Future<void> removeQuickPair(QuickConversionPair pair) async {
    final next = _quickPairs.where((item) => item.key != pair.key).toList();
    if (next.length == _quickPairs.length) return;
    _quickPairs = List.unmodifiable(next);
    _notify();
    await _saveQuickConversionsSafely();
  }

  Future<bool> applyConversionPhrase(String input) async {
    final parsed = parseConversionPhrase(
      input,
      languageCode: _language.languageCode,
      fallbackFrom: _quickFrom,
      fallbackTo: _quickTo,
    );
    if (parsed == null) return false;
    _quickAmount = _quickAmountInput(parsed.amount);
    _quickFrom = parsed.from;
    _quickTo = parsed.to;
    _notify();
    await rememberQuickConversion();
    return true;
  }

  String _quickAmountInput(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  double? conversionRate(String fromCurrency, String toCurrency) {
    return _rowCalculator.unitRate(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      unitsPerUsd: unitsPerUsd,
    );
  }

  void _applyMarketSnapshot(MarketSnapshot? snapshot) {
    if (snapshot == null) {
      _marketQuotes = const {};
      _marketFetchedAt = null;
      return;
    }
    final quotes = <String, MarketQuote>{};
    for (final quote in snapshot.quotes) {
      quotes[quote.code] = quote;
    }
    _marketQuotes = Map.unmodifiable(quotes);
    _marketFetchedAt = snapshot.fetchedAt;
  }

  Currency _currencyForPreference(String code) {
    final normalized = code.trim().toUpperCase();
    final known =
        CurrencyCatalog.byCode(normalized) ??
        _marketQuotes[normalized]?.currency ??
        _favorites.currencyByCode(normalized);
    if (known != null) return known;
    if (RegExp(r'^[A-Z]{2,10}$').hasMatch(normalized)) {
      return CurrencyCatalog.fiatCurrency(normalized);
    }
    return CurrencyCatalog.fiatCurrency('EUR');
  }

  void _refreshCurrencyCatalog() {
    final catalog = <Currency>[];
    final seen = <String>{};

    void add(Currency currency) {
      if (!seen.add(currency.code)) return;
      catalog.add(currency);
    }

    for (final currency in CurrencyCatalog.build(
      fiatCodes: _rates?.fiatUnitsPerUsd.keys ?? const [],
    )) {
      add(currency);
    }
    for (final quote in _marketQuotes.values) {
      add(quote.currency);
    }
    for (final favorite in _favorites.currencies) {
      add(favorite);
    }
    for (final row in _rows) {
      add(row.currency);
    }
    add(_outputCurrency);

    _currencies = List.unmodifiable(catalog);
    _catalogByCode
      ..clear()
      ..addEntries(
        _currencies.map((currency) => MapEntry(currency.code, currency)),
      );
  }

  RateOriginInfo _cachedStatusFor(DateTime timestamp) {
    return RateOriginInfo(origin: RateOrigin.cached, updatedAt: timestamp);
  }

  RateOriginInfo _markCached(RateOriginInfo status, RateBundle bundle) {
    if (status.isUnavailable) return status;
    return RateOriginInfo(
      origin: RateOrigin.cached,
      updatedAt: status.updatedAt ?? bundle.fetchedAt,
      errorMessage: status.errorMessage,
    );
  }

  Future<void> _persistPreferencesSafely() async {
    try {
      await _storage.savePreferences(
        AppPreferences(
          theme: _theme,
          language: _language,
          outputCurrencyCode: _outputCurrency.code,
        ),
      );
      if (_persistenceError != null) {
        _persistenceError = null;
        _notify();
      }
    } catch (error, stackTrace) {
      _log('Could not persist preferences.', error, stackTrace);
      _persistenceError = 'Preferences could not be saved locally.';
      _notify();
    }
  }

  Future<void> _saveHistorySafely() async {
    try {
      await _storage.saveHistory(_history);
      if (_persistenceError != null) {
        _persistenceError = null;
        _notify();
      }
    } catch (error, stackTrace) {
      _log('Could not persist calculation history.', error, stackTrace);
      _persistenceError = 'Calculation history could not be saved locally.';
      _notify();
    }
  }

  Future<void> _saveFavoritesSafely() async {
    try {
      await _storage.saveFavorites(_favorites);
      if (_persistenceError != null) {
        _persistenceError = null;
        _notify();
      }
    } catch (error, stackTrace) {
      _log('Could not persist favorites.', error, stackTrace);
      _persistenceError = 'Favorites could not be saved locally.';
      _notify();
    }
  }

  Future<void> _saveQuickConversionsSafely() async {
    try {
      await _storage.saveQuickConversions(
        QuickConversionData(pairs: _quickPairs, recent: _quickRecent),
      );
    } catch (error, stackTrace) {
      _log('Could not persist quick conversions.', error, stackTrace);
    }
  }

  String _nextId(String prefix) =>
      '$prefix-${_clock().microsecondsSinceEpoch}-${_idCounter++}';

  String? _joinMessages(List<String?> messages) {
    final values = messages.whereType<String>().where(
      (message) => message.trim().isNotEmpty,
    );
    return values.isEmpty ? null : values.toSet().join(' ');
  }

  void _startAutoRefreshTimer() {
    final interval = autoRefreshInterval;
    if (interval == null || interval <= Duration.zero) return;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) {
      unawaited(refreshRates());
    });
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'CalculatorController',
      error: error,
      stackTrace: stackTrace,
    );
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

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
