import '../models/currency.dart';

const Map<String, String> _foldMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
  'ğ': 'g', 'ģ': 'g',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i', 'İ': 'i',
  'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
  'ř': 'r',
  'ś': 's', 'š': 's', 'ş': 's',
  'ť': 't', 'ț': 't',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
};

/// Case- and accent-insensitive search form. Handles Turkish dotless/dotted i
/// and the combining dot that Dart adds when lower-casing `İ`.
String foldSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (rune == 0x0307) continue;
    final lower = character.toLowerCase();
    if (lower == 'i̇') {
      buffer.write('i');
      continue;
    }
    buffer.write(_foldMap[lower] ?? lower);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9а-яα-ω\u3040-\u30ff\u3400-\u9fff]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Deterministic, provider-free asset search.
///
/// Scoring prioritizes exact codes/symbols, then localized names, aliases and
/// prefix matches. Every query token must match somewhere, so multi-word
/// phrases such as `gram altın` remain precise.
List<Currency> searchCurrencies(
  Iterable<Currency> currencies,
  String query, {
  String languageCode = 'en',
  Iterable<String> favoriteCodes = const [],
}) {
  final normalized = foldSearch(query);
  if (normalized.isEmpty) return List<Currency>.of(currencies);
  final tokens = normalized.split(' ');
  final favorites = favoriteCodes.map((code) => code.toUpperCase()).toSet();
  final scored = <(Currency, int)>[];

  for (final currency in currencies) {
    final score = _score(currency, normalized, tokens, languageCode);
    if (score <= 0) continue;
    scored.add((currency, score + (favorites.contains(currency.code) ? 5 : 0)));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    final byKind = _kindRank(a.$1.kind).compareTo(_kindRank(b.$1.kind));
    if (byKind != 0) return byKind;
    return a.$1.code.compareTo(b.$1.code);
  });
  return [for (final entry in scored) entry.$1];
}

int _score(
  Currency currency,
  String query,
  List<String> tokens,
  String languageCode,
) {
  final code = foldSearch(currency.code);
  final symbol = foldSearch(currency.symbol);
  final name = foldSearch(currency.localizedName(languageCode));
  final englishName = foldSearch(currency.name);
  final aliases = currency.aliases.map(foldSearch).toList(growable: false);
  final haystack = [code, symbol, name, englishName, ...aliases].join(' ');

  if (!tokens.every((token) => haystack.contains(token))) return 0;

  if (code == query) return 1000;
  if (symbol.isNotEmpty && symbol == query) return 940;
  if (name == query || englishName == query) return 900;
  if (aliases.contains(query)) return 860;
  if (code.startsWith(query)) return 800;
  if (symbol.isNotEmpty && symbol.startsWith(query)) return 760;
  if (name.startsWith(query) || englishName.startsWith(query)) return 720;
  if (aliases.any((alias) => alias.startsWith(query))) return 680;
  if (code.contains(query)) return 600;
  if (name.contains(query) || englishName.contains(query)) return 560;
  if (aliases.any((alias) => alias.contains(query))) return 520;
  return 300;
}

int _kindRank(CurrencyKind kind) => switch (kind) {
  CurrencyKind.fiat => 0,
  CurrencyKind.crypto => 1,
  CurrencyKind.stock => 2,
  CurrencyKind.marketIndex => 3,
  CurrencyKind.metal => 4,
};

/// Parses user-entered amounts with either decimal comma or decimal dot.
double? parseLocalizedAmount(String raw) {
  var value = raw.trim().replaceAll('−', '-');
  value = value.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (value.isEmpty) return null;
  final negative = value.startsWith('-');
  if (negative) value = value.substring(1);
  final commas = ','.allMatches(value).length;
  final dots = '.'.allMatches(value).length;
  if (commas > 0 && dots > 0) {
    final decimal = value.lastIndexOf(',') > value.lastIndexOf('.') ? ',' : '.';
    final thousands = decimal == ',' ? '.' : ',';
    value = value.replaceAll(thousands, '').replaceAll(decimal, '.');
  } else if (commas > 0) {
    if (commas == 1 && value.split(',').last.length <= 2) {
      value = value.replaceAll(',', '.');
    } else {
      value = value.replaceAll(',', '');
    }
  } else if (dots > 1) {
    value = value.replaceAll('.', '');
  }
  final parsed = double.tryParse(negative ? '-$value' : value);
  if (parsed == null || !parsed.isFinite) return null;
  return parsed;
}
