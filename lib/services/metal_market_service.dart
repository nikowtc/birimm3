// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/currency_catalog.dart';
import '../models/market_data.dart';
import 'market_constants.dart';
import 'rate_service_exception.dart';

/// Precious-metal spot quotes from Gold API.
///
/// The keyless endpoint `https://api.gold-api.com/price/XAU` (and `XAG`)
/// returns a USD price per troy ounce. The app derives the per-gram price so
/// both ounce and gram assets share a single coherent quote source.
abstract interface class MetalMarketService {
  Future<MarketSnapshot> fetchQuotes();
}

class GoldApiMetalMarketService implements MetalMarketService {
  GoldApiMetalMarketService({
    required http.Client client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  static const String _host = 'api.gold-api.com';
  static const List<String> _symbols = ['XAU', 'XAG'];

  final http.Client _client;
  final DateTime Function() _clock;
  final Duration timeout;

  @override
  Future<MarketSnapshot> fetchQuotes() async {
    final results = await Future.wait(
      [
        for (final symbol in _symbols)
          _fetchMetal(symbol).then<Object?>((quote) => quote).catchError((
            Object error,
          ) {
            return error;
          }),
      ],
    );

    final fetchedAt = _clock().toUtc();
    final quotes = <MarketQuote>[];
    DateTime? latestProviderUpdate;
    MarketServiceException? firstFailure;

    for (final result in results) {
      if (result is MarketServiceException) {
        firstFailure ??= result;
        continue;
      }
      if (result is! _MetalPrice) continue;
      final ounce = CurrencyCatalog.byCode(result.symbol);
      final gram = CurrencyCatalog.byCode('${result.symbol}_G');
      if (ounce == null || gram == null) continue;

      quotes.add(
        MarketQuote(
          currency: ounce,
          usdPrice: result.ounceUsd,
          providerUpdatedAt: result.updatedAt,
          fetchedAt: fetchedAt,
        ),
      );
      final gramPrice = result.ounceUsd / gramsPerTroyOunce;
      if (gramPrice.isFinite && gramPrice > 0) {
        quotes.add(
          MarketQuote(
            currency: gram,
            usdPrice: gramPrice,
            providerUpdatedAt: result.updatedAt,
            fetchedAt: fetchedAt,
          ),
        );
      }
      final updated = result.updatedAt;
      if (updated != null &&
          (latestProviderUpdate == null ||
              updated.isAfter(latestProviderUpdate))) {
        latestProviderUpdate = updated;
      }
    }

    if (quotes.isEmpty) {
      throw firstFailure ??
          const MarketServiceException(
            'Gold API returned no usable metal prices.',
            reason: MarketFailure.provider,
          );
    }

    return MarketSnapshot(
      quotes: List.unmodifiable(quotes),
      fetchedAt: fetchedAt,
      providerUpdatedAt: latestProviderUpdate,
      nextPage: 2,
      hasMore: false,
    );
  }

  Future<_MetalPrice> _fetchMetal(String symbol) async {
    final response = await _getJson(
      Uri.https(_host, '/price/$symbol'),
      symbol: symbol,
    );
    if (response is! Map) {
      throw const MarketServiceException(
        'The Gold API response had an unexpected shape.',
        reason: MarketFailure.provider,
      );
    }
    final json = Map<String, Object?>.from(response);
    final rawPrice = json['price'];
    final price = rawPrice is num ? rawPrice.toDouble() : null;
    if (price == null || !price.isFinite || price <= 0) {
      throw MarketServiceException(
        'Gold API returned no usable price for $symbol.',
        reason: MarketFailure.provider,
      );
    }
    final currency = (json['currency'] as String?)?.trim().toUpperCase();
    if (currency != null && currency.isNotEmpty && currency != 'USD') {
      throw MarketServiceException(
        'Gold API quoted $symbol in $currency, which cannot be normalized.',
        reason: MarketFailure.missingRate,
      );
    }
    final updatedAt = DateTime.tryParse(
      json['updatedAt'] as String? ?? '',
    )?.toUtc();
    return _MetalPrice(
      symbol: symbol,
      ounceUsd: price,
      updatedAt: updatedAt,
    );
  }

  Future<Object?> _getJson(Uri uri, {required String symbol}) async {
    http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'Birimm/1.1',
            },
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw MarketServiceException(
        'The Gold API request for $symbol timed out.',
        reason: MarketFailure.network,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw MarketServiceException(
        'Could not reach Gold API.',
        reason: MarketFailure.network,
        cause: error,
      );
    } catch (error) {
      throw MarketServiceException(
        'Could not reach Gold API.',
        reason: MarketFailure.network,
        cause: error,
      );
    }

    if (response.statusCode == 429) {
      throw MarketServiceException(
        'Gold API is rate limiting requests for $symbol. Try again shortly.',
        reason: MarketFailure.rateLimit,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw MarketServiceException(
        'Gold API rejected the request for $symbol '
        '(HTTP ${response.statusCode}).',
        reason: MarketFailure.provider,
      );
    }
    if (response.statusCode != 200) {
      throw MarketServiceException(
        'Gold API returned HTTP ${response.statusCode} for $symbol.',
        reason: MarketFailure.provider,
      );
    }

    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw MarketServiceException(
        'The Gold API response for $symbol was not valid JSON.',
        reason: MarketFailure.provider,
        cause: error,
      );
    }
  }
}

class _MetalPrice {
  const _MetalPrice({
    required this.symbol,
    required this.ounceUsd,
    this.updatedAt,
  });

  final String symbol;
  final double ounceUsd;
  final DateTime? updatedAt;
}
