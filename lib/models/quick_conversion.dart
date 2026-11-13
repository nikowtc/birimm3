/// A saved from/to pair in Quick Conversion.
class QuickConversionPair {
  const QuickConversionPair({required this.fromCode, required this.toCode});

  final String fromCode;
  final String toCode;

  String get key => '${fromCode}_$toCode';

  Map<String, Object?> toJson() => {'from': fromCode, 'to': toCode};

  static QuickConversionPair? fromJson(Object? value) {
    if (value is! Map) return null;
    final from = value['from'];
    final to = value['to'];
    if (from is! String || to is! String) return null;
    final fromCode = from.trim().toUpperCase();
    final toCode = to.trim().toUpperCase();
    if (fromCode.isEmpty || toCode.isEmpty || fromCode == toCode) return null;
    return QuickConversionPair(fromCode: fromCode, toCode: toCode);
  }
}

/// One recent conversion. Only codes and the entered amount are stored; the
/// result is always recalculated from current rates.
class QuickConversionRecord {
  const QuickConversionRecord({
    required this.amount,
    required this.fromCode,
    required this.toCode,
    required this.createdAt,
  });

  final String amount;
  final String fromCode;
  final String toCode;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'amount': amount,
    'from': fromCode,
    'to': toCode,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static QuickConversionRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final amount = value['amount'];
    final from = value['from'];
    final to = value['to'];
    final createdAt = DateTime.tryParse(value['createdAt'] as String? ?? '');
    if (amount is! String ||
        from is! String ||
        to is! String ||
        createdAt == null) {
      return null;
    }
    final fromCode = from.trim().toUpperCase();
    final toCode = to.trim().toUpperCase();
    if (fromCode.isEmpty || toCode.isEmpty || fromCode == toCode) return null;
    return QuickConversionRecord(
      amount: amount,
      fromCode: fromCode,
      toCode: toCode,
      createdAt: createdAt.toUtc(),
    );
  }
}

class QuickConversionData {
  const QuickConversionData({
    this.pairs = const [],
    this.recent = const [],
  });

  static const int storageVersion = 1;

  final List<QuickConversionPair> pairs;
  final List<QuickConversionRecord> recent;

  QuickConversionData copyWith({
    List<QuickConversionPair>? pairs,
    List<QuickConversionRecord>? recent,
  }) {
    return QuickConversionData(
      pairs: pairs ?? this.pairs,
      recent: recent ?? this.recent,
    );
  }

  Map<String, Object?> toJson() => {
    'version': storageVersion,
    'pairs': pairs.map((pair) => pair.toJson()).toList(),
    'recent': recent.map((record) => record.toJson()).toList(),
  };

  static QuickConversionData fromJson(Object? value) {
    if (value is! Map) return const QuickConversionData();
    final json = Map<String, Object?>.from(value);
    if (json['version'] != storageVersion) return const QuickConversionData();
    final pairs = <QuickConversionPair>[];
    final seenPairs = <String>{};
    final rawPairs = json['pairs'];
    if (rawPairs is List) {
      for (final raw in rawPairs) {
        final pair = QuickConversionPair.fromJson(raw);
        if (pair == null || !seenPairs.add(pair.key)) continue;
        pairs.add(pair);
      }
    }
    final recent = <QuickConversionRecord>[];
    final rawRecent = json['recent'];
    if (rawRecent is List) {
      for (final raw in rawRecent) {
        final record = QuickConversionRecord.fromJson(raw);
        if (record == null) continue;
        recent.add(record);
        if (recent.length >= 8) break;
      }
    }
    return QuickConversionData(
      pairs: List.unmodifiable(pairs),
      recent: List.unmodifiable(recent),
    );
  }
}
