import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/currency.dart';

String formatAmount(
  double value,
  Currency currency, {
  String localeName = 'en_US',
}) {
  if (!value.isFinite) return '—';
  final normalized = value == 0 ? 0.0 : value;
  final absolute = normalized.abs();

  if (absolute > 0 && absolute < 0.00000001) {
    return normalized.toStringAsExponential(4);
  }

  final decimals = _decimalsFor(currency, absolute);
  final formatter = NumberFormat.decimalPatternDigits(
    locale: localeName,
    decimalDigits: decimals,
  );
  final formatted = formatter.format(normalized);
  if (!currency.isCrypto && absolute >= 0.01) return formatted;
  return _trimTrailingZeros(
    formatted,
    minimumDecimals: 2,
    separator: _decimalSeparator(localeName),
  );
}

String formatRatio(double value, {String localeName = 'en_US'}) {
  if (!value.isFinite) return '—';
  final normalized = value == 0 ? 0.0 : value;
  final absolute = normalized.abs();
  if (absolute > 0 && absolute < 0.00000001) {
    return normalized.toStringAsExponential(4);
  }
  final decimals = absolute >= 100
      ? 2
      : absolute >= 1
      ? 4
      : absolute >= 0.01
      ? 6
      : 8;
  final formatted = NumberFormat.decimalPatternDigits(
    locale: localeName,
    decimalDigits: decimals,
  ).format(normalized);
  return _trimTrailingZeros(
    formatted,
    minimumDecimals: 2,
    separator: _decimalSeparator(localeName),
  );
}

String formatUnitRate(double value, {String localeName = 'en_US'}) {
  if (!value.isFinite) return '—';
  final absolute = value.abs();
  if (absolute > 0 && absolute < 0.00000001) {
    return value.toStringAsExponential(4);
  }
  final decimals = absolute >= 1000
      ? 2
      : absolute >= 1
      ? 4
      : absolute >= 0.01
      ? 6
      : 8;
  final formatted = NumberFormat.decimalPatternDigits(
    locale: localeName,
    decimalDigits: decimals,
  ).format(value);
  return _trimTrailingZeros(
    formatted,
    minimumDecimals: 2,
    separator: _decimalSeparator(localeName),
  );
}

String formatPercent(double value, {String localeName = 'en_US'}) {
  if (!value.isFinite) return '—';
  final formatted = NumberFormat.decimalPatternDigits(
    locale: localeName,
    decimalDigits: 2,
  ).format(value);
  final sign = value > 0 ? '+' : '';
  return '$sign$formatted%';
}

String formatCompact(double value, {String localeName = 'en_US'}) {
  if (!value.isFinite) return '—';
  if (value.abs() < 1000) {
    return NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: 2,
    ).format(value);
  }
  return NumberFormat.compact(locale: localeName).format(value);
}

String formatTimestamp(
  DateTime? value, {
  DateTime? now,
  String localeName = 'en_US',
}) {
  final l10n = AppLocalizations(Locale(localeName));
  if (value == null) return l10n.unknown;
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final difference = current.difference(local);

  if (difference.inSeconds < 45 && difference.inSeconds >= 0) {
    return l10n.justNow;
  }
  if (difference.inMinutes < 60 && difference.inMinutes >= 0) {
    return l10n.minutesAgo(difference.inMinutes);
  }
  final sameDay =
      local.year == current.year &&
      local.month == current.month &&
      local.day == current.day;
  if (sameDay) {
    return DateFormat.jm(localeName).format(local);
  }
  return DateFormat.yMMMd(localeName).add_Hm().format(local);
}

String formatFullTimestamp(DateTime? value, {String localeName = 'en_US'}) {
  if (value == null) {
    return AppLocalizations(Locale(localeName)).unknown;
  }
  final local = value.toLocal();
  return DateFormat.yMMMd(localeName).add_Hm().format(local);
}

int _decimalsFor(Currency currency, double absolute) {
  if (absolute == 0) return 2;
  if (currency.isCrypto) {
    if (absolute >= 1000) return 2;
    if (absolute >= 1) return 4;
    if (absolute >= 0.01) return 6;
    return 8;
  }
  if (absolute > 0 && absolute < 0.0001) return 8;
  if (absolute > 0 && absolute < 0.01) return 6;
  return 2;
}

String _decimalSeparator(String localeName) {
  return NumberFormat.decimalPattern(localeName).symbols.DECIMAL_SEP;
}

String _trimTrailingZeros(
  String value, {
  required int minimumDecimals,
  required String separator,
}) {
  if (!value.contains(separator)) return value;
  var result = value;
  while (result.endsWith('0') &&
      result.length - result.lastIndexOf(separator) - 1 > minimumDecimals) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
