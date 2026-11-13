import 'package:calc2/l10n/app_localizations.dart';
import 'package:calc2/models/app_preferences.dart';
import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/utils/formatting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizations.forLanguage(AppLanguage.en);
  final tr = AppLocalizations.forLanguage(AppLanguage.tr);

  test('supports exactly English and Turkish', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      ['en', 'tr'],
    );
    expect(en.localeName, 'en_US');
    expect(tr.localeName, 'tr_TR');
    expect(en.decimalSeparator, '.');
    expect(tr.decimalSeparator, ',');
    expect(
      AppLocalizations.forLanguage(AppLanguage.en).locale,
      const Locale('en'),
    );
    expect(
      AppLocalizations.forLanguage(AppLanguage.tr).locale,
      const Locale('tr'),
    );
  });

  test('core navigation and screen copy is complete in both languages', () {
    final english = <String>[
      en.navCalculator,
      en.navMarkets,
      en.navFavorites,
      en.navHistory,
      en.navSettings,
      en.calculatorTitle,
      en.marketsTitle,
      en.favoritesTitle,
      en.historyTitle,
      en.settingsTitle,
      en.result,
      en.outputCurrency,
      en.saveToHistory,
      en.clearRows,
      en.historyEmptyBody,
      en.marketUnavailableBody,
      en.chartUnavailable,
      en.referenceCurrency,
      en.languageDescription,
      en.aboutBody,
    ];
    final turkish = <String>[
      tr.navCalculator,
      tr.navMarkets,
      tr.navFavorites,
      tr.navHistory,
      tr.navSettings,
      tr.calculatorTitle,
      tr.marketsTitle,
      tr.favoritesTitle,
      tr.historyTitle,
      tr.settingsTitle,
      tr.result,
      tr.outputCurrency,
      tr.saveToHistory,
      tr.clearRows,
      tr.historyEmptyBody,
      tr.marketUnavailableBody,
      tr.chartUnavailable,
      tr.referenceCurrency,
      tr.languageDescription,
      tr.aboutBody,
    ];

    expect(english.every((value) => value.trim().isNotEmpty), isTrue);
    expect(turkish.every((value) => value.trim().isNotEmpty), isTrue);
    expect(turkish, isNot(equals(english)));
    expect(en.appName, 'Birimm');
    expect(tr.appName, 'Birimm');
    expect(en.english, 'English');
    expect(tr.turkish, 'Türkçe');
  });

  test('Turkish coverage includes all primary destinations and states', () {
    expect(tr.navCalculator, 'Hesap');
    expect(tr.navMarkets, 'Piyasalar');
    expect(tr.navFavorites, 'Favoriler');
    expect(tr.navHistory, 'Geçmiş');
    expect(tr.navSettings, 'Ayarlar');
    expect(tr.live, 'Canlı');
    expect(tr.cached, 'Önbellek');
    expect(tr.unavailable, 'Kullanılamıyor');
    expect(tr.themeDark, 'Koyu');
    expect(tr.themeLight, 'Açık');
    expect(tr.filterPopular, 'Popüler');
    expect(tr.filterGainers, 'Yükselenler');
    expect(tr.filterLosers, 'Düşenler');
    expect(tr.fiatCurrencies, 'Fiat para birimleri');
    expect(tr.cryptoAssets, 'Kripto varlıklar');
  });

  test('interpolated and pluralized copy follows each locale', () {
    expect(en.rowsSummary(1, 1), '1 row · 1 currency');
    expect(en.rowsSummary(2, 3), '2 rows · 3 currencies');
    expect(tr.rowsSummary(2, 3), '2 satır · 3 para birimi');
    expect(en.favoriteCount(1), '1 favorite');
    expect(en.favoriteCount(3), '3 favorites');
    expect(tr.favoriteCount(3), '3 favori');
    expect(en.historyEntries(1), '1 calculation');
    expect(en.historyEntries(4), '4 calculations');
    expect(tr.historyEntries(4), '4 kayıt');
    expect(en.clearHistoryBody(1), contains('1 saved calculation'));
    expect(en.clearHistoryBody(2), contains('2 saved calculations'));
    expect(tr.clearHistoryBody(2), contains('2 kayıt'));
    expect(en.errorNoRate('XYZ'), 'No rate is available for XYZ.');
    expect(tr.errorNoRate('XYZ'), 'XYZ için kur yok.');
    expect(en.outputCurrencyChanged('TRY'), contains('TRY'));
    expect(tr.outputCurrencyChanged('TRY'), contains('TRY'));
    expect(en.unitRateLine('EUR', '32.5', 'TRY'), '1 EUR = 32.5 TRY');
    expect(en.noCurrencyMatches('zzz'), contains('zzz'));
    expect(tr.noCurrencyMatches('zzz'), contains('zzz'));
    expect(en.onlyFavorites, isNot(tr.onlyFavorites));
  });

  test('number and timestamp formatting use locale separators', () {
    final usd = CurrencyCatalog.fiatCurrency('USD');
    expect(formatAmount(1234.5, usd, localeName: en.localeName), '1,234.50');
    expect(formatAmount(1234.5, usd, localeName: tr.localeName), '1.234,50');
    expect(formatPercent(2.5, localeName: en.localeName), '+2.50%');
    expect(formatPercent(-1.25, localeName: tr.localeName), '-1,25%');
    expect(formatUnitRate(0.9, localeName: tr.localeName), '0,90');
    expect(
      formatTimestamp(
        DateTime.utc(2026, 10, 25, 9),
        now: DateTime.utc(2026, 10, 25, 9, 30),
        localeName: tr.localeName,
      ),
      '30 dk önce',
    );
    expect(
      formatTimestamp(
        DateTime.utc(2026, 10, 25, 9),
        now: DateTime.utc(2026, 10, 25, 9, 30),
        localeName: en.localeName,
      ),
      '30m ago',
    );
    expect(
      formatAmount(
        0.000000001,
        CurrencyCatalog.byCode('BTC')!,
        localeName: tr.localeName,
      ),
      '1.0000e-9',
    );
  });
}
