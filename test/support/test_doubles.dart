import 'dart:convert';

import 'package:calc2/models/app_preferences.dart';
import 'package:calc2/models/calculation_history.dart';
import 'package:calc2/models/calculation_row.dart';
import 'package:calc2/models/currency.dart';
import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/market_data.dart';
import 'package:calc2/models/rate_bundle.dart';
import 'package:calc2/models/rate_status.dart';
import 'package:calc2/models/user_favorites.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:calc2/services/crypto_rate_service.dart';
import 'package:calc2/services/exchange_rate_repository.dart';
import 'package:calc2/services/fiat_rate_service.dart';
import 'package:calc2/services/market_service.dart';

const Map<String, double> testFiatUnitsPerUsd = {
  'USD': 1,
  'EUR': 0.9,
  'GBP': 0.8,
  'TRY': 30,
  'AZN': 1.7,
  'JPY': 150,
  'CAD': 1.35,
};

const Map<String, double> testCryptoUnitsPerUsd = {
  'BTC': 1 / 50000,
  'ETH': 1 / 2000,
};

const Map<String, double> testCryptoUsdPrices = {
  'BTC': 50000,
  'ETH': 2000,
  'BNB': 300,
  'SOL': 100,
  'XRP': 0.5,
  'ADA': 0.4,
};

final DateTime testNow = DateTime.utc(2026, 10, 25, 12);

MarketSnapshot makeMarketSnapshot({
  DateTime? fetchedAt,
  List<String> codes = const ['BTC', 'ETH', 'BNB', 'SOL', 'XRP', 'ADA'],
  int nextPage = 2,
  bool hasMore = false,
}) {
  final timestamp = fetchedAt ?? testNow;
  final quotes = <MarketQuote>[];
  for (final code in codes) {
    final currency = CurrencyCatalog.byCode(code);
    final price = testCryptoUsdPrices[code];
    if (currency == null || price == null) continue;
    quotes.add(
      MarketQuote(
        currency: currency,
        usdPrice: price,
        change24hPercent: switch (code) {
          'BTC' => 2.5,
          'ETH' => -1.25,
          'SOL' => 4.0,
          _ => null,
        },
        marketCapUsd: price * 1000000,
        volume24hUsd: price * 10000,
        providerUpdatedAt: timestamp.subtract(const Duration(minutes: 2)),
        fetchedAt: timestamp,
      ),
    );
  }
  quotes.sort((a, b) => a.code.compareTo(b.code));
  return MarketSnapshot(
    quotes: List.unmodifiable(quotes),
    fetchedAt: timestamp,
    providerUpdatedAt: timestamp.subtract(const Duration(minutes: 2)),
    nextPage: nextPage,
    hasMore: hasMore,
  );
}

/// Deterministic synthetic CoinGecko page for pagination tests.
MarketSnapshot makeMarketPage({
  required int page,
  required int count,
  DateTime? fetchedAt,
  bool? hasMore,
}) {
  final timestamp = fetchedAt ?? testNow;
  final quotes = <MarketQuote>[
    for (var index = 0; index < count; index++)
      MarketQuote(
        currency: Currency(
          code:
              'P${page.toString().padLeft(2, '0')}'
              '${index.toString().padLeft(3, '0')}',
          name: 'Page $page Asset $index',
          symbol: 'T$page',
          kind: CurrencyKind.crypto,
          coinGeckoId: 'page-$page-asset-$index',
        ),
        usdPrice: (index + 1) * 10.0,
        change24hPercent: index.isEven ? 1.5 : -1.5,
        marketCapUsd: (count - index) * 1000000.0,
        volume24hUsd: 500000.0,
        providerUpdatedAt: timestamp.subtract(const Duration(minutes: 1)),
        fetchedAt: timestamp,
      ),
  ];
  return MarketSnapshot(
    quotes: List.unmodifiable(quotes),
    fetchedAt: timestamp,
    providerUpdatedAt: timestamp.subtract(const Duration(minutes: 1)),
    nextPage: page + 1,
    hasMore: hasMore ?? count >= 100,
  );
}

PriceHistory makePriceHistory({
  Currency? currency,
  PriceHistoryRange range = PriceHistoryRange.day,
  DateTime? fetchedAt,
}) {
  final asset = currency ?? CurrencyCatalog.byCode('BTC')!;
  final end = fetchedAt ?? testNow;
  final startPrice = testCryptoUsdPrices[asset.code] ?? 100;
  const pointCount = 12;
  final spanMilliseconds = range.days * Duration.millisecondsPerDay;
  final points = <PricePoint>[];
  for (var index = 0; index < pointCount; index++) {
    final progress = index / (pointCount - 1);
    points.add(
      PricePoint(
        time: end.subtract(
          Duration(milliseconds: (spanMilliseconds * (1 - progress)).round()),
        ),
        usdPrice: startPrice * (1 + 0.1 * progress),
      ),
    );
  }
  return PriceHistory(
    currencyCode: asset.code,
    range: range,
    points: List.unmodifiable(points),
    fetchedAt: end,
  );
}

RateBundle makeRateBundle({
  DateTime? fetchedAt,
  Map<String, double> fiat = testFiatUnitsPerUsd,
  Map<String, double> crypto = testCryptoUnitsPerUsd,
}) {
  final timestamp = fetchedAt ?? testNow;
  return RateBundle(
    fiatUnitsPerUsd: fiat,
    cryptoUnitsPerUsd: crypto,
    fiatUpdatedAt: timestamp,
    cryptoUpdatedAt: timestamp,
    fetchedAt: timestamp,
  );
}

