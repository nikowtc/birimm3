// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/currency_catalog.dart';
import 'rate_service_exception.dart';

class CryptoRateQuote {
  const CryptoRateQuote({required this.unitsPerUsd, required this.updatedAt});

  final Map<String, double> unitsPerUsd;
  final DateTime? updatedAt;
}

abstract interface class CryptoRateService {
  Future<CryptoRateQuote> fetchLatestUsdRates();
}

/// Verified endpoint:
/// https://api.coingecko.com/api/v3/simple/price
///
/// The keyless public endpoint works, is IP rate-limited, and is cached by
/// CoinGecko for roughly 60 seconds. A free Demo API key can optionally be
/// supplied with:
/// `--dart-define=COINGECKO_API_KEY=your_demo_key`
class CoinGeckoCryptoRateService implements CryptoRateService {
  CoinGeckoCryptoRateService({
    required http.Client client,
    String? apiKey,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client,
       _apiKey = apiKey ?? _environmentApiKey;

  static const String _environmentApiKey = String.fromEnvironment(
    'COINGECKO_API_KEY',
  );

  static final Uri endpoint = Uri.https(
    'api.coingecko.com',
    '/api/v3/simple/price',
    {
      'ids': CurrencyCatalog.cryptoCurrencies
          .map((currency) => currency.coinGeckoId)
          .whereType<String>()
          .join(','),
      'vs_currencies': 'usd',
      'include_last_updated_at': 'true',
    },
  );

  final http.Client _client;
  final String _apiKey;
  final Duration timeout;

  @override
  Future<CryptoRateQuote> fetchLatestUsdRates() async {
    http.Response response;
    try {
      response = await _client
          .get(
            endpoint,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'CurrencyCalculator/1.0',
              if (_apiKey.isNotEmpty) 'x-cg-demo-api-key': _apiKey,
            },
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw RateServiceException(
        'The crypto price request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw RateServiceException(
        'Could not reach the crypto price service.',
        cause: error,
      );
    } catch (error) {
      throw RateServiceException(
        'Could not reach the crypto price service.',
        cause: error,
      );
    }

    if (response.statusCode == 429) {
      throw const RateServiceException(
        'CoinGecko is rate limiting requests. Try again shortly.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RateServiceException(
        'CoinGecko rejected the request (HTTP ${response.statusCode}).',
      );
    }
    if (response.statusCode != 200) {
      throw RateServiceException(
        'CoinGecko returned HTTP ${response.statusCode}.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw RateServiceException(
        'The crypto price response was not valid JSON.',
        cause: error,
      );
    }
    if (decoded is! Map) {
      throw const RateServiceException(
        'The crypto price response had an unexpected shape.',
      );
    }
    final json = Map<String, Object?>.from(decoded);

    final rates = <String, double>{};
    DateTime? latestUpdate;

    for (final asset in CurrencyCatalog.cryptoCurrencies) {
      final apiId = asset.coinGeckoId;
      if (apiId == null) continue;
      final rawEntry = json[apiId];
      if (rawEntry is! Map) continue;
      final entry = Map<String, Object?>.from(rawEntry);
      final rawPrice = entry['usd'];
      final price = rawPrice is num ? rawPrice.toDouble() : null;
      if (price == null || !price.isFinite || price <= 0) continue;

      final unitsPerUsd = 1 / price;
      if (!unitsPerUsd.isFinite || unitsPerUsd <= 0) continue;
      rates[asset.code] = unitsPerUsd;

      final rawUpdated = entry['last_updated_at'];
      if (rawUpdated is num && rawUpdated > 0) {
        final updated = DateTime.fromMillisecondsSinceEpoch(
          (rawUpdated * 1000).round(),
          isUtc: true,
        );
        if (latestUpdate == null || updated.isAfter(latestUpdate)) {
          latestUpdate = updated;
        }
      }
    }

    if (rates.isEmpty) {
      throw const RateServiceException(
        'CoinGecko returned no usable crypto prices.',
      );
    }

    return CryptoRateQuote(
      unitsPerUsd: Map.unmodifiable(rates),
      updatedAt: latestUpdate,
    );
  }
}
