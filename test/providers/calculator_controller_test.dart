import 'package:calc2/models/app_preferences.dart';
import 'package:calc2/models/currency.dart';
import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/market_data.dart';
import 'package:calc2/models/rate_status.dart';
import 'package:calc2/models/user_favorites.dart';
import 'package:calc2/providers/calculator_controller.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_doubles.dart';

void main() {
  late MemoryKeyValueStore store;
  late AppStorage storage;
  late FakeRatesRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    storage = AppStorage(store);
    repository = FakeRatesRepository(cached: makeRateBundle());
  });

  Future<CalculatorController> createController({
    DateTime Function()? clock,
    Duration? autoRefreshInterval,
  }) async {
    final controller = CalculatorController(
      ratesRepository: repository,
      storage: storage,
      clock: clock ?? () => testNow,
      autoRefreshInterval: autoRefreshInterval,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    return controller;
  }

  group('initialization', () {
    test(
      'restores preferences, favorites, history, rates, and markets',
      () async {
        await seedPreferences(
          store,
          theme: AppThemePreference.light,
          language: AppLanguage.tr,
          outputCurrency: 'TRY',
        );
        await seedFavorites(
          store,
          UserFavorites(
            currencies: [
              CurrencyCatalog.fiatCurrency('JPY'),
              CurrencyCatalog.byCode('BTC')!,
            ],
          ),
        );
        await seedHistory(store, [makeHistoryEntry(id: 'stored-entry')]);
        await seedMarketCache(
          store,
          MarketSnapshot(
            quotes: [
              MarketQuote(
                currency: const Currency(
                  code: 'PEPE',
                  name: 'Pepe',
                  symbol: 'PEPE',
                  kind: CurrencyKind.crypto,
                  coinGeckoId: 'pepe',
                ),
                usdPrice: 0.00001,
                change24hPercent: 7.5,
                fetchedAt: testNow,
                providerUpdatedAt: testNow,
              ),
            ],
            fetchedAt: testNow,
            providerUpdatedAt: testNow,
            hasMore: false,
          ),
        );

        final controller = await createController();

        expect(controller.isInitialized, isTrue);
        expect(controller.theme, AppThemePreference.light);
        expect(controller.language, AppLanguage.tr);
        expect(controller.outputCurrency.code, 'TRY');
        expect(controller.favorites.currencies, hasLength(2));
        expect(controller.favoriteCurrencies.map((item) => item.code), [
          'JPY',
          'BTC',
        ]);
        expect(controller.history.single.id, 'stored-entry');
        expect(controller.hasRates, isTrue);
        expect(controller.isUsingCachedRates, isTrue);
        expect(controller.fiatStatus.isCached, isTrue);
        expect(controller.cryptoMarketStatus.isCached, isTrue);
        expect(controller.ratesFetchedAt, testNow);
        expect(controller.currencyByCode('PEPE')?.name, 'Pepe');
        expect(controller.quoteFor('pepe')?.usdPrice, 0.00001);
        expect(controller.unitsPerUsd['PEPE'], closeTo(100000, 0.0001));
        expect(controller.calculation.isValid, isTrue);
        expect(
          controller.calculation.total,
          closeTo(100 * testFiatUnitsPerUsd['TRY']!, 1e-9),
        );
      },
    );

    test('ignores corrupt optional state without fabricating rates', () async {
      store.values[AppStorage.preferencesKey] = 'not json';
      store.values[AppStorage.favoritesKey] = 'not json';
      store.values[AppStorage.historyKey] = 'not json';
      store.values[AppStorage.marketCacheKey] = 'not json';
      repository = FakeRatesRepository();

      final controller = await createController();

      expect(controller.theme, AppThemePreference.dark);
      expect(controller.language, AppLanguage.en);
      expect(controller.outputCurrency.code, 'EUR');
      expect(controller.favorites.isEmpty, isTrue);
      expect(controller.history, isEmpty);
      expect(controller.hasRates, isFalse);
      expect(controller.isUsingCachedRates, isFalse);
      expect(controller.quoteFor('BTC'), isNull);
      expect(controller.calculation.isValid, isFalse);
      expect(controller.ratesFetchedAt, isNull);
    });
  });

  group('row editing and output', () {
    test('calculates mixed rows independently through USD', () async {
      final controller = await createController();
      final tryCurrency = CurrencyCatalog.fiatCurrency('TRY');
      final btc = CurrencyCatalog.byCode('BTC')!;

      expect(controller.rows, hasLength(1));
      expect(controller.calculation.total, closeTo(90, 1e-9));

      final tryId = controller.addRow(currency: tryCurrency, amount: '30');
      final btcId = controller.addRow(currency: btc, amount: '0.001');

      expect(controller.rows, hasLength(3));
      expect(controller.calculation.isValid, isTrue);
      expect(controller.calculation.totalUsd, closeTo(151, 1e-9));
      expect(controller.calculation.total, closeTo(135.9, 1e-9));
      expect(controller.calculation.rows, hasLength(3));

      controller.updateRowAmount(tryId, '60');
      expect(controller.calculation.totalUsd, closeTo(152, 1e-9));

      controller.setRowCurrency(btcId, tryCurrency);
      controller.updateRowAmount(btcId, '0');
      expect(controller.rows.last.currency.code, 'TRY');
      expect(controller.calculation.totalUsd, closeTo(102, 1e-9));

      controller.removeRow(btcId);
      controller.removeRow(tryId);
      expect(controller.rows, hasLength(1));
      controller.removeRow(controller.rows.single.id);
      expect(controller.rows, hasLength(1));
    });

    test(
      'empty, invalid, and missing-rate rows invalidate the total',
      () async {
        final controller = await createController();
        controller.updateRowAmount(controller.rows.single.id, '');

        expect(controller.calculation.isEmpty, isTrue);
        expect(controller.canSaveCalculation, isFalse);

        controller.updateRowAmount(controller.rows.single.id, 'not a number');
        expect(controller.calculation.isValid, isFalse);
        expect(controller.canSaveCalculation, isFalse);

        controller.updateRowAmount(controller.rows.single.id, '10');
        controller.addRow(
          currency: CurrencyCatalog.fiatCurrency('ABC'),
          amount: '10',
        );
        expect(controller.calculation.isValid, isFalse);
        expect(controller.canSaveCalculation, isFalse);
      },
    );

    test('changing output persists and recalculates every row', () async {
      final controller = await createController();
      controller.addRow(
        currency: CurrencyCatalog.byCode('BTC')!,
        amount: '0.001',
      );

      controller.setOutputCurrency(CurrencyCatalog.fiatCurrency('TRY'));

      expect(controller.calculation.total, closeTo(4500, 1e-9));
      await pumpEventQueue();
      final saved = await storage.loadPreferences();
      expect(saved.outputCurrencyCode, 'TRY');

      controller.setOutputCurrency(CurrencyCatalog.fiatCurrency('EUR'));
      await pumpEventQueue();
      expect((await storage.loadPreferences()).outputCurrencyCode, 'EUR');
    });

    test('resetRows leaves one empty row and preserves the output', () async {
      final controller = await createController();
      controller.setOutputCurrency(CurrencyCatalog.fiatCurrency('TRY'));
      controller.addRow(amount: '4');

      controller.resetRows();

      expect(controller.rows, hasLength(1));
      expect(controller.rows.single.amount, isEmpty);
      expect(controller.rows.single.currency.code, 'USD');
      expect(controller.outputCurrency.code, 'TRY');
      expect(controller.calculation.isEmpty, isTrue);
    });
  });

  group('history', () {
    test(
      'saves a USD-derived result with relevant rates and metadata',
      () async {
        final controller = await createController();
        controller.addRow(
          currency: CurrencyCatalog.byCode('BTC')!,
          amount: '0.001',
        );
        controller.updateRowAmount(controller.rows.first.id, '100');
        controller.setOutputCurrency(CurrencyCatalog.fiatCurrency('EUR'));

        final saved = await controller.saveCurrentCalculationToHistory();

        expect(saved, isTrue);
        expect(controller.history, hasLength(1));
        final entry = controller.history.single;
        expect(entry.rows, hasLength(2));
        expect(entry.outputCurrency.code, 'EUR');
        expect(entry.resultUsd, closeTo(150, 1e-9));
        expect(entry.result, closeTo(135, 1e-9));
        expect(entry.unitsPerUsd['USD'], 1);
        expect(entry.unitsPerUsd['EUR'], 0.9);
        expect(entry.unitsPerUsd['BTC'], closeTo(1 / 50000, 1e-12));
        expect(entry.unitsPerUsd['TRY'], isNull);
        expect(entry.rateMeta.fetchedAt, testNow);
        expect(entry.rateMeta.fiatOrigin, RateOrigin.cached);
        expect(entry.rateMeta.cryptoOrigin, RateOrigin.cached);
        expect(entry.createdAt, testNow);
        expect((await storage.loadHistory()).single.id, entry.id);
      },
    );

    test('restores, deletes, and clears entries with persistence', () async {
      final controller = await createController();
      controller.addRow(
        currency: CurrencyCatalog.byCode('BTC')!,
        amount: '0.002',
      );
      await controller.saveCurrentCalculationToHistory();
      final entry = controller.history.single;
      final savedId = entry.id;

      controller.resetRows();
      controller.setOutputCurrency(CurrencyCatalog.fiatCurrency('USD'));
      controller.restoreHistory(entry);

      expect(controller.rows, hasLength(2));
      expect(controller.rows.last.amount, '0.002');
      expect(controller.outputCurrency.code, 'EUR');
      await pumpEventQueue();
      expect((await storage.loadPreferences()).outputCurrencyCode, 'EUR');

      await controller.removeHistoryEntry(savedId);
      expect(controller.history, isEmpty);
      expect(await storage.loadHistory(), isEmpty);

      await controller.saveCurrentCalculationToHistory();
      await controller.saveCurrentCalculationToHistory();
      expect(controller.history, hasLength(2));
      await controller.clearHistory();
      expect(controller.history, isEmpty);
      expect(await storage.loadHistory(), isEmpty);
    });

    test(
      'recalculates with current rates without changing stored values',
      () async {
        final controller = await createController();
        await controller.saveCurrentCalculationToHistory();
        final stored = controller.history.single;
        final storedResult = stored.result;
        final improved = makeRateBundle(
          fiat: {...testFiatUnitsPerUsd, 'EUR': 1.25},
        );
        repository.refreshResult = RateRefreshResult(
          bundle: improved,
          fiat: RateOriginInfo(origin: RateOrigin.live, updatedAt: testNow),
          crypto: RateOriginInfo(origin: RateOrigin.live, updatedAt: testNow),
        );

        await controller.refreshRates();
        final recalculated = controller.recalculateHistory(stored);

        expect(stored.result, storedResult);
        expect(recalculated.isValid, isTrue);
        expect(recalculated.total, closeTo(125, 1e-9));
        expect(recalculated.total, isNot(closeTo(storedResult, 1e-9)));
      },
    );

    test('does not save invalid or empty calculations', () async {
      final controller = await createController();
      controller.updateRowAmount(controller.rows.single.id, '');

      expect(await controller.saveCurrentCalculationToHistory(), isFalse);
      controller.updateRowAmount(controller.rows.single.id, 'bad');
      expect(controller.canSaveCalculation, isFalse);
      expect(await controller.saveCurrentCalculationToHistory(), isFalse);
      expect(controller.history, isEmpty);
    });

    test('keeps a maximum of one hundred newest entries', () async {
      final controller = await createController();
      for (var index = 0; index < 105; index++) {
        controller.updateRowAmount(controller.rows.single.id, '${index + 1}');
        expect(await controller.saveCurrentCalculationToHistory(), isTrue);
      }

      expect(controller.history, hasLength(100));
      expect(controller.history.first.resultUsd, 105);
      expect(controller.history.last.resultUsd, 6);
      expect((await storage.loadHistory()), hasLength(100));
    });
  });

  group('favorites and market synchronization', () {
    test('toggles real currency metadata and persists it', () async {
      final controller = await createController();
      final btc = CurrencyCatalog.byCode('BTC')!;

      expect(await controller.toggleCurrencyFavorite(btc), isTrue);
      expect(controller.isCurrencyFavorite('BTC'), isTrue);
      expect(controller.favoriteCurrencies.single.name, 'Bitcoin');
      await pumpEventQueue();
      expect((await storage.loadFavorites()).hasCurrency('BTC'), isTrue);

      expect(await controller.toggleCurrencyFavorite(btc), isFalse);
      expect(controller.isCurrencyFavorite('BTC'), isFalse);
      await pumpEventQueue();
      expect((await storage.loadFavorites()).hasCurrency('BTC'), isFalse);
    });

    test('adds dynamic market assets and their supplemental rate', () async {
      final controller = await createController();
      const pepe = Currency(
        code: 'PEPE',
        name: 'Pepe',
        symbol: 'PEPE',
        kind: CurrencyKind.crypto,
        coinGeckoId: 'pepe',
      );
      final snapshot = MarketSnapshot(
        quotes: [
          MarketQuote(
            currency: pepe,
            usdPrice: 0.00002,
            change24hPercent: 4,
            fetchedAt: testNow,
            providerUpdatedAt: testNow,
          ),
        ],
        fetchedAt: testNow,
        providerUpdatedAt: testNow,
        hasMore: false,
      );

      controller.syncMarketData(
        snapshot,
        status: RateOriginInfo(origin: RateOrigin.live, updatedAt: testNow),
      );

      expect(controller.quoteFor('pepe')?.usdPrice, 0.00002);
      expect(controller.currencyByCode('PEPE'), pepe);
      expect(controller.currencies.any((item) => item.code == 'PEPE'), isTrue);
      expect(controller.unitsPerUsd['PEPE'], closeTo(50000, 1e-6));
      expect(controller.marketStatus.isLive, isTrue);

      controller.setOutputCurrency(pepe);
      controller.addRow(currency: pepe, amount: '1000');
      expect(controller.calculation.isValid, isTrue);
      expect(controller.calculation.total, closeTo(100 / 0.00002 + 1000, 1e-6));

      controller.syncMarketData(
        null,
        status: const RateOriginInfo.unavailable(),
        error: 'Market offline',
      );

      expect(controller.quoteFor('PEPE'), isNull);
      expect(controller.unitsPerUsd.containsKey('PEPE'), isFalse);
      expect(controller.calculation.isValid, isFalse);
      expect(controller.marketError, 'Market offline');
      expect(controller.currencyByCode('PEPE'), pepe);
    });

    test('resolves favorite metadata from a later market snapshot', () async {
      const dynamic = Currency(
        code: 'WIF',
        name: 'dogwifhat',
        symbol: 'WIF',
        kind: CurrencyKind.crypto,
        coinGeckoId: 'dogwifhat',
      );
      await seedFavorites(store, UserFavorites(currencies: [dynamic]));
      final controller = await createController();
      final snapshot = MarketSnapshot(
        quotes: [
          MarketQuote(
            currency: const Currency(
              code: 'WIF',
              name: 'dogwifhat (renamed)',
              symbol: 'WIF',
              kind: CurrencyKind.crypto,
              coinGeckoId: 'dogwifhat',
            ),
            usdPrice: 2,
            fetchedAt: testNow,
          ),
        ],
        fetchedAt: testNow,
        hasMore: false,
      );

      controller.syncMarketData(
        snapshot,
        status: RateOriginInfo(origin: RateOrigin.live, updatedAt: testNow),
      );

      expect(controller.favoriteCurrencies.single.name, 'dogwifhat (renamed)');
    });
  });

  group('preferences and refresh behavior', () {
    test('persists theme and language changes', () async {
      final controller = await createController();

      controller.setTheme(AppThemePreference.light);
      controller.setLanguage(AppLanguage.tr);
      await pumpEventQueue();

      final saved = await storage.loadPreferences();
      expect(saved.theme, AppThemePreference.light);
      expect(saved.language, AppLanguage.tr);
    });

    test('refreshRatesIfStale respects the age threshold', () async {
      var clock = testNow;
      final controller = await createController(clock: () => clock);

      await controller.refreshRatesIfStale();
      expect(repository.refreshCalls, 0);

      clock = testNow.add(const Duration(minutes: 20));
      await controller.refreshRatesIfStale();
      expect(repository.refreshCalls, 1);
      expect(controller.fiatStatus.isLive, isTrue);
      expect(controller.cryptoStatus.isLive, isTrue);
    });

    test(
      'a failed rate refresh keeps cached values and reports the error',
      () async {
        final controller = await createController();
        repository.refreshError = Exception('Rate network down');

        await controller.refreshRates();

        expect(controller.hasRates, isTrue);
        expect(controller.isUsingCachedRates, isTrue);
        expect(controller.fiatStatus.isCached, isTrue);
        expect(controller.cryptoStatus.isCached, isTrue);
        expect(controller.rateRefreshError, isNotNull);
        expect(controller.isLoadingRates, isFalse);
      },
    );

    test(
      'refreshAllData calls both the rate and market refresh hooks',
      () async {
        final controller = await createController();
        var marketRefreshes = 0;
        controller.refreshMarketData = () async {
          marketRefreshes++;
        };

        await controller.refreshAllData();

        expect(repository.refreshCalls, 1);
        expect(marketRefreshes, 1);
      },
    );

    test(
      'surfaces storage failures without discarding in-memory state',
      () async {
        final controller = await createController();
        store.failWrites = true;

        final favorite = CurrencyCatalog.fiatCurrency('GBP');
        expect(await controller.toggleCurrencyFavorite(favorite), isTrue);
        expect(controller.isCurrencyFavorite('GBP'), isTrue);
        expect(controller.persistenceError, contains('Favorites'));

        store.failWrites = false;
        controller.updateRowAmount(controller.rows.single.id, '12');
        store.failWrites = true;
        expect(await controller.saveCurrentCalculationToHistory(), isFalse);
        expect(controller.persistenceError, contains('history'));
        expect(controller.history, hasLength(1));
      },
    );
  });
}
