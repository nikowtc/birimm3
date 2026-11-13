import 'package:calc2/logic/row_calculator.dart';
import 'package:calc2/models/calculation_row.dart';
import 'package:calc2/models/currency.dart';
import 'package:calc2/models/currency_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = RowCalculator();
  final usd = CurrencyCatalog.fiatCurrency('USD');
  final eur = CurrencyCatalog.fiatCurrency('EUR');
  final tryCurrency = CurrencyCatalog.fiatCurrency('TRY');
  final btc = CurrencyCatalog.byCode('BTC')!;
  final rates = <String, double>{
    'USD': 1,
    'EUR': 0.9,
    'TRY': 30,
    'BTC': 1 / 50000,
  };

  CalculationRow row(String id, String amount, Currency currency) {
    return CalculationRow(id: id, amount: amount, currency: currency);
  }

  group('mixed-currency addition', () {
    test('converts every row through USD before adding', () {
      final result = calculator.calculate(
        rows: [
          row('1', '100', usd),
          row('2', '90', eur),
          row('3', '3000', tryCurrency),
          row('4', '0.001', btc),
        ],
        outputCurrency: eur,
        unitsPerUsd: rates,
      );

      expect(result.isValid, isTrue);
      expect(result.totalUsd, closeTo(350, 1e-9));
      expect(result.total, closeTo(315, 1e-9));
      expect(result.outputRate, 0.9);
      expect(result.rows.map((item) => item.usdValue), [
        closeTo(100, 1e-9),
        closeTo(100, 1e-9),
        closeTo(100, 1e-9),
        closeTo(50, 1e-9),
      ]);
      expect(result.rows.last.outputValue, closeTo(45, 1e-9));
    });

    test('supports comma decimals, signs, and negative totals', () {
      final result = calculator.calculate(
        rows: [
          row('1', '1,5', usd),
          row('2', '+2.25', eur),
          row('3', '-10,75', usd),
        ],
        outputCurrency: usd,
        unitsPerUsd: rates,
      );

      expect(result.isValid, isTrue);
      expect(result.totalUsd, closeTo(-6.75, 1e-9));
      expect(result.total, closeTo(-6.75, 1e-9));
      expect(result.rows.first.amount, 1.5);
      expect(result.rows[1].amount, 2.25);
      expect(result.rows[2].amount, -10.75);
    });

    test('uses USD only as the shared reference, never sums raw amounts', () {
      final result = calculator.calculate(
        rows: [row('1', '1', usd), row('2', '1', tryCurrency)],
        outputCurrency: tryCurrency,
        unitsPerUsd: rates,
      );

      expect(result.isValid, isTrue);
      expect(result.totalUsd, closeTo(1 + 1 / 30, 1e-9));
      expect(result.total, closeTo(31, 1e-9));
      expect(result.total, isNot(closeTo(2, 1e-9)));
    });
  });

  group('empty, zero, and invalid input', () {
    test('returns an empty result when nothing is entered', () {
      final result = calculator.calculate(
        rows: [row('1', '', usd), row('2', '   ', eur)],
        outputCurrency: eur,
        unitsPerUsd: rates,
      );

      expect(result.isEmpty, isTrue);
      expect(result.isValid, isFalse);
      expect(result.total, isNull);
      expect(result.rows.map((item) => item.isSkipped), [true, true]);
    });

    test('zero is a valid, saveable calculation', () {
      final result = calculator.calculate(
        rows: [row('1', '0', usd)],
        outputCurrency: eur,
        unitsPerUsd: rates,
      );

      expect(result.isEmpty, isFalse);
      expect(result.isValid, isTrue);
      expect(result.total, 0);
      expect(result.totalUsd, 0);
    });

    test('flags malformed numbers with the offending row', () {
      for (final value in [
        'NaN',
        'Infinity',
        '1e5',
        '1,2,3',
        '1 000',
        '-',
        '.',
        '--4',
        '12abc',
      ]) {
        final result = calculator.calculate(
          rows: [row('valid', '10', usd), row('bad', value, eur)],
          outputCurrency: usd,
          unitsPerUsd: rates,
        );

        expect(result.isValid, isFalse, reason: value);
        expect(result.hasRowErrors, isTrue, reason: value);
        expect(
          result.errorForRow('bad')?.kind,
          RowCalculationErrorKind.invalidAmount,
          reason: value,
        );
        expect(result.errorForRow('valid'), isNull, reason: value);
      }
    });

    test('rejects amounts above the documented limit', () {
      final accepted = calculator.calculate(
        rows: [row('ok', '1000000000000000', usd)],
        outputCurrency: usd,
        unitsPerUsd: rates,
      );
      final rejected = calculator.calculate(
        rows: [row('big', '1000000000000001', usd)],
        outputCurrency: usd,
        unitsPerUsd: rates,
      );

      expect(accepted.isValid, isTrue);
      expect(rejected.isValid, isFalse);
      expect(
        rejected.errorForRow('big')?.kind,
        RowCalculationErrorKind.amountTooLarge,
      );
    });
  });

  group('missing rates and overflow', () {
    test('marks a row without a rate instead of estimating', () {
      final result = calculator.calculate(
        rows: [
          row('usd', '10', usd),
          row('unknown', '10', CurrencyCatalog.fiatCurrency('ABC')),
        ],
        outputCurrency: usd,
        unitsPerUsd: rates,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errorForRow('unknown')?.kind,
        RowCalculationErrorKind.missingRate,
      );
      expect(result.errorForRow('unknown')?.currencyCode, 'ABC');
    });

    test('marks a missing output rate even when all rows are valid', () {
      final result = calculator.calculate(
        rows: [row('usd', '10', usd)],
        outputCurrency: CurrencyCatalog.fiatCurrency('ABC'),
        unitsPerUsd: rates,
      );

      expect(result.isValid, isFalse);
      expect(result.error?.kind, RowCalculationErrorKind.missingRate);
      expect(result.error?.currencyCode, 'ABC');
      expect(result.rows.single.isValid, isTrue);
    });

    test('detects USD conversion overflow', () {
      final result = calculator.calculate(
        rows: [row('huge', '1000000000000000', eur)],
        outputCurrency: usd,
        unitsPerUsd: {'USD': 1, 'EUR': 1e-307},
      );

      expect(result.isValid, isFalse);
      expect(
        result.errorForRow('huge')?.kind,
        RowCalculationErrorKind.overflow,
      );
    });

    test('detects total overflow across otherwise finite rows', () {
      final result = calculator.calculate(
        rows: [
          row('1', '1000000000000000', usd),
          row('2', '1000000000000000', usd),
        ],
        outputCurrency: eur,
        unitsPerUsd: {'USD': 1, 'EUR': 1e308},
      );

      expect(result.isValid, isFalse);
      expect(result.error?.kind, RowCalculationErrorKind.overflow);
    });

    test('ignores non-positive and non-finite rates', () {
      for (final rate in [0.0, -1.0, double.infinity, double.nan]) {
        final result = calculator.calculate(
          rows: [row('1', '10', eur)],
          outputCurrency: usd,
          unitsPerUsd: {'USD': 1, 'EUR': rate},
        );

        expect(result.isValid, isFalse, reason: '$rate');
        expect(
          result.errorForRow('1')?.kind,
          RowCalculationErrorKind.missingRate,
          reason: '$rate',
        );
      }
    });
  });

  group('conversion helpers', () {
    test('unitRate follows the USD reference', () {
      expect(
        calculator.unitRate(
          fromCurrency: 'EUR',
          toCurrency: 'TRY',
          unitsPerUsd: rates,
        ),
        closeTo(30 / 0.9, 1e-9),
      );
      expect(
        calculator.unitRate(
          fromCurrency: 'USD',
          toCurrency: 'USD',
          unitsPerUsd: rates,
        ),
        1,
      );
      expect(
        calculator.unitRate(
          fromCurrency: 'EUR',
          toCurrency: 'ABC',
          unitsPerUsd: rates,
        ),
        isNull,
      );
    });

    test(
      'convert handles valid and missing rates without inventing values',
      () {
        expect(
          calculator.convert(
            amount: 90,
            fromCurrency: 'EUR',
            toCurrency: 'TRY',
            unitsPerUsd: rates,
          ),
          closeTo(3000, 1e-9),
        );
        expect(
          calculator.convert(
            amount: 1,
            fromCurrency: 'EUR',
            toCurrency: 'ABC',
            unitsPerUsd: rates,
          ),
          isNull,
        );
        expect(
          calculator.convert(
            amount: double.infinity,
            fromCurrency: 'EUR',
            toCurrency: 'USD',
            unitsPerUsd: rates,
          ),
          isNull,
        );
      },
    );
  });
}
