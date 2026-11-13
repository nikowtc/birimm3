// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/currency.dart';
import '../models/currency_catalog.dart';
import '../models/market_data.dart';
import 'market_constants.dart';
import 'rate_service_exception.dart';

/// Live stock/index quotes and historical charts from Yahoo Finance.
///
/// The keyless endpoints are:
/// * `/v7/finance/spark` for one batch snapshot of every curated ticker.
/// * `/v8/finance/chart/{symbol}` for a single history series.
///
/// Yahoo does not send CORS headers, so Flutter web needs a proxy. Set
/// `--dart-define=BIRIMM_MARKET_PROXY=https://proxy.example/?url=` (a base URL
/// that accepts an encoded `url` query parameter) or a URL containing `{url}`.
/// Native builds work directly. Without a proxy, web throws
/// [MarketFailure.needProxy] instead of pretending the data is empty.
abstract interface class EquityMarketService {
  Future<MarketSnapshot> fetchQuotes();

  Future<PriceHistory> fetchPriceHistory({
    required Currency currency,
    required PriceHistoryRange range,
  });
}

class YahooFinanceMarketService implements EquityMarketService {
  YahooFinanceMarketService({
    required http.Client client,
    Map<String, double> Function()? fiatUnitsPerUsd,
    String? proxyUrl,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client,
       _fiatUnitsPerUsd = fiatUnitsPerUsd ?? (() => const {}),
       _proxyUrl = proxyUrl ?? _environmentProxy,
       _clock = clock ?? DateTime.now;

  static const String _environmentProxy = String.fromEnvironment(
    'BIRIMM_MARKET_PROXY',
  );

  static const String _host = 'query1.finance.yahoo.com';

  final http.Client _client;
  final Map<String, double> Function() _fiatUnitsPerUsd;
  final String _proxyUrl;
  final DateTime Function() _clock;
  final Duration timeout;

  @override
  Future<MarketSnapshot> fetchQuotes() async {
    if (kIsWeb && _proxyUrl.trim().isEmpty) {
      throw const MarketServiceException(
        'Stock and index quotes need a CORS proxy in this browser build.',
        reason: MarketFailure.needProxy,
      );
    }

    final symbols = <String>[
      for (final currency in CurrencyCatalog.stockCurrencies)
        if (currency.yahooSymbol != null) currency.yahooSymbol!,
      for (final currency in CurrencyCatalog.indexCurrencies)
        if (currency.yahooSymbol != null) currency.yahooSymbol!,
    ];
    if (symbols.isEmpty) {
      throw const MarketServiceException(
        'No Yahoo Finance symbols are configured.',
        reason: MarketFailure.provider,
      );
    }

    final uri = Uri.https(_host, '/v7/finance/spark', {
      'symbols': symbols.join(','),
      'range': '5d',
      'interval': '1d',
    });
    final decoded = await _getJson(uri);
    final results = _sparkResults(decoded);
    if (results.isEmpty) {
      final providerError = _providerError(decoded);
      throw MarketServiceException(
        providerError ?? 'Yahoo Finance returned no usable stock prices.',
        reason: MarketFailure.provider,
      );
    }

    final fetchedAt = _clock().toUtc();
    final fiat = _fiatUnitsPerUsd();
    final quotes = <MarketQuote>[];
    final seen = <String>{};
    DateTime? latestProviderUpdate;

    for (final raw in results) {
      if (raw is! Map) continue;
      final json = Map<String, Object?>.from(raw);
      final quote = _parseQuote(json, fetchedAt: fetchedAt, fiat: fiat);
      if (quote == null || !seen.add(quote.code)) continue;
      quotes.add(quote);
      final updated = quote.providerUpdatedAt;
      if (updated != null &&
          (latestProviderUpdate == null ||
              updated.isAfter(latestProviderUpdate))) {
        latestProviderUpdate = updated;
      }
    }

    if (quotes.isEmpty) {
      throw const MarketServiceException(
        'Yahoo Finance returned no usable stock prices.',
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

  @override
  Future<PriceHistory> fetchPriceHistory({
    required Currency currency,
    required PriceHistoryRange range,
  }) async {
    if (kIsWeb && _proxyUrl.trim().isEmpty) {
      throw const MarketServiceException(
        'Charts for this asset need a CORS proxy in this browser build.',
        reason: MarketFailure.needProxy,
      );
    }

    final symbol = _historySymbol(currency);
    if (symbol == null) {
      throw MarketServiceException(
        'No Yahoo Finance symbol is available for ${currency.code}.',
        reason: MarketFailure.provider,
      );
    }
    final uri = Uri.https(_host, '/v8/finance/chart/$symbol', {
      'range': switch (range) {
        PriceHistoryRange.day => '1d',
        PriceHistoryRange.week => '5d',
        PriceHistoryRange.month => '1mo',
      },
      'interval': switch (range) {
        PriceHistoryRange.day => '5m',
        PriceHistoryRange.week => '30m',
        PriceHistoryRange.month => '1d',
      },
    });
    final decoded = await _getJson(uri);
    if (decoded is! Map) {
      throw const MarketServiceException(
        'The Yahoo Finance chart response had an unexpected shape.',
        reason: MarketFailure.provider,
      );
    }
    final chart = Map<String, Object?>.from(decoded)['chart'];
    if (chart is! Map) {
      throw const MarketServiceException(
        'The Yahoo Finance chart response had an unexpected shape.',
        reason: MarketFailure.provider,
      );
    }
    final chartJson = Map<String, Object?>.from(chart);
    final providerError = chartJson['error'];
    if (providerError is Map && providerError.isNotEmpty) {
      throw MarketServiceException(
        'Yahoo Finance could not build this chart.',
        reason: MarketFailure.provider,
      );
    }
    final rawResults = chartJson['result'];
    if (rawResults is! List || rawResults.isEmpty || rawResults.first is! Map) {
      throw const MarketServiceException(
        'The Yahoo Finance chart response contained no prices.',
        reason: MarketFailure.provider,
      );
    }
    final result = Map<String, Object?>.from(rawResults.first as Map);
    final meta = result['meta'] is Map
        ? Map<String, Object?>.from(result['meta'] as Map)
        : const <String, Object?>{};
    final quoteCurrency =
        (meta['currency'] as String?)?.trim().toUpperCase() ??
        currency.quoteCurrency;
    final unitsPerUsd = _unitsPerUsd(quoteCurrency);
    if (unitsPerUsd == null) {
      throw MarketServiceException(
        'No $quoteCurrency to USD rate is available for this chart.',
        reason: MarketFailure.missingRate,
      );
    }

    final rawTimestamps = result['timestamp'];
    final indicators = result['indicators'];
    if (rawTimestamps is! List || indicators is! Map) {
      throw const MarketServiceException(
        'The Yahoo Finance chart response contained no prices.',
        reason: MarketFailure.provider,
      );
    }
    final rawQuote = (Map<String, Object?>.from(indicators))['quote'];
    if (rawQuote is! List || rawQuote.isEmpty || rawQuote.first is! Map) {
      throw const MarketServiceException(
        'The Yahoo Finance chart response contained no prices.',
        reason: MarketFailure.provider,
      );
    }
    final closes = Map<String, Object?>.from(rawQuote.first as Map)['close'];
    if (closes is! List) {
      throw const MarketServiceException(
        'The Yahoo Finance chart response contained no prices.',
        reason: MarketFailure.provider,
      );
    }

    final isGram = currency.isMetal && currency.code.endsWith('_G');
    final points = <PricePoint>[];
    final count = rawTimestamps.length < closes.length
        ? rawTimestamps.length
        : closes.length;
    for (var index = 0; index < count; index++) {
      final rawTime = rawTimestamps[index];
      final rawClose = closes[index];
      if (rawTime is! num || rawClose is! num) continue;
      var price = rawClose.toDouble() / unitsPerUsd;
      if (isGram) price /= gramsPerTroyOunce;
      if (!price.isFinite || price <= 0) continue;
      points.add(
        PricePoint(
          time: DateTime.fromMillisecondsSinceEpoch(
            (rawTime * 1000).round(),
            isUtc: true,
          ),
          usdPrice: price,
        ),
      );
    }
    if (points.isEmpty) {
      throw const MarketServiceException(
        'Yahoo Finance returned no usable chart data.',
        reason: MarketFailure.provider,
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

  MarketQuote? _parseQuote(
    Map<String, Object?> json, {
    required DateTime fetchedAt,
    required Map<String, double> fiat,
  }) {
    final rawResponses = json['response'];
    Map<String, Object?> body;
    if (rawResponses is List &&
        rawResponses.isNotEmpty &&
        rawResponses.first is Map) {
      body = Map<String, Object?>.from(rawResponses.first as Map);
    } else {
      body = json;
    }
    final rawMeta = body['meta'] ?? json['meta'];
    final meta = rawMeta is Map
        ? Map<String, Object?>.from(rawMeta)
        : const <String, Object?>{};
    final symbol =
        (meta['symbol'] as String?)?.trim() ??
        (json['symbol'] as String?)?.trim();
    if (symbol == null || symbol.isEmpty) return null;
    final currency =
        CurrencyCatalog.byYahooSymbol(symbol) ??
        CurrencyCatalog.byYahooSymbol(
          symbol.replaceAll(RegExp(r'\.IS$'), '.IS'),
        );
    if (currency == null) return null;

    final closes = _closes(body);
    final rawPrice = meta['regularMarketPrice'];
    var price = rawPrice is num ? rawPrice.toDouble() : null;
    price ??= _lastFinite(closes);
    if (price == null || !price.isFinite || price <= 0) return null;

    final quoteCurrency =
        (meta['currency'] as String?)?.trim().toUpperCase() ??
        currency.quoteCurrency;
    final unitsPerUsd = _unitsPerUsd(quoteCurrency, fiat: fiat);
    if (unitsPerUsd == null) return null;
    final usdPrice = price / unitsPerUsd;
    if (!usdPrice.isFinite || usdPrice <= 0) return null;

    final rawPrevious =
        meta['chartPreviousClose'] ?? meta['previousClose'] ?? meta['regularMarketPreviousClose'];
    var previous = rawPrevious is num ? rawPrevious.toDouble() : null;
    previous ??= _previousFinite(closes);
    final change = previous == null || previous <= 0
        ? null
        : (price - previous) / previous * 100;

    final rawUpdated = meta['regularMarketTime'];
    final providerUpdatedAt = rawUpdated is num && rawUpdated > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            (rawUpdated * 1000).round(),
            isUtc: true,
          )
        : null;

    return MarketQuote(
      currency: currency,
      usdPrice: usdPrice,
      change24hPercent: change,
      providerUpdatedAt: providerUpdatedAt,
      fetchedAt: fetchedAt,
    );
  }

  List<double> _closes(Map<String, Object?> body) {
    final indicators = body['indicators'];
    if (indicators is! Map) return const [];
    final quote = (Map<String, Object?>.from(indicators))['quote'];
    if (quote is! List || quote.isEmpty || quote.first is! Map) return const [];
    final closes = Map<String, Object?>.from(quote.first as Map)['close'];
    if (closes is! List) return const [];
    return [
      for (final value in closes)
        if (value is num && value.toDouble().isFinite) value.toDouble(),
    ];
  }

  double? _unitsPerUsd(String code, {Map<String, double>? fiat}) {
    if (code == 'USD') return 1;
    final rates = fiat ?? _fiatUnitsPerUsd();
    final value = rates[code];
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  String? _historySymbol(Currency currency) {
    if (currency.isMetal) {
      return switch (currency.code) {
        'XAU' || 'XAU_G' => 'GC=F',
        'XAG' || 'XAG_G' => 'SI=F',
        _ => null,
      };
    }
    return currency.yahooSymbol;
  }

  Future<Object?> _getJson(Uri target) async {
    final uri = _proxyUri(target);
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
        'The Yahoo Finance request timed out.',
        reason: MarketFailure.network,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw MarketServiceException(
        'Could not reach Yahoo Finance.',
        reason: MarketFailure.network,
        cause: error,
      );
    } catch (error) {
      throw MarketServiceException(
        'Could not reach Yahoo Finance.',
        reason: MarketFailure.network,
        cause: error,
      );
    }

    if (response.statusCode == 429) {
      throw const MarketServiceException(
        'Yahoo Finance is rate limiting requests. Try again shortly.',
        reason: MarketFailure.rateLimit,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw MarketServiceException(
        'Yahoo Finance rejected the request (HTTP ${response.statusCode}).',
        reason: MarketFailure.provider,
      );
    }
    if (response.statusCode != 200) {
      throw MarketServiceException(
        'Yahoo Finance returned HTTP ${response.statusCode}.',
        reason: MarketFailure.provider,
      );
    }

    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw MarketServiceException(
        'The Yahoo Finance response was not valid JSON.',
        reason: MarketFailure.provider,
        cause: error,
      );
    }
  }

  Uri _proxyUri(Uri target) {
    final raw = _proxyUrl.trim();
    if (raw.isEmpty) return target;
    if (raw.contains('{url}')) {
      return Uri.parse(
        raw.replaceAll('{url}', Uri.encodeComponent(target.toString())),
      );
    }
    final base = Uri.tryParse(raw);
    if (base == null || !base.hasScheme) {
      throw const MarketServiceException(
        'BIRIMM_MARKET_PROXY is not a valid URL.',
        reason: MarketFailure.provider,
      );
    }
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        'url': target.toString(),
      },
    );
  }

  List<Object?> _sparkResults(Object? decoded) {
    if (decoded is! Map) return const [];
    final spark = Map<String, Object?>.from(decoded)['spark'];
    if (spark is List) return spark;
    if (spark is! Map) return const [];
    final result = Map<String, Object?>.from(spark)['result'];
    return result is List ? result : const [];
  }

  String? _providerError(Object? decoded) {
    if (decoded is! Map) return null;
    final spark = Map<String, Object?>.from(decoded)['spark'];
    if (spark is! Map) return null;
    final error = Map<String, Object?>.from(spark)['error'];
    if (error is! Map) return null;
    final description = error['description'];
    return description is String && description.trim().isNotEmpty
        ? 'Yahoo Finance: ${description.trim()}'
        : null;
  }

  double? _lastFinite(List<double> values) {
    for (var index = values.length - 1; index >= 0; index--) {
      if (values[index].isFinite) return values[index];
    }
    return null;
  }

  double? _previousFinite(List<double> values) {
    var seenLast = false;
    for (var index = values.length - 1; index >= 0; index--) {
      if (!values[index].isFinite) continue;
      if (!seenLast) {
        seenLast = true;
        continue;
      }
      return values[index];
    }
    return null;
  }
}
