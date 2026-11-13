import 'currency.dart';

/// Persisted fiat and crypto favorites.
///
/// Version 2 stores complete currency metadata so a dynamic market asset can
/// still be shown when its market page has not been loaded yet. Version 1
/// bare codes remain readable.
class UserFavorites {
  const UserFavorites({this.currencies = const []});

  static const int cacheVersion = 2;

  final List<Currency> currencies;

  bool get isEmpty => currencies.isEmpty;
  bool get isNotEmpty => currencies.isNotEmpty;

  bool hasCurrency(String code) {
    final normalized = code.trim().toUpperCase();
    return currencies.any((currency) => currency.code == normalized);
  }

  Currency? currencyByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final currency in currencies) {
      if (currency.code == normalized) return currency;
    }
    return null;
  }

  UserFavorites copyWith({List<Currency>? currencies}) {
    return UserFavorites(currencies: currencies ?? this.currencies);
  }

  Map<String, Object?> toJson() => {
    'version': cacheVersion,
    'currencies': currencies.map((currency) => currency.toJson()).toList(),
  };

  static UserFavorites fromJson(Object? value) {
    if (value is! Map) return const UserFavorites();
    final json = Map<String, Object?>.from(value);
    final version = json['version'];
    final rawCurrencies = json['currencies'];
    if (rawCurrencies is! List) return const UserFavorites();

    final currencies = <Currency>[];
    final seen = <String>{};
    if (version == cacheVersion) {
      for (final raw in rawCurrencies) {
        final currency = Currency.fromJson(raw);
        if (currency == null || !seen.add(currency.code)) continue;
        currencies.add(currency);
      }
    } else if (version == 1) {
      for (final raw in rawCurrencies) {
        if (raw is! String) continue;
        final code = raw.trim().toUpperCase();
        if (code.isEmpty || !seen.add(code)) continue;
        currencies.add(
          Currency(
            code: code,
            name: code,
            symbol: code,
            kind: CurrencyKind.fiat,
          ),
        );
      }
    }
    return UserFavorites(currencies: List.unmodifiable(currencies));
  }
}
