import 'dart:convert';

import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/market_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_doubles.dart';

void main() {
  test('market snapshots round-trip through cache JSON', () {
    final snapshot = makeMarketSnapshot();
    final decoded = jsonDecode(jsonEncode(snapshot.toJson()));

    final restored = MarketSnapshot.fromJson(decoded);

    expect(restored, isNotNull);
    expect(restored!.quotes, hasLength(snapshot.quotes.length));
    expect(restored.fetchedAt, snapshot.fetchedAt);
    expect(restored.quotes.first.code, snapshot.quotes.first.code);
    expect(restored.quotes.first.usdPrice, snapshot.quotes.first.usdPrice);
    expect(
      restored.quotes.first.change24hPercent,
      snapshot.quotes.first.change24hPercent,
    );
  });

  test('snapshot parsing rejects bad versions, prices, and duplicates', () {
    final snapshot = makeMarketSnapshot();
    final json = Map<String, Object?>.from(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map,
    );
    json['version'] = 999;
    expect(MarketSnapshot.fromJson(json), isNull);

    final duplicate = Map<String, Object?>.from(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map,
    );
    final quotes = [
      ...(duplicate['quotes'] as List),
      (duplicate['quotes'] as List).first,
      {...((duplicate['quotes'] as List).first as Map), 'usdPrice': 0},
    ];
    duplicate['quotes'] = quotes;
    final restored = MarketSnapshot.fromJson(duplicate);
    expect(restored, isNotNull);
    expect(restored!.quotes, hasLength(snapshot.quotes.length));
  });

  test('price histories round-trip and expose period statistics', () {
    final history = makePriceHistory(
      currency: CurrencyCatalog.byCode('ETH')!,
      range: PriceHistoryRange.month,
    );
    final decoded = jsonDecode(jsonEncode(history.toJson()));

    final restored = PriceHistory.fromJson(decoded);

    expect(restored, isNotNull);
    expect(restored!.currencyCode, 'ETH');
    expect(restored.range, PriceHistoryRange.month);
    expect(restored.points, hasLength(history.points.length));
    expect(restored.firstPrice, closeTo(2000, 0.000001));
    expect(restored.lastPrice, closeTo(2200, 0.000001));
    expect(restored.highPrice, closeTo(2200, 0.000001));
    expect(restored.lowPrice, closeTo(2000, 0.000001));
    expect(restored.periodChangePercent, closeTo(10, 0.000001));
  });

  test('price history parsing drops unusable points and bad ranges', () {
    final history = makePriceHistory();
    final json = Map<String, Object?>.from(
      jsonDecode(jsonEncode(history.toJson())) as Map,
    );
    final points = [...(json['points'] as List)];
    points.add([0, 0]);
    points.add([1, 'bad']);
    points.add(['bad', 1]);
    json['points'] = points;
    final restored = PriceHistory.fromJson(json);
    expect(restored, isNotNull);
    expect(restored!.points, hasLength(history.points.length));

    final badRange = Map<String, Object?>.from(json);
    badRange['range'] = 'year';
    expect(PriceHistory.fromJson(badRange), isNull);

    final noPoints = Map<String, Object?>.from(json);
    noPoints['points'] = [];
    expect(PriceHistory.fromJson(noPoints), isNull);
  });
}
