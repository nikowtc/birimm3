import 'currency.dart';

/// A validated market quote from CoinGecko. Prices are quoted in USD.
class MarketQuote {
  const MarketQuote({
    required this.currency,
    required this.usdPrice,
    required this.fetchedAt,
    this.change24hPercent,
    this.marketCapUsd,
    this.volume24hUsd,
    this.imageUrl,
    this.providerUpdatedAt,
  });

  final Currency currency;
  final double usdPrice;
  final double? change24hPercent;
  final double? marketCapUsd;
  final double? volume24hUsd;
  final String? imageUrl;
  final DateTime? providerUpdatedAt;
  final DateTime fetchedAt;

  String get code => currency.code;

  Map<String, Object?> toJson() => {
    'code': currency.code,
    'name': currency.name,
    'symbol': currency.symbol,
    'kind': currency.kind.name,
    'coinGeckoId': currency.coinGeckoId,
    'yahooSymbol': currency.yahooSymbol,
    'quoteCurrency': currency.quoteCurrency,
    'usdPrice': usdPrice,
    'change24hPercent': change24hPercent,
    'marketCapUsd': marketCapUsd,
    'volume24hUsd': volume24hUsd,
    'imageUrl': imageUrl,
    'providerUpdatedAt': providerUpdatedAt?.toUtc().toIso8601String(),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };

  static MarketQuote? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final code = json['code'];
    final name = json['name'];
    final symbol = json['symbol'];
    final rawCoinGeckoId = json['coinGeckoId'];
    final rawYahooSymbol = json['yahooSymbol'];
    final rawPrice = json['usdPrice'];
    final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');

    if (code is! String ||
        code.trim().isEmpty ||
        name is! String ||
        symbol is! String ||
        rawPrice is! num ||
        fetchedAt == null) {
      return null;
    }
    final price = rawPrice.toDouble();
    if (!price.isFinite || price <= 0) return null;

    final coinGeckoId =
        rawCoinGeckoId is String && rawCoinGeckoId.trim().isNotEmpty
        ? rawCoinGeckoId.trim()
        : null;
    final kindName = json['kind'];
    var kind = coinGeckoId == null ? CurrencyKind.fiat : CurrencyKind.crypto;
    for (final candidate in CurrencyKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }

    return MarketQuote(
      currency: Currency(
        code: code.trim().toUpperCase(),
        name: name,
        symbol: symbol,
        kind: kind,
        coinGeckoId: coinGeckoId,
        yahooSymbol: rawYahooSymbol is String && rawYahooSymbol.isNotEmpty
            ? rawYahooSymbol
            : null,
        quoteCurrency: json['quoteCurrency'] is String
            ? json['quoteCurrency'] as String
            : 'USD',
      ),
      usdPrice: price,
      change24hPercent: _readNullableFinite(json['change24hPercent']),
      marketCapUsd: _readNullableFinite(json['marketCapUsd']),
      volume24hUsd: _readNullableFinite(json['volume24hUsd']),
      imageUrl:
          json['imageUrl'] is String && (json['imageUrl'] as String).isNotEmpty
          ? json['imageUrl'] as String
          : null,
      providerUpdatedAt: DateTime.tryParse(
        json['providerUpdatedAt'] as String? ?? '',
      )?.toUtc(),
      fetchedAt: fetchedAt.toUtc(),
    );
  }

  static double? _readNullableFinite(Object? value) {
    if (value is! num) return null;
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }
}

/// One or more CoinGecko market pages, combined in display order.
class MarketSnapshot {
  const MarketSnapshot({
    required this.quotes,
    required this.fetchedAt,
    this.providerUpdatedAt,
    this.nextPage = 2,
    this.hasMore = true,
  });

  static const int cacheVersion = 3;
  static const Set<int> readableCacheVersions = {2, 3};

  final List<MarketQuote> quotes;
  final DateTime fetchedAt;
  final DateTime? providerUpdatedAt;

  /// The next CoinGecko page to request when the user loads more.
  final int nextPage;

  /// Whether another page can be requested.
  final bool hasMore;

