import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/market_data.dart';
import 'package:calc2/providers/markets_controller.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_doubles.dart';

void main() {
  late MemoryKeyValueStore store;
  late AppStorage storage;
  late FakeMarketDataService service;

  setUp(() {
    store = MemoryKeyValueStore();
    storage = AppStorage(store);
    service = FakeMarketDataService();
  });

  MarketsController createController({Duration? autoRefreshInterval}) {
    return MarketsController(
      service: service,
      storage: storage,
      autoRefreshInterval: autoRefreshInterval,
      clock: () => testNow,
    );
  }

  test('loads a cached snapshot and then replaces it with live data', () async {
    final cached = makeMarketSnapshot(
      fetchedAt: testNow.subtract(const Duration(minutes: 10)),
    );
    await seedMarketCache(store, cached);
    final controller = createController();
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.isInitialized, isTrue);
    expect(controller.quotes, hasLength(cached.quotes.length));
    expect(controller.status.isCached, isTrue);
    expect(controller.isUsingCachedData, isTrue);
    expect(controller.quoteFor('btc')?.usdPrice, 50000);

    service.snapshot = makeMarketSnapshot(fetchedAt: testNow);
    await controller.refresh();

    expect(controller.status.isLive, isTrue);
    expect(controller.isUsingCachedData, isFalse);
    expect(controller.fetchedAt, testNow);
    expect(controller.errorMessage, isNull);
    final persisted = await storage.loadMarketCache();
    expect(persisted, isNotNull);
    expect(persisted!.fetchedAt, testNow);
  });

  test('refresh failure keeps cached prices and reports the error', () async {
    await seedMarketCache(
      store,
      makeMarketSnapshot(fetchedAt: testNow.subtract(const Duration(hours: 1))),
    );
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();
    service.error = Exception('Network down');

    await controller.refresh();

    expect(controller.hasQuotes, isTrue);
    expect(controller.status.isCached, isTrue);
    expect(controller.errorMessage, contains('Network down'));
    expect(await storage.loadMarketCache(), isNotNull);
  });

  test('refresh failure without cache stays unavailable', () async {
    service.error = Exception('Provider offline');
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(controller.hasQuotes, isFalse);
    await controller.refresh();

    expect(controller.quotes, isEmpty);
    expect(controller.status.isUnavailable, isTrue);
    expect(controller.errorMessage, contains('Provider offline'));
  });

  test('corrupt cache is ignored without fabricating prices', () async {
    store.values[AppStorage.marketCacheKey] = 'not json';
    final controller = createController();
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.quotes, isEmpty);
    expect(controller.status.isUnavailable, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('refreshIfStale skips fresh data and refreshes stale data', () async {
    await seedMarketCache(
      store,
      makeMarketSnapshot(
        fetchedAt: testNow.subtract(const Duration(minutes: 1)),
      ),
    );
    final fresh = createController();
    addTearDown(fresh.dispose);
    await fresh.initialize();
    await fresh.refreshIfStale();
    expect(service.marketCalls, 0);

    final staleStore = MemoryKeyValueStore();
    final staleStorage = AppStorage(staleStore);
    await seedMarketCache(
      staleStore,
      makeMarketSnapshot(fetchedAt: testNow.subtract(const Duration(hours: 1))),
    );
    final staleService = FakeMarketDataService();
    final stale = MarketsController(
      service: staleService,
      storage: staleStorage,
      clock: () => testNow,
    );
    addTearDown(stale.dispose);
    await stale.initialize();
    await stale.refreshIfStale();
    expect(staleService.marketCalls, 1);
    expect(stale.status.isLive, isTrue);
  });

  test('loads additional pages without dropping existing quotes', () async {
    final first = makeMarketPage(page: 1, count: 100);
    final second = makeMarketPage(page: 2, count: 3);
    service
      ..snapshot = makeMarketPage(page: 1, count: 100)
      ..pages = {1: first, 2: second};
    final controller = createController();
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.refresh();

    expect(controller.quotes, hasLength(100));
    expect(controller.hasMore, isTrue);
    expect(controller.loadedQuoteCount, 100);

    await controller.loadMore();

    expect(controller.quotes, hasLength(103));
    expect(controller.quotes.first.code, 'P01000');
    expect(controller.quotes.last.code, 'P02002');
    expect(controller.hasMore, isFalse);
    expect(service.requestedPages, [1, 2]);
    expect(service.requestedPageSizes, [100, 100]);
    expect(controller.errorMessage, isNull);
    final persisted = await storage.loadMarketCache();
    expect(persisted?.quotes, hasLength(103));
  });

  test('refreshing an expanded market reloads each loaded page', () async {
    service
      ..snapshot = makeMarketPage(page: 1, count: 100)
      ..pages = {
        1: makeMarketPage(page: 1, count: 100),
        2: makeMarketPage(page: 2, count: 4),
      };
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.refresh();
    await controller.loadMore();
    service.requestedPages.clear();

    await controller.refresh();

    expect(service.requestedPages, [1, 2]);
    expect(controller.quotes, hasLength(104));
    expect(controller.hasMore, isFalse);
    expect(controller.status.isLive, isTrue);
  });

  test('page refresh failure preserves the expanded snapshot', () async {
    service
      ..snapshot = makeMarketPage(page: 1, count: 100)
      ..pages = {
        1: makeMarketPage(page: 1, count: 100),
        2: makeMarketPage(page: 2, count: 4),
      };
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.refresh();
    await controller.loadMore();
    service.error = Exception('Second refresh offline');

    await controller.refresh();

    expect(controller.quotes, hasLength(104));
    expect(controller.status.isCached, isTrue);
    expect(controller.errorMessage, contains('Second refresh offline'));
    expect(controller.isLoading, isFalse);
  });

  test(
    'a failed additional page keeps loaded quotes and exposes the error',
    () async {
      service
        ..snapshot = makeMarketPage(page: 1, count: 100)
        ..pages = {1: makeMarketPage(page: 1, count: 100)}
        ..pageErrors = {2: Exception('Page two unavailable')};
      final controller = createController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.refresh();

      await controller.loadMore();

      expect(controller.quotes, hasLength(100));
      expect(controller.isLoadingMore, isFalse);
      expect(controller.errorMessage, contains('Page two unavailable'));
      expect(controller.status.isLive, isTrue);
    },
  );

  test('does not request more pages at the five-page ceiling', () async {
    service.snapshot = makeMarketPage(page: 1, count: 100);
    service.pages = {
      for (var page = 1; page <= 5; page++)
        page: makeMarketPage(page: page, count: 100),
    };
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.refresh();
    for (var page = 2; page <= 5; page++) {
      await controller.loadMore();
    }

    expect(controller.quotes, hasLength(500));
    expect(controller.hasMore, isFalse);
    await controller.loadMore();
    expect(service.requestedPages, [1, 2, 3, 4, 5]);
  });

  test('loads live history, caches it, and reuses the live result', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();

    final history = await controller.loadHistory(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.week,
    );

    expect(history, isNotNull);
    expect(history!.range, PriceHistoryRange.week);
    expect(history.fetchedAt, testNow);
    expect(service.historyCalls, 1);
    expect(service.requestedRanges, [PriceHistoryRange.week]);
    final state = controller.historyState(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.week,
    );
    expect(state.history, isNotNull);
    expect(state.status.isLive, isTrue);
    expect(
      (await storage.loadPriceHistory(
        'BTC',
        PriceHistoryRange.week,
      ))?.fetchedAt,
      testNow,
    );

    await controller.loadHistory(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.week,
    );
    expect(service.historyCalls, 1);

    await controller.loadHistory(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.week,
      forceRefresh: true,
    );
    expect(service.historyCalls, 2);
  });

  test('cached history is used when a chart refresh fails', () async {
    final cached = makePriceHistory(
      currency: CurrencyCatalog.byCode('BTC')!,
      range: PriceHistoryRange.day,
      fetchedAt: testNow.subtract(const Duration(hours: 2)),
    );
    await seedPriceHistory(store, cached);
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();
    service.historyError = Exception('Chart endpoint offline');

    final history = await controller.loadHistory(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.day,
    );

    expect(history, isNotNull);
    expect(history!.fetchedAt, cached.fetchedAt);
    final state = controller.historyState(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.day,
    );
    expect(state.history, isNotNull);
    expect(state.status.isCached, isTrue);
    expect(state.errorMessage, contains('Chart endpoint offline'));
  });

  test('chart failure without cache exposes an unavailable state', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    await controller.initialize();
    service.historyError = Exception('Chart endpoint offline');

    final history = await controller.loadHistory(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.day,
    );

    expect(history, isNull);
    final state = controller.historyState(
      CurrencyCatalog.byCode('BTC')!,
      PriceHistoryRange.day,
    );
    expect(state.history, isNull);
    expect(state.isLoading, isFalse);
    expect(state.status.isUnavailable, isTrue);
    expect(state.errorMessage, contains('Chart endpoint offline'));
  });
}
