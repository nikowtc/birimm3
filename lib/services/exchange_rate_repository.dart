// ignore_for_file: prefer_initializing_formals

import 'dart:developer' as developer;

import '../models/rate_bundle.dart';
import '../models/rate_status.dart';
import 'app_storage.dart';
import 'crypto_rate_service.dart';
import 'fiat_rate_service.dart';
import 'rate_service_exception.dart';

abstract interface class RatesRepository {
  Future<RateBundle?> loadCachedRates();

  Future<RateRefreshResult> refresh({RateBundle? cached});
}

/// Combines the two providers and never invents a missing rate.
///
/// If one provider fails, rates from the other provider still update. A
/// provider-specific cached fallback is used only when one exists, and the
/// returned [RateOriginInfo] tells the UI that it is cached.
class ExchangeRateRepository implements RatesRepository {
  ExchangeRateRepository({
    required FiatRateService fiatService,
    required CryptoRateService cryptoService,
    required AppStorage storage,
    DateTime Function()? clock,
  }) : _fiatService = fiatService,
       _cryptoService = cryptoService,
       _storage = storage,
       _clock = clock ?? DateTime.now;

  final FiatRateService _fiatService;
  final CryptoRateService _cryptoService;
  final AppStorage _storage;
  final DateTime Function() _clock;

  @override
  Future<RateBundle?> loadCachedRates() => _storage.loadRateCache();

  @override
  Future<RateRefreshResult> refresh({RateBundle? cached}) async {
    final results = await Future.wait<_FetchResult<Object>>([
      _fetchFiat(),
      _fetchCrypto(),
    ]);
    final fiatResult = results[0];
    final cryptoResult = results[1];

    final fiatQuote = fiatResult.value as FiatRateQuote?;
    final cryptoQuote = cryptoResult.value as CryptoRateQuote?;

    final Map<String, double> fiatRates;
    final Map<String, double> cryptoRates;
    final DateTime? fiatUpdatedAt;
    final DateTime? cryptoUpdatedAt;
    final RateOriginInfo fiatInfo;
    final RateOriginInfo cryptoInfo;

    if (fiatQuote != null) {
      fiatRates = fiatQuote.unitsPerUsd;
      fiatUpdatedAt = fiatQuote.updatedAt;
      fiatInfo = RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: fiatQuote.updatedAt,
      );
    } else if (cached != null && cached.hasFiat) {
      fiatRates = cached.fiatUnitsPerUsd;
      fiatUpdatedAt = cached.fiatUpdatedAt;
      fiatInfo = RateOriginInfo(
        origin: RateOrigin.cached,
        updatedAt: cached.fiatUpdatedAt,
        errorMessage: fiatResult.errorMessage,
      );
    } else {
      fiatRates = const {};
      fiatUpdatedAt = null;
      fiatInfo = RateOriginInfo.unavailable(
        errorMessage: fiatResult.errorMessage,
      );
    }

    if (cryptoQuote != null) {
      cryptoRates = cryptoQuote.unitsPerUsd;
      cryptoUpdatedAt = cryptoQuote.updatedAt;
      cryptoInfo = RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: cryptoQuote.updatedAt,
      );
    } else if (cached != null && cached.hasCrypto) {
      cryptoRates = cached.cryptoUnitsPerUsd;
      cryptoUpdatedAt = cached.cryptoUpdatedAt;
      cryptoInfo = RateOriginInfo(
        origin: RateOrigin.cached,
        updatedAt: cached.cryptoUpdatedAt,
        errorMessage: cryptoResult.errorMessage,
      );
    } else {
      cryptoRates = const {};
      cryptoUpdatedAt = null;
      cryptoInfo = RateOriginInfo.unavailable(
        errorMessage: cryptoResult.errorMessage,
      );
    }

    final anyLive = fiatQuote != null || cryptoQuote != null;
    final hasAnyRates = fiatRates.isNotEmpty || cryptoRates.isNotEmpty;

    RateBundle? bundle;
    if (hasAnyRates) {
      bundle = RateBundle(
        fiatUnitsPerUsd: fiatRates,
        cryptoUnitsPerUsd: cryptoRates,
        fiatUpdatedAt: fiatUpdatedAt,
        cryptoUpdatedAt: cryptoUpdatedAt,
        fetchedAt: anyLive
            ? _clock().toUtc()
            : cached?.fetchedAt ?? _clock().toUtc(),
      );
    }

    // Persist only successful (or mixed live/cached) data. If every provider
    // failed, keep the existing cache untouched.
    if (anyLive && bundle != null) {
      try {
        await _storage.saveRateCache(bundle);
      } catch (error, stackTrace) {
        developer.log(
          'Could not persist the latest rate cache.',
          name: 'ExchangeRateRepository',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return RateRefreshResult(
      bundle: bundle,
      fiat: fiatInfo,
      crypto: cryptoInfo,
    );
  }

  Future<_FetchResult<Object>> _fetchFiat() async {
    try {
      final quote = await _fiatService.fetchLatestUsdRates();
      return _FetchResult.success(quote);
    } catch (error, stackTrace) {
      developer.log(
        'Fiat rate refresh failed.',
        name: 'ExchangeRateRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return _FetchResult.failure(_friendlyError(error));
    }
  }

  Future<_FetchResult<Object>> _fetchCrypto() async {
    try {
      final quote = await _cryptoService.fetchLatestUsdRates();
      return _FetchResult.success(quote);
    } catch (error, stackTrace) {
      developer.log(
        'Crypto rate refresh failed.',
        name: 'ExchangeRateRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return _FetchResult.failure(_friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    if (error is RateServiceException) return error.message;
    return 'The rate service failed unexpectedly.';
  }
}

class _FetchResult<T> {
  const _FetchResult._({this.value, this.errorMessage});

  factory _FetchResult.success(T value) => _FetchResult._(value: value);

  factory _FetchResult.failure(String message) =>
      _FetchResult._(errorMessage: message);

  final T? value;
  final String? errorMessage;
}
