// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/currency.dart';
import '../models/market_data.dart';
import 'rate_service_exception.dart';

abstract interface class MarketDataService {
  Future<MarketSnapshot> fetchMarkets({int page = 1, int perPage = 100});

  Future<PriceHistory> fetchPriceHistory({
    required Currency currency,
    required PriceHistoryRange range,
  });
}

/// CoinGecko market overview and historical chart service.
///
/// Endpoints:
/// * `/api/v3/coins/markets` for live prices, 24h change, market cap, and volume.
/// * `/api/v3/coins/{id}/market_chart` for 24h, 7d, and 30d price history.
///
/// The market endpoint is not filtered by a fixed asset list, so the overview
/// can page through hundreds of assets. The keyless public API is IP
/// rate-limited. A Demo key can be supplied with
/// `--dart-define=COINGECKO_API_KEY=your_demo_key`.
class CoinGeckoMarketDataService implements MarketDataService {
  CoinGeckoMarketDataService({
    required http.Client client,
    String? apiKey,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client,
       _apiKey = apiKey ?? _environmentApiKey,
       _clock = clock ?? DateTime.now;

  static const String _environmentApiKey = String.fromEnvironment(
    'COINGECKO_API_KEY',
  );

  final http.Client _client;
  final String _apiKey;
  final DateTime Function() _clock;
  final Duration timeout;

  @override
  Future<MarketSnapshot> fetchMarkets({int page = 1, int perPage = 100}) async {
    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, 250);
    final uri = Uri.https('api.coingecko.com', '/api/v3/coins/markets', {
      'vs_currency': 'usd',
      'order': 'market_cap_desc',
      'per_page': '$safePerPage',
      'page': '$safePage',
      'sparkline': 'false',
      'price_change_percentage': '24h',
    });
    final decoded = await _getJson(uri);
    if (decoded is! List) {
      throw const RateServiceException(
        'The market response had an unexpected shape.',
      );
    }

    final quotes = <MarketQuote>[];
    final seen = <String>{};
    DateTime? latestProviderUpdate;
    final fetchedAt = _clock().toUtc();

    for (final raw in decoded) {
      if (raw is! Map) continue;
      final json = Map<String, Object?>.from(raw);
      final id = json['id'];
      final symbol = json['symbol'];
      final name = json['name'];
      if (id is! String ||
          id.trim().isEmpty ||
          symbol is! String ||
          name is! String) {
        continue;
      }
      final code = _marketCode(symbol);
      if (code == null || !seen.add(code)) continue;

      final rawPrice = json['current_price'];
      final price = rawPrice is num ? rawPrice.toDouble() : null;
      if (price == null || !price.isFinite || price <= 0) continue;

      final updatedAt = DateTime.tryParse(json['last_updated'] as String? ?? '')
          ?.toUtc();
      if (updatedAt != null &&
          (latestProviderUpdate == null ||
              updatedAt.isAfter(latestProviderUpdate))) {
        latestProviderUpdate = updatedAt;
      }

      final displayName = name.trim().isEmpty ? code : name.trim();
      quotes.add(
        MarketQuote(
          currency: Currency(
            code: code,
            name: displayName,
            symbol: symbol.trim().isEmpty ? code : symbol.trim().toUpperCase(),
            kind: CurrencyKind.crypto,
            coinGeckoId: id.trim(),
          ),
          usdPrice: price,
          change24hPercent: _nullableFinite(
            json['price_change_percentage_24h'],
          ),
          marketCapUsd: _nullableFinite(json['market_cap']),
          volume24hUsd: _nullableFinite(json['total_volume']),
          imageUrl:
              json['image'] is String && (json['image'] as String).isNotEmpty
              ? json['image'] as String
              : null,
          providerUpdatedAt: updatedAt,
          fetchedAt: fetchedAt,
        ),
      );
    }

    if (quotes.isEmpty) {
      throw const RateServiceException(
        'CoinGecko returned no usable market prices.',
      );
    }

    return MarketSnapshot(
      quotes: List.unmodifiable(quotes),
      fetchedAt: fetchedAt,
      providerUpdatedAt: latestProviderUpdate,
      nextPage: safePage + 1,
      hasMore: decoded.length >= safePerPage,
    );
  }

  @override
  Future<PriceHistory> fetchPriceHistory({
    required Currency currency,
    required PriceHistoryRange range,
  }) async {
    final apiId = currency.coinGeckoId;
    if (apiId == null || apiId.trim().isEmpty) {
      throw RateServiceException(
        'No CoinGecko identifier is available for ${currency.code}.',
      );
    }
    final uri = Uri.https(
      'api.coingecko.com',
      '/api/v3/coins/${Uri.encodeComponent(apiId)}/market_chart',
      {'vs_currency': 'usd', 'days': '${range.days}'},
    );
    final decoded = await _getJson(uri);
    if (decoded is! Map) {
      throw const RateServiceException(
        'The chart response had an unexpected shape.',
      );
    }
    final json = Map<String, Object?>.from(decoded);
    final rawPrices = json['prices'];
    if (rawPrices is! List) {
      throw const RateServiceException(
        'The chart response did not include prices.',
      );
    }

    final points = <PricePoint>[];
    for (final raw in rawPrices) {
      if (raw is! List || raw.length < 2) continue;
      final rawTime = raw[0];
      final rawPrice = raw[1];
      if (rawTime is! num) continue;
      final price = rawPrice is num ? rawPrice.toDouble() : null;
      if (price == null || !price.isFinite || price <= 0) continue;
      points.add(
        PricePoint(
          time: DateTime.fromMillisecondsSinceEpoch(
            rawTime.round(),
            isUtc: true,
          ),
          usdPrice: price,
        ),
      );
    }
    if (points.isEmpty) {
      throw const RateServiceException(
        'CoinGecko returned no usable chart data.',
      );
    }
    points.sort((a, b) => a.time.compareTo(b.time));

    return PriceHistory(
      currencyCode: currency.code,
      range: range,
      points: List.unmodifiable(points),
      fetchedAt: _clock().toUtc(),
    );
  }

  Future<Object?> _getJson(Uri uri) async {
    http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Birimm/1.0',
              if (_apiKey.isNotEmpty) 'x-cg-demo-api-key': _apiKey,
            },
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw RateServiceException(
        'The CoinGecko request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw RateServiceException('Could not reach CoinGecko.', cause: error);
    } catch (error) {
      throw RateServiceException('Could not reach CoinGecko.', cause: error);
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

    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw RateServiceException(
        'The CoinGecko response was not valid JSON.',
        cause: error,
      );
    }
  }

  static String? _marketCode(String raw) {
    final normalized = raw.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (normalized.isEmpty || normalized.length > 14) return null;
    return normalized;
  }

  static double? _nullableFinite(Object? value) {
    if (value is! num) return null;
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }
}