CalculationHistoryEntry makeHistoryEntry({
  String id = 'history-1',
  List<CalculationRow>? rows,
  Currency? outputCurrency,
  double result = 90,
  double resultUsd = 100,
  Map<String, double>? unitsPerUsd,
  HistoryRateMeta? rateMeta,
  DateTime? createdAt,
}) {
  final output = outputCurrency ?? CurrencyCatalog.fiatCurrency('EUR');
  return CalculationHistoryEntry(
    id: id,
    rows: List.unmodifiable(
      rows ??
          [
            CalculationRow(
              id: 'row-1',
              amount: '100',
              currency: CurrencyCatalog.fiatCurrency('USD'),
            ),
          ],
    ),
    outputCurrency: output,
    result: result,
    resultUsd: resultUsd,
    unitsPerUsd: Map.unmodifiable(
      unitsPerUsd ?? {...testFiatUnitsPerUsd, ...testCryptoUnitsPerUsd},
    ),
    rateMeta:
        rateMeta ??
        HistoryRateMeta(
          fetchedAt: testNow,
          fiatOrigin: RateOrigin.live,
          cryptoOrigin: RateOrigin.live,
          fiatUpdatedAt: testNow,
          cryptoUpdatedAt: testNow,
        ),
    createdAt: createdAt ?? testNow,
  );
}

class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial])
    : values = Map<String, String>.from(initial ?? const {});

  final Map<String, String> values;
  bool failReads = false;
  bool failWrites = false;
  int writeCount = 0;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('Simulated storage read failure.');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    if (failWrites) {
      throw StateError('Simulated storage failure.');
    }
    values[key] = value;
  }
}

class FakeRatesRepository implements RatesRepository {
  FakeRatesRepository({this.cached, this.refreshResult, this.refreshError});

  RateBundle? cached;
  RateRefreshResult? refreshResult;
  Object? refreshError;
  int loadCalls = 0;
  int refreshCalls = 0;

  @override
  Future<RateBundle?> loadCachedRates() async {
    loadCalls++;
    return cached;
  }

  @override
  Future<RateRefreshResult> refresh({RateBundle? cached}) async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    final configured = refreshResult;
    if (configured != null) return configured;

    final bundle = this.cached ?? makeRateBundle();
    return RateRefreshResult(
      bundle: bundle,
      fiat: RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: bundle.fiatUpdatedAt,
      ),
      crypto: RateOriginInfo(
        origin: RateOrigin.live,
        updatedAt: bundle.cryptoUpdatedAt,
      ),
    );
  }
}

class FakeFiatRateService implements FiatRateService {
  FakeFiatRateService({this.quote, this.error});

  FiatRateQuote? quote;
  Object? error;
  int calls = 0;

  @override
  Future<FiatRateQuote> fetchLatestUsdRates() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return quote!;
  }
}

class FakeCryptoRateService implements CryptoRateService {
  FakeCryptoRateService({this.quote, this.error});

  CryptoRateQuote? quote;
  Object? error;
  int calls = 0;

  @override
  Future<CryptoRateQuote> fetchLatestUsdRates() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return quote!;
  }
}

class FakeMarketDataService implements MarketDataService {
  FakeMarketDataService({
    MarketSnapshot? snapshot,
    Map<int, MarketSnapshot>? pages,
    this.error,
    this.pageErrors = const {},
    this.historyError,
    this.delay = Duration.zero,
  }) : snapshot = snapshot ?? makeMarketSnapshot(),
       pages = pages ?? const {};

  MarketSnapshot snapshot;
  Map<int, MarketSnapshot> pages;
  Object? error;
  Map<int, Object> pageErrors;
  Object? historyError;
  Duration delay;
  int marketCalls = 0;
  int historyCalls = 0;
  final List<int> requestedPages = [];
  final List<int> requestedPageSizes = [];
  final List<PriceHistoryRange> requestedRanges = [];

  @override
  Future<MarketSnapshot> fetchMarkets({int page = 1, int perPage = 100}) async {
    marketCalls++;
    requestedPages.add(page);
    requestedPageSizes.add(perPage);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = error;
    if (failure != null) throw failure;
    final pageFailure = pageErrors[page];
    if (pageFailure != null) throw pageFailure;
    return pages[page] ?? snapshot;
  }

  @override
  Future<PriceHistory> fetchPriceHistory({
    required Currency currency,
    required PriceHistoryRange range,
  }) async {
    historyCalls++;
    requestedRanges.add(range);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = historyError;
    if (failure != null) throw failure;
    return makePriceHistory(
      currency: currency,
      range: range,
      fetchedAt: testNow,
    );
  }
}

Future<void> seedPreferences(
  MemoryKeyValueStore store, {
  AppThemePreference theme = AppThemePreference.dark,
  AppLanguage language = AppLanguage.en,
  String outputCurrency = 'EUR',
}) {
  return AppStorage(store).savePreferences(
    AppPreferences(
      theme: theme,
      language: language,
      outputCurrencyCode: outputCurrency,
    ),
  );
}

Future<void> seedHistory(
  MemoryKeyValueStore store,
  List<CalculationHistoryEntry> entries,
) {
  return AppStorage(store).saveHistory(entries);
}

Future<void> seedRateCache(MemoryKeyValueStore store, RateBundle bundle) {
  return AppStorage(store).saveRateCache(bundle);
}

Future<void> seedFavorites(MemoryKeyValueStore store, UserFavorites favorites) {
  return AppStorage(store).saveFavorites(favorites);
}

Future<void> seedMarketCache(
  MemoryKeyValueStore store,
  MarketSnapshot snapshot,
) {
  return AppStorage(store).saveMarketCache(snapshot);
}

Future<void> seedPriceHistory(MemoryKeyValueStore store, PriceHistory history) {
  return AppStorage(store).savePriceHistory(history);
}

String encodeJson(Object value) => jsonEncode(value);
