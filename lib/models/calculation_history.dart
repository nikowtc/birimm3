import 'calculation_row.dart';
import 'currency.dart';
import 'rate_status.dart';

/// The provider state captured when a calculation was saved.
class HistoryRateMeta {
  const HistoryRateMeta({
    required this.fetchedAt,
    required this.fiatOrigin,
    required this.cryptoOrigin,
    this.fiatUpdatedAt,
    this.cryptoUpdatedAt,
  });

  const HistoryRateMeta.none()
    : fetchedAt = null,
      fiatOrigin = RateOrigin.unavailable,
      cryptoOrigin = RateOrigin.unavailable,
      fiatUpdatedAt = null,
      cryptoUpdatedAt = null;

  final DateTime? fetchedAt;
  final RateOrigin fiatOrigin;
  final RateOrigin cryptoOrigin;
  final DateTime? fiatUpdatedAt;
  final DateTime? cryptoUpdatedAt;

  bool get hasSnapshot => fetchedAt != null;
  bool get isAnyCached =>
      fiatOrigin == RateOrigin.cached || cryptoOrigin == RateOrigin.cached;

  Map<String, Object?> toJson() => {
    'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
    'fiatOrigin': fiatOrigin.name,
    'cryptoOrigin': cryptoOrigin.name,
    'fiatUpdatedAt': fiatUpdatedAt?.toUtc().toIso8601String(),
    'cryptoUpdatedAt': cryptoUpdatedAt?.toUtc().toIso8601String(),
  };

  static HistoryRateMeta fromJson(Object? value) {
    if (value is! Map) return const HistoryRateMeta.none();
    final json = Map<String, Object?>.from(value);
    return HistoryRateMeta(
      fetchedAt: _date(json['fetchedAt']),
      fiatOrigin: _origin(json['fiatOrigin']),
      cryptoOrigin: _origin(json['cryptoOrigin']),
      fiatUpdatedAt: _date(json['fiatUpdatedAt']),
      cryptoUpdatedAt: _date(json['cryptoUpdatedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static RateOrigin _origin(Object? value) {
    if (value is! String) return RateOrigin.unavailable;
    return RateOrigin.values.firstWhere(
      (origin) => origin.name == value,
      orElse: () => RateOrigin.unavailable,
    );
  }
}

/// A complete, immutable calculation record.
///
/// The stored result is never recomputed when browsing. The detail view can
/// additionally compare it with a fresh calculation using the current rates.
class CalculationHistoryEntry {
  const CalculationHistoryEntry({
    required this.id,
    required this.rows,
    required this.outputCurrency,
    required this.result,
    required this.resultUsd,
    required this.unitsPerUsd,
    required this.rateMeta,
    required this.createdAt,
  });

  static const int cacheVersion = 1;

  final String id;
  final List<CalculationRow> rows;
  final Currency outputCurrency;
  final double result;
  final double resultUsd;

  /// Only the rates needed to explain this entry are stored.
  final Map<String, double> unitsPerUsd;
  final HistoryRateMeta rateMeta;
  final DateTime createdAt;

  int get currencyCount => rows.map((row) => row.currency.code).toSet().length;

  Map<String, Object?> toJson() => {
    'version': cacheVersion,
    'id': id,
    'rows': rows.map((row) => row.toJson()).toList(),
    'outputCurrency': outputCurrency.toJson(),
    'result': result,
    'resultUsd': resultUsd,
    'unitsPerUsd': unitsPerUsd,
    'rateMeta': rateMeta.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static CalculationHistoryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    if (json['version'] != cacheVersion) return null;

    final id = json['id'];
    final outputCurrency = Currency.fromJson(json['outputCurrency']);
    final result = json['result'];
    final resultUsd = json['resultUsd'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final rawRows = json['rows'];
    if (id is! String ||
        id.trim().isEmpty ||
        outputCurrency == null ||
        result is! num ||
        resultUsd is! num ||
        createdAt == null ||
        rawRows is! List) {
      return null;
    }

    final rows = <CalculationRow>[];
    for (var index = 0; index < rawRows.length; index++) {
      final row = CalculationRow.fromJson(
        rawRows[index],
        fallbackId: 'restored-$index',
      );
      if (row != null) rows.add(row);
    }
    if (rows.isEmpty) return null;

    final units = <String, double>{};
    final rawUnits = json['unitsPerUsd'];
    if (rawUnits is Map) {
      for (final entry in rawUnits.entries) {
        if (entry.key is! String || entry.value is! num) continue;
        final rate = (entry.value as num).toDouble();
        if (!rate.isFinite || rate <= 0) continue;
        units[(entry.key as String).toUpperCase()] = rate;
      }
    }

    final resultValue = result.toDouble();
    final resultUsdValue = resultUsd.toDouble();
    if (!resultValue.isFinite || !resultUsdValue.isFinite) {
      return null;
    }

    return CalculationHistoryEntry(
      id: id,
      rows: List.unmodifiable(rows),
      outputCurrency: outputCurrency,
      result: resultValue,
      resultUsd: resultUsdValue,
      unitsPerUsd: Map.unmodifiable(units),
      rateMeta: HistoryRateMeta.fromJson(json['rateMeta']),
      createdAt: createdAt.toUtc(),
    );
  }

  Map<String, Object?> toListJson() => toJson();
}
