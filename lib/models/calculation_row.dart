import 'currency.dart';

/// One independently editable calculator row.
///
/// [amount] is kept as the exact text the user typed so invalid input can be
/// explained instead of being silently discarded.
class CalculationRow {
  const CalculationRow({
    required this.id,
    required this.amount,
    required this.currency,
  });

  final String id;
  final String amount;
  final Currency currency;

  bool get hasInput => amount.trim().isNotEmpty;

  CalculationRow copyWith({String? amount, Currency? currency}) {
    return CalculationRow(
      id: id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'currency': currency.toJson(),
  };

  static CalculationRow? fromJson(Object? value, {required String fallbackId}) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final currency = Currency.fromJson(json['currency']);
    final amount = json['amount'];
    if (currency == null || amount is! String) return null;
    final id = json['id'];
    return CalculationRow(
      id: id is String && id.trim().isNotEmpty ? id : fallbackId,
      amount: amount,
      currency: currency,
    );
  }
}
