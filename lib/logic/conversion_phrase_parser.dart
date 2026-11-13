import '../models/currency.dart';
import '../models/currency_catalog.dart';
import 'asset_search.dart';

/// A deterministic interpretation of a short natural-language conversion.
class ParsedConversion {
  const ParsedConversion({
    required this.amount,
    required this.from,
    required this.to,
  });

  final double amount;
  final Currency from;
  final Currency to;
}

const List<String> _connectors = [
  'kaç',
  'kac',
  'how much is',
  'how much',
  'to',
  'into',
  'in',
  'en',
  'à',
  'в',
];

/// Parses phrases such as `5 manat kaç TL`, `100 USD to EUR`, and
/// `10 gram gold to AZN` without any network or AI dependency.
ParsedConversion? parseConversionPhrase(
  String input, {
  String languageCode = 'en',
  Currency? fallbackFrom,
  Currency? fallbackTo,
}) {
  final raw = input.trim().toLowerCase();
  if (raw.isEmpty) return null;

  final amountMatch = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(raw);
  if (amountMatch == null) return null;
  final amount = parseLocalizedAmount(amountMatch.group(0)!);
  if (amount == null || !amount.isFinite) return null;

  final remainder = raw
      .replaceRange(amountMatch.start, amountMatch.end, ' ')
      .replaceAll('→', ' ')
      .replaceAll('->', ' ')
      .replaceAll('=', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final catalog = CurrencyCatalog.build();
  Currency? from;
  Currency? to;

  final split = _splitAtConnector(remainder);
  if (split != null) {
    final left = split.$1.trim();
    final right = split.$2.trim();
    if (left.isNotEmpty) {
      from = _resolvePhrase(left, catalog, languageCode) ??
          _resolvePhrase(_lastWords(left, 2), catalog, languageCode);
    }
    if (right.isNotEmpty) {
      to = _resolvePhrase(right, catalog, languageCode) ??
          _resolvePhrase(_firstWords(right, 2), catalog, languageCode);
    }
  }

  if (from == null || to == null) {
    final candidates = _candidateAssets(remainder, catalog, languageCode);
    if (candidates.length >= 2) {
      from ??= candidates.first;
      to ??= candidates.last;
    } else if (candidates.length == 1) {
      from ??= candidates.first;
      to ??= fallbackTo != null && fallbackTo.code != candidates.first.code
          ? fallbackTo
          : _differentTarget(candidates.first, catalog);
    }
  }

  from ??= fallbackFrom;
  to ??= fallbackTo;
  if (from == null || to == null || from.code == to.code) return null;

  return ParsedConversion(amount: amount, from: from, to: to);
}

(String, String)? _splitAtConnector(String value) {
  for (final connector in _connectors) {
    final pattern = connector == 'à'
        ? RegExp(r'(^|\s)à(\s|$)')
        : RegExp('(^|\\s)${RegExp.escape(connector)}(\\s|\$)');
    final match = pattern.firstMatch(value);
    if (match == null) continue;
    return (
      value.substring(0, match.start),
      value.substring(match.start + match.group(0)!.length),
    );
  }
  return null;
}

Currency? _resolvePhrase(
  String phrase,
  List<Currency> catalog,
  String languageCode,
) {
  final clean = phrase
      .replaceAll(RegExp(r'^(from|den|dan|of|the)\s+'), '')
      .trim();
  if (clean.isEmpty) return null;
  final direct = searchCurrencies(
    catalog,
    clean,
    languageCode: languageCode,
  );
  if (direct.isNotEmpty) return direct.first;

  final words = clean.split(RegExp(r'\s+'));
  for (var start = 0; start < words.length; start++) {
    final candidate = words.sublist(start).join(' ');
    final matches = searchCurrencies(
      catalog,
      candidate,
      languageCode: languageCode,
    );
    if (matches.isNotEmpty) return matches.first;
  }
  return null;
}

List<Currency> _candidateAssets(
  String value,
  List<Currency> catalog,
  String languageCode,
) {
  final words = value
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 1)
      .toList(growable: false);
  final seen = <String>{};
  final candidates = <Currency>[];
  for (var index = 0; index < words.length; index++) {
    final pair = index + 1 < words.length
        ? '${words[index]} ${words[index + 1]}'
        : words[index];
    for (final phrase in [pair, words[index]]) {
      final matches = searchCurrencies(
        catalog,
        phrase,
        languageCode: languageCode,
      );
      if (matches.isEmpty) continue;
      final match = matches.first;
      if (seen.add(match.code)) candidates.add(match);
      break;
    }
  }
  return candidates;
}

String _lastWords(String value, int count) {
  final words = value.split(RegExp(r'\s+'));
  if (words.length <= count) return value;
  return words.sublist(words.length - count).join(' ');
}

String _firstWords(String value, int count) {
  final words = value.split(RegExp(r'\s+'));
  if (words.length <= count) return value;
  return words.sublist(0, count).join(' ');
}

Currency? _differentTarget(Currency source, List<Currency> catalog) {
  final preferred = source.isFiat
      ? catalog.where((currency) => currency.code == 'USD').firstOrNull
      : catalog.where((currency) => currency.code == 'USD').firstOrNull;
  if (preferred != null && preferred.code != source.code) return preferred;
  return catalog.where((currency) => currency.code != source.code).firstOrNull;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
