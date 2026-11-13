import 'package:calc2/app.dart';
import 'package:calc2/models/app_preferences.dart';
import 'package:calc2/providers/calculator_controller.dart';
import 'package:calc2/providers/markets_controller.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_doubles.dart';

void main() {
  testWidgets('dump', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryKeyValueStore();
    await seedPreferences(store, theme: AppThemePreference.dark, language: AppLanguage.en, outputCurrency: 'EUR');
    final storage = AppStorage(store);
    final calculator = CalculatorController(ratesRepository: FakeRatesRepository(cached: makeRateBundle()), storage: storage, clock: () => testNow);
    final markets = MarketsController(service: FakeMarketDataService(snapshot: makeMarketSnapshot()), storage: storage, clock: () => testNow);
    addTearDown(() { calculator.dispose(); markets.dispose(); });
    await tester.pumpWidget(CurrencyCalculatorApp(controller: calculator, marketsController: markets));
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(find.byKey(const Key('nav-markets')));
    await tester.pumpAndSettle();
    tester.takeException();
    for (final element in find.byType(Row).evaluate()) {
      final flex = element.renderObject as RenderFlex?;
      if (flex == null || !flex.hasSize) continue;
      var childTotal = 0.0;
      RenderBox? child = flex.firstChild;
      while (child != null) {
        childTotal += child.size.width;
        final data = child.parentData as FlexParentData;
        child = data.nextSibling;
      }
      if (childTotal > flex.size.width + 0.5) {
        // ignore: avoid_print
        print('OVERFLOWROW box=${flex.size} childTotal=$childTotal creator=${element.debugGetCreatorChain(8)}');
        child = flex.firstChild;
        while (child != null) {
          final data = child.parentData as FlexParentData;
          // ignore: avoid_print
          print('  child w=${child.size.width} flex=${data.flex}');
          child = data.nextSibling;
        }
      }
    }
  });
}