  Map<String, Object?> toJson() => {
    'version': cacheVersion,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'providerUpdatedAt': providerUpdatedAt?.toUtc().toIso8601String(),
    'nextPage': nextPage,
    'hasMore': hasMore,
    'quotes': quotes.map((quote) => quote.toJson()).toList(),
  };

  static MarketSnapshot? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final version = json['version'];
    if (version is! int || !readableCacheVersions.contains(version)) return null;
    final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
    final rawQuotes = json['quotes'];
    if (fetchedAt == null || rawQuotes is! List) return null;

    final quotes = <MarketQuote>[];
    final seen = <String>{};
    for (final raw in rawQuotes) {
      final quote = MarketQuote.fromJson(raw);
      if (quote == null || !seen.add(quote.code)) continue;
      quotes.add(quote);
    }
    if (quotes.isEmpty) return null;

    return MarketSnapshot(
      quotes: List.unmodifiable(quotes),
      fetchedAt: fetchedAt.toUtc(),
      providerUpdatedAt: DateTime.tryParse(
        json['providerUpdatedAt'] as String? ?? '',
      )?.toUtc(),
      nextPage: _readInt(json['nextPage'], fallback: 2),
      hasMore: json['hasMore'] is bool ? json['hasMore'] as bool : true,
    );
  }

  static int _readInt(Object? value, {required int fallback}) {
    return value is num && value >= 1 ? value.round() : fallback;
  }
}

enum PriceHistoryRange {
  day(1),
  week(7),
  month(30);

  const PriceHistoryRange(this.days);

  final int days;
}

class PricePoint {
  const PricePoint({required this.time, required this.usdPrice});

  final DateTime time;
  final double usdPrice;
}

class PriceHistory {
  const PriceHistory({
    required this.currencyCode,
    required this.range,
    required this.points,
    required this.fetchedAt,
  });

  static const int cacheVersion = 1;

  final String currencyCode;
  final PriceHistoryRange range;
  final List<PricePoint> points;
  final DateTime fetchedAt;

  Map<String, Object?> toJson() => {
    'version': cacheVersion,
    'currencyCode': currencyCode,
    'range': range.name,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'points': [
      for (final point in points)
        [point.time.toUtc().millisecondsSinceEpoch, point.usdPrice],
    ],
  };

  static PriceHistory? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    if (json['version'] != cacheVersion) return null;
    final code = json['currencyCode'];
    final rangeName = json['range'];
    final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
    final rawPoints = json['points'];
    if (code is! String || code.trim().isEmpty || rangeName is! String) {
      return null;
    }
    PriceHistoryRange? range;
    for (final candidate in PriceHistoryRange.values) {
      if (candidate.name == rangeName) {
        range = candidate;
        break;
      }
    }
    if (range == null || fetchedAt == null || rawPoints is! List) return null;

    final points = <PricePoint>[];
    for (final raw in rawPoints) {
      if (raw is! List || raw.length < 2) continue;
      final rawTime = raw[0];
      final rawPrice = raw[1];
      if (rawTime is! num || rawPrice is! num) continue;
      final price = rawPrice.toDouble();
      final time = DateTime.fromMillisecondsSinceEpoch(
        rawTime.round(),
        isUtc: true,
      );
      if (!price.isFinite || price <= 0) continue;
      points.add(PricePoint(time: time, usdPrice: price));
    }
    if (points.isEmpty) return null;
    points.sort((a, b) => a.time.compareTo(b.time));

    return PriceHistory(
      currencyCode: code.trim().toUpperCase(),
      range: range,
      points: List.unmodifiable(points),
      fetchedAt: fetchedAt.toUtc(),
    );
  }

  double? get firstPrice => points.isEmpty ? null : points.first.usdPrice;
  double? get lastPrice => points.isEmpty ? null : points.last.usdPrice;

  double? get periodChangePercent {
    final first = firstPrice;
    final last = lastPrice;
    if (first == null || last == null || first <= 0) return null;
    return (last - first) / first * 100;
  }

  double? get highPrice {
    if (points.isEmpty) return null;
    return points
        .map((point) => point.usdPrice)
        .reduce((a, b) => a > b ? a : b);
  }

  double? get lowPrice {
    if (points.isEmpty) return null;
    return points
        .map((point) => point.usdPrice)
        .reduce((a, b) => a < b ? a : b);
  }
}
