/// A validated, timestamped set of rates expressed against one USD.
///
/// `unitsPerUsd['EUR'] == 0.9` means 1 USD = 0.9 EUR.
/// `unitsPerUsd['BTC'] == 0.0000125` means 1 USD = 0.0000125 BTC.
class RateBundle {
  RateBundle({
    required Map<String, double> fiatUnitsPerUsd,
    required Map<String, double> cryptoUnitsPerUsd,
    required this.fiatUpdatedAt,
    required this.cryptoUpdatedAt,
    required this.fetchedAt,
  }) : fiatUnitsPerUsd = Map.unmodifiable(fiatUnitsPerUsd),
       cryptoUnitsPerUsd = Map.unmodifiable(cryptoUnitsPerUsd);

  static const int cacheVersion = 1;

  final Map<String, double> fiatUnitsPerUsd;
  final Map<String, double> cryptoUnitsPerUsd;

  /// The timestamp reported by the fiat provider for its rate set.
  final DateTime? fiatUpdatedAt;

  /// The most recent price timestamp reported by the crypto provider.
  final DateTime? cryptoUpdatedAt;

  /// When this snapshot was successfully retrieved/saved.
  final DateTime fetchedAt;

  Map<String, double> get allUnitsPerUsd => <String, double>{
    ...fiatUnitsPerUsd,
    ...cryptoUnitsPerUsd,
  };

  bool get hasFiat => fiatUnitsPerUsd.isNotEmpty;
  bool get hasCrypto => cryptoUnitsPerUsd.isNotEmpty;
  bool get hasAnyRates => hasFiat || hasCrypto;

  double? unitsPerUsd(String code) {
    final normalized = code.toUpperCase();
    if (normalized == 'USD') return 1;
    return fiatUnitsPerUsd[normalized] ?? cryptoUnitsPerUsd[normalized];
  }

  Map<String, Object?> toJson() => {
    'version': cacheVersion,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'fiatUpdatedAt': fiatUpdatedAt?.toUtc().toIso8601String(),
    'cryptoUpdatedAt': cryptoUpdatedAt?.toUtc().toIso8601String(),
    'fiat': fiatUnitsPerUsd,
    'crypto': cryptoUnitsPerUsd,
  };

  /// Returns null instead of throwing when persisted data is malformed.
  static RateBundle? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    if (json['version'] != cacheVersion) return null;

    final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
    if (fetchedAt == null) return null;

    final fiat = _readRateMap(json['fiat']);
    final crypto = _readRateMap(json['crypto']);
    if (fiat.isEmpty && crypto.isEmpty) return null;

    return RateBundle(
      fiatUnitsPerUsd: fiat,
      cryptoUnitsPerUsd: crypto,
      fiatUpdatedAt: _readDate(json['fiatUpdatedAt']) ?? fetchedAt,
      cryptoUpdatedAt: _readDate(json['cryptoUpdatedAt']) ?? fetchedAt,
      fetchedAt: fetchedAt,
    );
  }

  static Map<String, double> _readRateMap(Object? value) {
    if (value is! Map) return const {};
    final result = <String, double>{};
    for (final entry in value.entries) {
      final code = entry.key;
      final rawRate = entry.value;
      if (code is! String || code.trim().isEmpty) continue;
      final rate = rawRate is num ? rawRate.toDouble() : null;
      if (rate == null || !rate.isFinite || rate <= 0) continue;
      result[code.trim().toUpperCase()] = rate;
    }
    return result;
  }

  static DateTime? _readDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
