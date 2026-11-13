import 'dart:convert';

import 'package:calc2/models/calculation_history.dart';
import 'package:calc2/models/calculation_row.dart';
import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/rate_status.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_doubles.dart';

void main() {
  group('CalculationHistoryEntry serialization', () {
    test('round-trips inputs, rates, metadata, and negative results', () {
      final entry = makeHistoryEntry(
        id: 'history-negative',
        rows: [
          CalculationRow(
            id: 'row-a',
            amount: '-10,5',
            currency: CurrencyCatalog.fiatCurrency('EUR'),
          ),
          CalculationRow(
            id: 'row-b',
            amount: '2.25',
            currency: CurrencyCatalog.byCode('BTC')!,
          ),
        ],
        result: -120.75,
        resultUsd: -134.1666666667,
      );

      final decoded = jsonDecode(jsonEncode(entry.toJson()));
      final restored = CalculationHistoryEntry.fromJson(decoded);

      expect(restored, isNotNull);
      expect(restored!.id, 'history-negative');
      expect(restored.rows, hasLength(2));
      expect(restored.rows.first.amount, '-10,5');
      expect(restored.rows.first.currency.code, 'EUR');
      expect(restored.rows.last.currency.coinGeckoId, 'bitcoin');
      expect(restored.outputCurrency.code, 'EUR');
      expect(restored.result, -120.75);
      expect(restored.resultUsd, closeTo(-134.1666666667, 1e-9));
      expect(restored.unitsPerUsd['BTC'], closeTo(1 / 50000, 1e-12));
      expect(restored.rateMeta.fetchedAt, testNow);
      expect(restored.rateMeta.fiatOrigin, RateOrigin.live);
      expect(restored.rateMeta.cryptoOrigin, RateOrigin.live);
      expect(restored.createdAt, testNow);
      expect(restored.currencyCount, 2);
    });

    test('stored result remains independent of helper defaults', () {
      final entry = makeHistoryEntry(
        result: 123.45,
        resultUsd: 137.16,
        rateMeta: const HistoryRateMeta.none(),
      );

      expect(entry.result, 123.45);
      expect(entry.resultUsd, 137.16);
      expect(entry.rateMeta.hasSnapshot, isFalse);
      expect(entry.rateMeta.fiatOrigin, RateOrigin.unavailable);
    });

    test('rejects unsupported versions and irrecoverable entries', () {
      final json = Map<String, Object?>.from(
        jsonDecode(jsonEncode(makeHistoryEntry().toJson())) as Map,
      );

      expect(
        CalculationHistoryEntry.fromJson({...json, 'version': 99}),
        isNull,
      );
      expect(
        CalculationHistoryEntry.fromJson({...json, 'result': double.nan}),
        isNull,
      );
      expect(
        CalculationHistoryEntry.fromJson({...json, 'createdAt': 'bad'}),
        isNull,
      );
      expect(
        CalculationHistoryEntry.fromJson({...json, 'rows': <Object>[]}),
        isNull,
      );
      expect(
        CalculationHistoryEntry.fromJson({
          ...json,
          'rows': [
            {'amount': '1'},
          ],
        }),
        isNull,
      );
    });

    test('drops unusable rows and rates but keeps valid stored values', () {
      final json = Map<String, Object?>.from(
        jsonDecode(jsonEncode(makeHistoryEntry().toJson())) as Map,
      );
      final validRow = Map<String, Object?>.from(
        (json['rows'] as List).first as Map,
      );
      final secondRow = Map<String, Object?>.from(validRow)
        ..['id'] = ''
        ..['amount'] = '2';
      json['rows'] = [
        validRow,
        'not a row',
        {'amount': '1', 'currency': 'EUR'},
        secondRow,
      ];
      json['unitsPerUsd'] = {
        'USD': 1,
        'EUR': 0.9,
        'BAD_ZERO': 0,
        'BAD_TEXT': 'x',
        'BTC': 1 / 50000,
      };
      json['rateMeta'] = {
        'fetchedAt': '2026-10-25T12:00:00Z',
        'fiatOrigin': 'mystery',
        'cryptoOrigin': 'cached',
      };

      final restored = CalculationHistoryEntry.fromJson(json);

      expect(restored, isNotNull);
      expect(restored!.rows, hasLength(3));
      expect(restored.rows[1].currency.code, 'EUR');
      expect(restored.rows.last.id, 'restored-3');
      expect(restored.rows.last.amount, '2');
      expect(restored.unitsPerUsd.keys, ['USD', 'EUR', 'BTC']);
      expect(restored.rateMeta.fiatOrigin, RateOrigin.unavailable);
      expect(restored.rateMeta.cryptoOrigin, RateOrigin.cached);
    });
  });

  group('history persistence', () {
    test('loads valid unique entries and ignores malformed records', () async {
      final store = MemoryKeyValueStore();
      final storage = AppStorage(store);
      final first = makeHistoryEntry(id: 'first');
      final second = makeHistoryEntry(
        id: 'second',
        result: -3,
        resultUsd: -3.33,
      );
      await storage.saveHistory([first, second]);

      final raw = jsonDecode(store.values[AppStorage.historyKey]!) as Map;
      final entries = raw['entries'] as List;
      entries.add({...first.toJson()});
      entries.add('not an entry');
      entries.add({'version': 1});
      store.values[AppStorage.historyKey] = jsonEncode(raw);

      final loaded = await storage.loadHistory();

      expect(loaded, hasLength(2));
      expect(loaded.map((entry) => entry.id), ['first', 'second']);
      expect(loaded.last.result, -3);
    });

    test('corrupt history is ignored without discarding other data', () async {
      final store = MemoryKeyValueStore({AppStorage.historyKey: 'not json'});
      final storage = AppStorage(store);

      expect(await storage.loadHistory(), isEmpty);
    });

    test('persisted history uses the documented version and key', () async {
      final store = MemoryKeyValueStore();
      final storage = AppStorage(store);
      await storage.saveHistory([makeHistoryEntry()]);

      final raw = jsonDecode(
        store.values[AppStorage.historyKey]!,
      ) as Map<String, Object?>;
      expect(raw['version'], 1);
      expect(raw['entries'], isA<List>());
      expect(AppStorage.historyKey, 'calculation_history_v1');
    });
  });
}
