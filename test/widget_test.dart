import 'package:calc2/app.dart';
import 'package:calc2/models/app_preferences.dart';
import 'package:calc2/models/calculation_history.dart';
import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/market_data.dart';
import 'package:calc2/models/user_favorites.dart';
import 'package:calc2/providers/calculator_controller.dart';
import 'package:calc2/providers/markets_controller.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:calc2/widgets/price_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_doubles.dart';

class _Harness {
  const _Harness({
    required this.calculator,
    required this.markets,
    required this.storage,
    required this.store,
    required this.marketService,
  });

  final CalculatorController calculator;
  final MarketsController markets;
  final AppStorage storage;
  final MemoryKeyValueStore store;
  final FakeMarketDataService marketService;
}

Future<_Harness> _pumpBirimm(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
  AppThemePreference theme = AppThemePreference.dark,
  AppLanguage language = AppLanguage.en,
  String outputCurrency = 'EUR',
  List<CalculationHistoryEntry>? history,
  UserFavorites? favorites,
  MarketSnapshot? marketSnapshot,
  Map<int, MarketSnapshot>? marketPages,
  bool cacheMarketSnapshot = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = MemoryKeyValueStore();
  await seedPreferences(
    store,
    theme: theme,
    language: language,
    outputCurrency: outputCurrency,
  );
  if (history != null) {
    await seedHistory(store, history);
  }
  if (favorites != null) {
    await seedFavorites(store, favorites);
  }
  final snapshot = marketSnapshot ?? makeMarketSnapshot();
  if (cacheMarketSnapshot) {
    await seedMarketCache(store, snapshot);
  }

  final storage = AppStorage(store);
  final marketService = FakeMarketDataService(
    snapshot: snapshot,
    pages: marketPages ?? const {},
  );
  final calculator = CalculatorController(
    ratesRepository: FakeRatesRepository(cached: makeRateBundle()),
    storage: storage,
    clock: () => testNow,
  );
  final markets = MarketsController(
    service: marketService,
    storage: storage,
    clock: () => testNow,
  );
  addTearDown(() {
    calculator.dispose();
    markets.dispose();
  });

  await tester.pumpWidget(
    CurrencyCalculatorApp(controller: calculator, marketsController: markets),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  return _Harness(
    calculator: calculator,
    markets: markets,
    storage: storage,
    store: store,
    marketService: marketService,
  );
}

Future<void> _goTo(WidgetTester tester, String destination) async {
  await tester.tap(find.byKey(Key('nav-$destination')));
  await tester.pumpAndSettle();
}

Future<void> _selectCurrency(
  WidgetTester tester,
  String code, {
  String query = '',
}) async {
  if (query.isNotEmpty) {
    await tester.enterText(
      find.byKey(const Key('currency-search-field')),
      query,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('currency-option-$code')));
  await tester.pumpAndSettle();
}

ScrollableState _scrollableFor(WidgetTester tester, String pageKey) {
  return tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byKey(Key(pageKey)),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

Future<void> _sendWheel(
  WidgetTester tester,
  String pageKey, {
  double delta = 240,
}) async {
  final position = tester.getCenter(find.byKey(Key(pageKey)));
  await tester.sendEventToBinding(
    PointerScrollEvent(position: position, scrollDelta: Offset(0, delta)),
  );
  await tester.pumpAndSettle();
}

Future<void> _sendMiddleDrag(WidgetTester tester, String pageKey) async {
  final position = tester.getCenter(find.byKey(Key(pageKey)));
  final gesture = await tester.startGesture(
    position,
    pointer: 91,
    kind: PointerDeviceKind.mouse,
    buttons: kMiddleMouseButton,
  );
  await tester.pump();
  await gesture.moveBy(const Offset(0, -120));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('shell and navigation', () {
    testWidgets('exposes five destinations on desktop and mobile', (
      tester,
    ) async {
      final desktop = await _pumpBirimm(tester);

      expect(find.byKey(const Key('desktop-rail')), findsOneWidget);
      expect(find.byKey(const Key('mobile-navigation')), findsNothing);
      expect(find.byKey(const Key('calculator-page')), findsOneWidget);
      for (final destination in [
        'calculator',
        'markets',
        'favorites',
        'history',
        'settings',
      ]) {
        expect(find.byKey(Key('nav-$destination')), findsOneWidget);
      }

      await _goTo(tester, 'markets');
      expect(find.byKey(const Key('markets-page')), findsOneWidget);
      expect(find.byKey(const Key('market-asset-BTC')), findsOneWidget);

      await _goTo(tester, 'favorites');
      expect(find.byKey(const Key('favorites-page')), findsOneWidget);
      expect(find.text('No favorites yet.'), findsOneWidget);
      expect(desktop.calculator.favoriteCurrencies, isEmpty);

      await _goTo(tester, 'history');
      expect(find.byKey(const Key('history-page')), findsOneWidget);
      expect(find.text('No saved calculations yet.'), findsOneWidget);

      await _goTo(tester, 'settings');
      expect(find.byKey(const Key('settings-page')), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final mobile = await _pumpBirimm(tester, size: const Size(360, 760));

      expect(find.byKey(const Key('desktop-rail')), findsNothing);
      expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
      for (final destination in [
        'markets',
        'favorites',
        'history',
        'settings',
        'calculator',
      ]) {
        await _goTo(tester, destination);
        expect(
          find.byKey(
            Key(
              '${destination == 'calculator' ? 'calculator' : destination}-page',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      expect(mobile.calculator.calculation.isValid, isTrue);
    });

    testWidgets('keeps narrow and short phone layouts overflow-free', (
      tester,
    ) async {
      await _pumpBirimm(tester, size: const Size(320, 640));

      expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final destination in [
        'markets',
        'favorites',
        'history',
        'settings',
        'calculator',
      ]) {
        await _goTo(tester, destination);
        expect(
          find.byKey(
            Key(
              '${destination == 'calculator' ? 'calculator' : destination}-page',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await _pumpBirimm(tester, size: const Size(844, 390));
      expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final destination in [
        'markets',
        'favorites',
        'history',
        'settings',
        'calculator',
      ]) {
        await _goTo(tester, destination);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow on $destination at 844x390',
        );
      }
    });

    testWidgets('keeps the wide desktop market toolbar overflow-free', (
      tester,
    ) async {
      await _pumpBirimm(tester, size: const Size(1600, 1000));
      await _goTo(tester, 'markets');

      expect(find.byKey(const Key('markets-page')), findsOneWidget);
      expect(find.byKey(const Key('market-search-field')), findsOneWidget);
      expect(find.byKey(const Key('market-filter-all')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('calculator', () {
    testWidgets('edits mixed rows, validates input, and saves history', (
      tester,
    ) async {
      final harness = await _pumpBirimm(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('result-value'))).data,
        '90.00',
      );

      await tester.tap(find.byKey(const Key('add-row-button')));
      await tester.pumpAndSettle();

      final newRow = harness.calculator.rows.last;
      final amountField = find
          .descendant(
            of: find.byKey(Key('row-amount-${newRow.id}')),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(amountField, '30');
      await tester.pumpAndSettle();
      expect(harness.calculator.calculation.isValid, isTrue);

      await tester.tap(find.byKey(Key('row-currency-${newRow.id}')));
      await tester.pumpAndSettle();
      await _selectCurrency(tester, 'TRY', query: 'TRY');
      expect(harness.calculator.rows.last.currency.code, 'TRY');
      expect(harness.calculator.calculation.totalUsd, closeTo(101, 1e-9));
      expect(
        tester.widget<Text>(find.byKey(const Key('result-value'))).data,
        '90.90',
      );

      await tester.enterText(amountField, 'not a number');
      await tester.pumpAndSettle();
      expect(harness.calculator.calculation.isValid, isFalse);
      expect(
        tester.widget<Text>(find.byKey(const Key('result-value'))).data,
        '—',
      );
      expect(find.text('Enter a valid number.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save to history'),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(amountField, '30');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-history-button')));
      await tester.pumpAndSettle();

      expect(harness.calculator.history, hasLength(1));
      expect(find.text('Calculation saved to history.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final entry = harness.calculator.history.single;
      await _goTo(tester, 'history');
      await tester.tap(find.byKey(Key('history-entry-${entry.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Calculation details'), findsOneWidget);
      expect(find.text('STORED RESULT'), findsOneWidget);
      expect(find.text('CURRENT RESULT'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-restore-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calculator-page')), findsOneWidget);
      expect(harness.calculator.rows, hasLength(2));
      expect(harness.calculator.rows.last.amount, '30');
      expect(harness.calculator.rows.last.currency.code, 'TRY');
      expect(find.text('Calculation restored.'), findsOneWidget);
    });

    testWidgets('output picker changes the total and survives a reload', (
      tester,
    ) async {
      final harness = await _pumpBirimm(tester);

      await tester.tap(find.byKey(const Key('output-currency-button')));
      await tester.pumpAndSettle();
      await _selectCurrency(tester, 'TRY', query: 'TRY');

      expect(harness.calculator.outputCurrency.code, 'TRY');
      expect(harness.calculator.calculation.total, closeTo(3000, 1e-9));
      expect(
        tester.widget<Text>(find.byKey(const Key('result-value'))).data,
        '3,000.00',
      );

      await tester.pump();
      final saved = await harness.storage.loadPreferences();
      expect(saved.outputCurrencyCode, 'TRY');
    });

    testWidgets('clearing rows asks first and preserves history', (
      tester,
    ) async {
      final harness = await _pumpBirimm(
        tester,
        history: [makeHistoryEntry(id: 'kept-entry')],
      );

      await tester.tap(find.byKey(const Key('clear-rows-button')));
      await tester.pumpAndSettle();
      expect(find.text('Clear all rows?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-clear-rows')));
      await tester.pumpAndSettle();

      expect(harness.calculator.rows, hasLength(1));
      expect(harness.calculator.rows.single.amount, isEmpty);
      expect(harness.calculator.history, hasLength(1));
      expect(find.byKey(const Key('result-value')), findsOneWidget);
      expect(find.text('Enter an amount to begin.'), findsOneWidget);
    });
  });

  group('markets and favorites', () {
    testWidgets('searches, filters, opens a real chart, and adds an asset', (
      tester,
    ) async {
      final harness = await _pumpBirimm(tester);

      await _goTo(tester, 'markets');
      expect(find.byKey(const Key('market-asset-BTC')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('market-search-field')),
        'sol',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('market-asset-SOL')), findsOneWidget);
      expect(find.byKey(const Key('market-asset-BTC')), findsNothing);

      await tester.enterText(find.byKey(const Key('market-search-field')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-filter-gainers')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('market-asset-BTC')), findsOneWidget);
      expect(find.byKey(const Key('market-asset-SOL')), findsOneWidget);
      expect(find.byKey(const Key('market-asset-ETH')), findsNothing);

      await tester.tap(find.byKey(const Key('market-filter-losers')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('market-asset-ETH')), findsOneWidget);
      expect(find.byKey(const Key('market-asset-BTC')), findsNothing);

      await tester.tap(find.byKey(const Key('market-filter-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-asset-BTC')));
      await tester.pumpAndSettle();

      expect(find.byType(PriceChart), findsOneWidget);
      expect(harness.marketService.historyCalls, 1);
      expect(find.text('Bitcoin price chart'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chart-range-7d')));
      await tester.pumpAndSettle();
      expect(
        harness.marketService.requestedRanges.last,
        PriceHistoryRange.week,
      );
      expect(harness.marketService.historyCalls, 2);

      final addButton = find.byKey(const Key('add-to-calculator-BTC'));
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calculator-page')), findsOneWidget);
      expect(harness.calculator.rows, hasLength(2));
      expect(harness.calculator.rows.last.currency.code, 'BTC');
      expect(find.text('BTC was added as a calculator row.'), findsOneWidget);
    });

    testWidgets('stars an asset and manages it from Favorites', (tester) async {
      final harness = await _pumpBirimm(tester);

      await _goTo(tester, 'markets');
      await tester.tap(find.byKey(const Key('favorite-market-BTC')));
      await tester.pumpAndSettle();
      expect(harness.calculator.isCurrencyFavorite('BTC'), isTrue);

      await _goTo(tester, 'favorites');
      expect(find.byKey(const Key('favorite-row-BTC')), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('1 favorite'), findsOneWidget);

      await tester.tap(find.byKey(const Key('favorite-add-BTC')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calculator-page')), findsOneWidget);
      expect(harness.calculator.rows.last.currency.code, 'BTC');
      expect(harness.calculator.rows.last.amount, '1');

      await _goTo(tester, 'favorites');
      await tester.tap(find.byKey(const Key('remove-favorite-BTC')));
      await tester.pumpAndSettle();
      expect(harness.calculator.isCurrencyFavorite('BTC'), isFalse);
      expect(find.text('No favorites yet.'), findsOneWidget);
    });

    testWidgets('loads another cached market page without dropping quotes', (
      tester,
    ) async {
      final snapshot = makeMarketSnapshot(hasMore: true, nextPage: 2);
      final harness = await _pumpBirimm(
        tester,
        marketSnapshot: snapshot,
        marketPages: {2: makeMarketPage(page: 2, count: 1, hasMore: false)},
        cacheMarketSnapshot: true,
      );

      await _goTo(tester, 'markets');
      expect(harness.markets.loadedQuoteCount, 6);

      final loadMore = find.byKey(const Key('market-load-more'));
      await tester.ensureVisible(loadMore);
      await tester.pumpAndSettle();
      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      expect(harness.marketService.requestedPages, contains(2));
      expect(harness.markets.loadedQuoteCount, 7);
      expect(harness.markets.quoteFor('P02000'), isNotNull);
      expect(find.byKey(const Key('market-asset-P02000')), findsOneWidget);
    });
  });

  group('history', () {
    testWidgets('deletes one entry and clears the rest with confirmation', (
      tester,
    ) async {
      final harness = await _pumpBirimm(
        tester,
        history: [
          makeHistoryEntry(id: 'entry-a'),
          makeHistoryEntry(id: 'entry-b'),
        ],
      );

      await _goTo(tester, 'history');
      expect(find.byKey(const Key('history-entry-entry-a')), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-entry-entry-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-delete-button')));
      await tester.pumpAndSettle();

      expect(harness.calculator.history.map((entry) => entry.id), ['entry-b']);
      expect(find.byKey(const Key('history-entry-entry-a')), findsNothing);
      expect(find.text('Entry deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history-clear-button')));
      await tester.pumpAndSettle();
      expect(find.text('Clear all history?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-clear-history')));
      await tester.pumpAndSettle();

      expect(harness.calculator.history, isEmpty);
      expect(find.text('No saved calculations yet.'), findsOneWidget);
      expect(find.text('History cleared.'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('switches to Turkish and light theme and persists both', (
      tester,
    ) async {
      final harness = await _pumpBirimm(tester);

      await _goTo(tester, 'settings');
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);

      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();

      expect(harness.calculator.language, AppLanguage.tr);
      expect(find.text('Ayarlar'), findsWidgets);
      expect(find.text('Hesap'), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);

      await tester.tap(find.text('Açık'));
      await tester.pumpAndSettle();

      expect(harness.calculator.theme, AppThemePreference.light);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      expect(
        Theme.of(tester.element(find.byKey(const Key('settings-page'))))
            .brightness,
        Brightness.light,
      );

      await tester.pump();
      final saved = await harness.storage.loadPreferences();
      expect(saved.language, AppLanguage.tr);
      expect(saved.theme, AppThemePreference.light);
    });
  });

  group('Windows scrolling regression', () {
    testWidgets('wheel and middle-button gestures are safe on every page', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final favorites = UserFavorites(
          currencies: CurrencyCatalog.cryptoCurrencies.take(20).toList(),
        );
        final history = [
          for (var index = 0; index < 24; index++)
            makeHistoryEntry(
              id: 'scroll-entry-$index',
              createdAt: testNow.subtract(Duration(days: index)),
            ),
        ];
        final marketSnapshot = makeMarketPage(
          page: 1,
          count: 30,
          hasMore: false,
        );
        final harness = await _pumpBirimm(
          tester,
          size: const Size(1280, 820),
          favorites: favorites,
          history: history,
          marketSnapshot: marketSnapshot,
          cacheMarketSnapshot: true,
        );

        for (var index = 0; index < 24; index++) {
          harness.calculator.addRow(
            currency: CurrencyCatalog.fiatCurrency('EUR'),
            amount: '${index + 1}',
          );
        }
        await tester.pumpAndSettle();

        final pages = <String, String>{
          'calculator': 'calculator-page',
          'markets': 'markets-page',
          'favorites': 'favorites-page',
          'history': 'history-page',
          'settings': 'settings-page',
        };
        final controllers = <int>{};

        for (final entry in pages.entries) {
          await _goTo(tester, entry.key);
          expect(find.byKey(Key(entry.value)), findsOneWidget);

          final view = tester.widget<SingleChildScrollView>(
            find.byKey(Key(entry.value)),
          );
          expect(view.controller, isNotNull);
          expect(view.primary, isNot(true));
          controllers.add(view.controller!.hashCode);

          final scrollable = _scrollableFor(tester, entry.value);
          final before = scrollable.position.pixels;
          await _sendWheel(tester, entry.value);
          final after = scrollable.position.pixels;
          expect(
            after,
            greaterThan(before),
            reason: 'The mouse wheel should scroll ${entry.key}.',
          );
          expect(tester.takeException(), isNull);

          await _sendMiddleDrag(tester, entry.value);
          expect(tester.takeException(), isNull);
        }

        expect(controllers, hasLength(pages.length));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
