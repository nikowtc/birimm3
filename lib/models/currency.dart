/// Every selectable kind of asset in the app.
enum CurrencyKind { fiat, crypto, stock, marketIndex, metal }

/// A selectable currency or market asset.
///
/// Crypto assets keep their CoinGecko identifier; stocks and indices keep the
/// Yahoo Finance ticker; metals are quoted by the Gold API. API concerns stay
/// out of the UI and out of persisted history.
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.kind,
    this.coinGeckoId,
    this.yahooSymbol,
    this.quoteCurrency = 'USD',
    this.aliases = const [],
    this.localizedNames = const {},
  });

  final String code;
  final String name;
  final String symbol;
  final CurrencyKind kind;
  final String? coinGeckoId;
  final String? yahooSymbol;

  /// The currency the provider quotes this asset in. Prices are normalized to
  /// USD before they reach the calculator.
  final String quoteCurrency;

  /// Lower-case search terms (local spellings, abbreviations, provider names).
  final List<String> aliases;

  /// Language code (`tr`, `ru`, …) to display/search name.
  final Map<String, String> localizedNames;

  bool get isCrypto => kind == CurrencyKind.crypto;
  bool get isFiat => kind == CurrencyKind.fiat;
  bool get isStock => kind == CurrencyKind.stock;
  bool get isIndex => kind == CurrencyKind.marketIndex;
  bool get isMetal => kind == CurrencyKind.metal;

  bool get isMarketAsset => !isFiat;

  bool get hasProviderSymbol =>
      (coinGeckoId?.isNotEmpty ?? false) || (yahooSymbol?.isNotEmpty ?? false);

  String localizedName(String languageCode) {
    return localizedNames[languageCode] ?? name;
  }

  List<String> get searchTerms => [
    code,
    name,
    symbol,
    ...aliases,
    ...localizedNames.values,
  ];

  String get kindKey => switch (kind) {
    CurrencyKind.fiat => 'fiat',
    CurrencyKind.crypto => 'crypto',
    CurrencyKind.stock => 'stocks',
    CurrencyKind.marketIndex => 'indices',
    CurrencyKind.metal => 'metals',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'symbol': symbol,
    'kind': kind.name,
    'coinGeckoId': coinGeckoId,
    'yahooSymbol': yahooSymbol,
    'quoteCurrency': quoteCurrency,
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (localizedNames.isNotEmpty) 'localizedNames': localizedNames,
  };

  /// Parses both the current object format and legacy bare-code values.
  static Currency? fromJson(Object? value) {
    if (value is String) {
      final code = value.trim().toUpperCase();
      if (code.isEmpty) return null;
      return Currency(
        code: code,
        name: code,
        symbol: code,
        kind: CurrencyKind.fiat,
      );
    }
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final code = json['code'];
    final name = json['name'];
    final symbol = json['symbol'];
    final kind = json['kind'];
    if (code is! String || code.trim().isEmpty) return null;
    final normalized = code.trim().toUpperCase();
    final coinGeckoId = _readString(json['coinGeckoId']);
    final parsedKind = _parseKind(kind, coinGeckoId: coinGeckoId);
    final rawAliases = json['aliases'];
    final rawNames = json['localizedNames'];
    return Currency(
      code: normalized,
      name: name is String && name.trim().isNotEmpty ? name : normalized,
      symbol: symbol is String && symbol.isNotEmpty ? symbol : normalized,
      kind: parsedKind,
      coinGeckoId: coinGeckoId,
      yahooSymbol: _readString(json['yahooSymbol']),
      quoteCurrency: _readString(json['quoteCurrency']) ?? 'USD',
      aliases: rawAliases is List
          ? List.unmodifiable(rawAliases.whereType<String>())
          : const [],
      localizedNames: rawNames is Map
          ? Map.unmodifiable(
              rawNames.map(
                (key, value) => MapEntry('$key', '$value'),
              ),
            )
          : const {},
    );
  }

  static String? _readString(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static CurrencyKind _parseKind(Object? raw, {String? coinGeckoId}) {
    if (raw == 'index') return CurrencyKind.marketIndex;
    for (final kind in CurrencyKind.values) {
      if (kind.name == raw) return kind;
    }
    return coinGeckoId == null ? CurrencyKind.fiat : CurrencyKind.crypto;
  }

  @override
  String toString() => '$code ($name)';
}
