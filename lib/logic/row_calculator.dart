import '../models/calculation_row.dart';
import '../models/currency.dart';

enum RowCalculationErrorKind {
  invalidAmount,
  amountTooLarge,
  missingRate,
  overflow,
}

class RowCalculationError {
  const RowCalculationError({
    required this.kind,
    this.currencyCode,
    this.rowId,
  });

  final RowCalculationErrorKind kind;
  final String? currencyCode;
  final String? rowId;
}

class RowBreakdown {
  const RowBreakdown({
    required this.row,
    this.amount,
    this.usdValue,
    this.outputValue,
    this.error,
  });

  final CalculationRow row;
  final double? amount;
  final double? usdValue;
  final double? outputValue;
  final RowCalculationError? error;

  bool get isValid => error == null && amount != null;
  bool get isSkipped => row.amount.trim().isEmpty;
}

class RowCalculationResult {
  const RowCalculationResult({
    required this.rows,
    required this.isEmpty,
    this.totalUsd,
    this.total,
    this.outputRate,
    this.error,
  });

  const RowCalculationResult.empty()
    : rows = const [],
      isEmpty = true,
      totalUsd = null,
      total = null,
      outputRate = null,
      error = null;

  final List<RowBreakdown> rows;
  final bool isEmpty;
  final double? totalUsd;
  final double? total;

  /// Units of the output currency per 1 USD.
  final double? outputRate;
  final RowCalculationError? error;

  bool get isValid => !isEmpty && error == null && !hasRowErrors;

  bool get hasRowErrors => rows.any((row) => row.error != null);

  RowCalculationError? errorForRow(String id) {
    for (final row in rows) {
      if (row.row.id == id) return row.error;
    }
    return null;
  }
}

/// Adds mixed-currency rows by converting each one to USD first.
///
/// No amount is ever added directly to an amount in another currency. Missing
/// rates and malformed values produce explicit errors instead of estimates.
class RowCalculator {
  const RowCalculator();

  static final RegExp _amountPattern = RegExp(
    r'^[+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)$',
  );

  static const double maxAmount = 1e15;

  RowCalculationResult calculate({
    required List<CalculationRow> rows,
    required Currency outputCurrency,
    required Map<String, double> unitsPerUsd,
  }) {
    final breakdowns = <RowBreakdown>[];
    var hasInput = false;
    var totalUsd = 0.0;

    for (final row in rows) {
      final text = row.amount.trim();
      if (text.isEmpty) {
        breakdowns.add(RowBreakdown(row: row));
        continue;
      }
      hasInput = true;

      final amount = _parseAmount(text);
      if (amount == null) {
        breakdowns.add(
          RowBreakdown(
            row: row,
            error: RowCalculationError(
              kind: RowCalculationErrorKind.invalidAmount,
              rowId: row.id,
              currencyCode: row.currency.code,
            ),
          ),
        );
        continue;
      }
      if (amount.abs() > maxAmount) {
        breakdowns.add(
          RowBreakdown(
            row: row,
            error: RowCalculationError(
              kind: RowCalculationErrorKind.amountTooLarge,
              rowId: row.id,
              currencyCode: row.currency.code,
            ),
          ),
        );
        continue;
      }

      final rate = _rateFor(row.currency.code, unitsPerUsd);
      if (rate == null) {
        breakdowns.add(
          RowBreakdown(
            row: row,
            error: RowCalculationError(
              kind: RowCalculationErrorKind.missingRate,
              rowId: row.id,
              currencyCode: row.currency.code,
            ),
          ),
        );
        continue;
      }

      final usd = amount / rate;
      if (!usd.isFinite) {
        breakdowns.add(
          RowBreakdown(
            row: row,
            error: RowCalculationError(
              kind: RowCalculationErrorKind.overflow,
              rowId: row.id,
              currencyCode: row.currency.code,
            ),
          ),
        );
        continue;
      }

      totalUsd += usd;
      if (!totalUsd.isFinite) {
        return RowCalculationResult(
          rows: List.unmodifiable(breakdowns),
          isEmpty: false,
          error: const RowCalculationError(
            kind: RowCalculationErrorKind.overflow,
          ),
        );
      }
      breakdowns.add(RowBreakdown(row: row, amount: amount, usdValue: usd));
    }

    if (!hasInput) {
      return RowCalculationResult(
        rows: List.unmodifiable(breakdowns),
        isEmpty: true,
      );
    }

    final outputRate = _rateFor(outputCurrency.code, unitsPerUsd);
    if (outputRate == null) {
      return RowCalculationResult(
        rows: List.unmodifiable(breakdowns),
        isEmpty: false,
        error: RowCalculationError(
          kind: RowCalculationErrorKind.missingRate,
          currencyCode: outputCurrency.code,
        ),
      );
    }

    final total = totalUsd * outputRate;
    if (!total.isFinite) {
      return RowCalculationResult(
        rows: List.unmodifiable(breakdowns),
        isEmpty: false,
        error: const RowCalculationError(
          kind: RowCalculationErrorKind.overflow,
        ),
      );
    }

    final withOutput = <RowBreakdown>[
      for (final row in breakdowns)
        if (row.usdValue == null)
          row
        else
          RowBreakdown(
            row: row.row,
            amount: row.amount,
            usdValue: row.usdValue,
            outputValue: row.usdValue! * outputRate,
          ),
    ];

    return RowCalculationResult(
      rows: List.unmodifiable(withOutput),
      isEmpty: false,
      totalUsd: totalUsd,
      total: total,
      outputRate: outputRate,
    );
  }

  double? _rateFor(String code, Map<String, double> unitsPerUsd) {
    if (code.toUpperCase() == 'USD') return 1;
    final rate = unitsPerUsd[code.toUpperCase()];
    if (rate == null || !rate.isFinite || rate <= 0) return null;
    return rate;
  }

  double? _parseAmount(String text) {
    if (!_amountPattern.hasMatch(text)) return null;
    final normalized = text.replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite) return null;
    return value;
  }

  /// Conversion value for labels, or null when either rate is missing.
  double? unitRate({
    required String fromCurrency,
    required String toCurrency,
    required Map<String, double> unitsPerUsd,
  }) {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) return 1;
    final from = _rateFor(fromCurrency, unitsPerUsd);
    final to = _rateFor(toCurrency, unitsPerUsd);
    if (from == null || to == null) return null;
    final value = to / from;
    if (!value.isFinite || value <= 0) return null;
    return value;
  }

  /// Converts an amount through the USD reference, or null on missing rates.
  double? convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    required Map<String, double> unitsPerUsd,
  }) {
    if (!amount.isFinite) return null;
    final from = _rateFor(fromCurrency, unitsPerUsd);
    final to = _rateFor(toCurrency, unitsPerUsd);
    if (from == null || to == null) return null;
    final value = amount / from * to;
    if (!value.isFinite) return null;
    return value;
  }
}
