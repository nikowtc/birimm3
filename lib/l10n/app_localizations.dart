import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_info.dart';
import '../models/app_preferences.dart';
import 'translations/en.dart';
import 'translations/es.dart';
import 'translations/fr.dart';
import 'translations/ja.dart';
import 'translations/pt_br.dart';
import 'translations/ru.dart';
import 'translations/tr.dart';
import 'translations/zh.dart';

/// Typed, dependency-free copy for the eight supported Birimm locales.
///
/// Every locale mirrors [enStrings]; unknown keys fall back to English so a
/// missing translation can never surface an empty label.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('tr'),
    Locale('ru'),
    Locale('es'),
    Locale('fr'),
    Locale('zh'),
    Locale('ja'),
    Locale('pt', 'BR'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static AppLocalizations forLanguage(AppLanguage language) {
    return AppLocalizations(language.locale);
  }

  Map<String, String> get _strings {
    return switch (locale.languageCode) {
      'tr' => trStrings,
      'ru' => ruStrings,
      'es' => esStrings,
      'fr' => frStrings,
      'zh' => zhStrings,
      'ja' => jaStrings,
      'pt' => ptBrStrings,
      _ => enStrings,
    };
  }

  String get localeName {
    return switch (locale.languageCode) {
      'tr' => 'tr_TR',
      'ru' => 'ru_RU',
      'es' => 'es_ES',
      'fr' => 'fr_FR',
      'zh' => 'zh_CN',
      'ja' => 'ja_JP',
      'pt' => 'pt_BR',
      _ => 'en_US',
    };
  }

  String get decimalSeparator {
    return switch (locale.languageCode) {
      'tr' || 'ru' || 'es' || 'fr' || 'pt' => ',',
      _ => '.',
    };
  }

  /// Raw lookup for keys that do not need a typed getter yet.
  String text(String key) => _t(key);

  String _t(String key, [Map<String, String> args = const {}]) {
    final template = _strings[key] ?? enStrings[key] ?? key;
    if (args.isEmpty) return template;
    var result = template;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  String _plural(String key, int count) {
    final singular = count == 1 ? (_strings['$key.one'] ?? enStrings['$key.one']) : null;
    return _t(singular == null ? key : '$key.one', {'count': '$count'});
  }

  String get appName => 'Birimm';

  String languageName(AppLanguage language) {
    return switch (language) {
      AppLanguage.en => 'English',
      AppLanguage.tr => 'Türkçe',
      AppLanguage.ru => 'Русский',
      AppLanguage.es => 'Español',
      AppLanguage.fr => 'Français',
      AppLanguage.zh => '简体中文',
      AppLanguage.ja => '日本語',
      AppLanguage.ptBr => 'Português (Brasil)',
    };
  }

  String get versionLabel => _t('versionLabel', {'version': AppInfo.version});

  String get copyright => _t('copyright', {'year': '${DateTime.now().year}'});

  String noCurrencyMatches(String query) => _t('noCurrencyMatches', {'q': query});

  String noAssetMatches(String query) => _t('noAssetMatches', {'q': query});

  String searchNoResultsFor(String query) =>
      _t('searchNoResultsFor', {'q': query});

  String quickRate(String from, String rate, String to) =>
      _t('quickRate', {'from': from, 'rate': rate, 'to': to});

  String quickInverseRate(String from, String rate, String to) =>
      _t('quickInverseRate', {'from': from, 'rate': rate, 'to': to});

  String snapshotSaved(String time) => _t('snapshotSaved', {'time': time});

  String providerTooltip(String provider, String time) =>
      _t('providerTooltip', {'provider': provider, 'time': time});

  String errorNoRate(String code) => _t('errorNoRate', {'code': code});

  String unitRateLine(String from, String rate, String to) =>
      _t('unitRateLine', {'from': from, 'rate': rate, 'to': to});

  String rowEquivalent(String amount, String code) =>
      _t('rowEquivalent', {'amount': amount, 'code': code});

  String rowsSummary(int rows, int currencies) =>
      '${_plural('rowCount', rows)} · ${_plural('currencyCount', currencies)}';

  String rowRateLabel(String code, String rate, String output) =>
      _t('rowRateLabel', {'code': code, 'rate': rate, 'output': output});

  String addedCurrencyToCalculator(String code) =>
      _t('addedCurrencyToCalculator', {'code': code});

  String outputCurrencyChanged(String code) =>
      _t('outputCurrencyChanged', {'code': code});

  String favoriteCount(int count) => _plural('favoriteCount', count);

  String clearHistoryBody(int count) => _plural('clearHistoryBody', count);

  String historyEntries(int count) => _plural('historyEntries', count);

  String storedResultNote(String time) =>
      _t('storedResultNote', {'time': time});

  String assetsLoaded(int count) => _plural('assetsLoaded', count);

  String currenciesLoaded(int count) => _plural('currenciesLoaded', count);

  String marketCachedNote(String time) =>
      _t('marketCachedNote', {'time': time});

  String searchLoadedOnly(int count) =>
      _t('searchLoadedOnly', {'count': '$count'});

  String referenceEquivalent(String amount, String reference, String code) =>
      _t('referenceEquivalent', {
        'amount': amount,
        'reference': reference,
        'code': code,
      });

  String inverseEquivalent(String amount, String code, String reference) =>
      _t('inverseEquivalent', {
        'amount': amount,
        'code': code,
        'reference': reference,
      });

  String chartTitle(String name) => _t('chartTitle', {'name': name});

  String fiatReferenceNote(String reference) =>
      _t('fiatReferenceNote', {'reference': reference});

  String favoritesSaved(int count) => _plural('favoritesSaved', count);

  String historySaved(int count) => _plural('historySaved', count);

  String minutesAgo(int count) => _plural('minutesAgo', count);

  // Generated getters for the complete key set.
  String get appTagline => _t('appTagline');
  String get appDescription => _t('appDescription');
  String get navCalculator => _t('navCalculator');
  String get navMarkets => _t('navMarkets');
  String get navFavorites => _t('navFavorites');
  String get navHistory => _t('navHistory');
  String get navSettings => _t('navSettings');
  String get close => _t('close');
  String get cancel => _t('cancel');
  String get retry => _t('retry');
  String get refresh => _t('refresh');
  String get refreshAll => _t('refreshAll');
  String get updating => _t('updating');
  String get live => _t('live');
  String get cached => _t('cached');
  String get stale => _t('stale');
  String get unavailable => _t('unavailable');
  String get updated => _t('updated');
  String get unknown => _t('unknown');
  String get loading => _t('loading');
  String get justNow => _t('justNow');
  String get clearSearch => _t('clearSearch');
  String get save => _t('save');
  String get delete => _t('delete');
  String get remove => _t('remove');
  String get done => _t('done');
  String get back => _t('back');
  String get add => _t('add');
  String get copy => _t('copy');
  String get copied => _t('copied');
  String get viewDetails => _t('viewDetails');
  String get data => _t('data');
  String get rate => _t('rate');
  String get price => _t('price');
  String get fiat => _t('fiat');
  String get crypto => _t('crypto');
  String get stocks => _t('stocks');
  String get metals => _t('metals');
  String get indices => _t('indices');
  String get fiatCurrencies => _t('fiatCurrencies');
  String get cryptoAssets => _t('cryptoAssets');
  String get stockAssets => _t('stockAssets');
  String get metalAssets => _t('metalAssets');
  String get indexAssets => _t('indexAssets');
  String get searchCurrenciesHint => _t('searchCurrenciesHint');
  String get searchByHint => _t('searchByHint');
  String get searchAssetsHint => _t('searchAssetsHint');
  String get searchFiatHint => _t('searchFiatHint');
  String get searchAllHint => _t('searchAllHint');
  String get addToFavorites => _t('addToFavorites');
  String get removeFromFavorites => _t('removeFromFavorites');
  String get onlyFavorites => _t('onlyFavorites');
  String get removeRow => _t('removeRow');
  String get addRow => _t('addRow');
  String get clearRows => _t('clearRows');
  String get clearRowsTitle => _t('clearRowsTitle');
  String get clearRowsBody => _t('clearRowsBody');
  String get calculatorTitle => _t('calculatorTitle');
  String get calculatorSubtitle => _t('calculatorSubtitle');
  String get quickConversion => _t('quickConversion');
  String get quickConversionSubtitle => _t('quickConversionSubtitle');
  String get quickFrom => _t('quickFrom');
  String get quickTo => _t('quickTo');
  String get swapCurrencies => _t('swapCurrencies');
  String get quickResult => _t('quickResult');
  String get quickEnterAmount => _t('quickEnterAmount');
  String get quickCopyResult => _t('quickCopyResult');
  String get quickFavoritePair => _t('quickFavoritePair');
  String get quickUnfavoritePair => _t('quickUnfavoritePair');
  String get quickRecent => _t('quickRecent');
  String get quickSavedPairs => _t('quickSavedPairs');
  String get quickNoRecent => _t('quickNoRecent');
  String get quickPhraseLabel => _t('quickPhraseLabel');
  String get quickPhraseHint => _t('quickPhraseHint');
  String get quickPhraseApply => _t('quickPhraseApply');
  String get quickPhraseApplied => _t('quickPhraseApplied');
  String get quickPhraseFailed => _t('quickPhraseFailed');
  String get quickPhraseExamples => _t('quickPhraseExamples');
  String get quickRecentCleared => _t('quickRecentCleared');
  String get clearRecent => _t('clearRecent');
  String get advancedCalculator => _t('advancedCalculator');
  String get advancedCalculatorSubtitle => _t('advancedCalculatorSubtitle');
  String get expandAdvanced => _t('expandAdvanced');
  String get collapseAdvanced => _t('collapseAdvanced');
  String get currenciesLabel => _t('currenciesLabel');
  String get amountHint => _t('amountHint');
  String get currency => _t('currency');
  String get outputCurrency => _t('outputCurrency');
  String get outputLabel => _t('outputLabel');
  String get inputsLabel => _t('inputsLabel');
  String get selectCurrency => _t('selectCurrency');
  String get selectOutputCurrency => _t('selectOutputCurrency');
  String get result => _t('result');
  String get resultEmpty => _t('resultEmpty');
  String get resultInvalid => _t('resultInvalid');
  String get conversionNote => _t('conversionNote');
  String get usdReferenceNote => _t('usdReferenceNote');
  String get saveToHistory => _t('saveToHistory');
  String get calculationSaved => _t('calculationSaved');
  String get calculationSaveFailed => _t('calculationSaveFailed');
  String get nothingToSave => _t('nothingToSave');
  String get invalidAmount => _t('invalidAmount');
  String get amountTooLarge => _t('amountTooLarge');
  String get resultTooLarge => _t('resultTooLarge');
  String get singleCurrency => _t('singleCurrency');
  String get ratesTitle => _t('ratesTitle');
  String get fiatRates => _t('fiatRates');
  String get cryptoPrices => _t('cryptoPrices');
  String get stockPrices => _t('stockPrices');
  String get metalPrices => _t('metalPrices');
  String get indexPrices => _t('indexPrices');
  String get marketData => _t('marketData');
  String get exchangeRates => _t('exchangeRates');
  String get ratesAndData => _t('ratesAndData');
  String get refreshing => _t('refreshing');
  String get noRateSnapshot => _t('noRateSnapshot');
  String get rateSnapshot => _t('rateSnapshot');
  String get ratesUnavailable => _t('ratesUnavailable');
  String get ratesUpdateError => _t('ratesUpdateError');
  String get cachedRatesLoadError => _t('cachedRatesLoadError');
  String get preferencesLoadError => _t('preferencesLoadError');
  String get preferencesSaveError => _t('preferencesSaveError');
  String get favoritesLoadError => _t('favoritesLoadError');
  String get favoritesSaveError => _t('favoritesSaveError');
  String get historyLoadError => _t('historyLoadError');
  String get historySaveError => _t('historySaveError');
  String get linkOpenFailed => _t('linkOpenFailed');
  String get favoritesTitle => _t('favoritesTitle');
  String get favoritesSubtitle => _t('favoritesSubtitle');
  String get favoriteCurrencies => _t('favoriteCurrencies');
  String get noFavoritesTitle => _t('noFavoritesTitle');
  String get noFavoritesBody => _t('noFavoritesBody');
  String get noFavoriteCurrencies => _t('noFavoriteCurrencies');
  String get browseMarkets => _t('browseMarkets');
  String get addToCalculator => _t('addToCalculator');
  String get setAsOutput => _t('setAsOutput');
  String get noMarketQuote => _t('noMarketQuote');
  String get noRate => _t('noRate');
  String get favoritePricesNote => _t('favoritePricesNote');
  String get historyTitle => _t('historyTitle');
  String get historySubtitle => _t('historySubtitle');
  String get historyEmptyTitle => _t('historyEmptyTitle');
  String get historyEmptyBody => _t('historyEmptyBody');
  String get goToCalculator => _t('goToCalculator');
  String get clearHistory => _t('clearHistory');
  String get clearHistoryTitle => _t('clearHistoryTitle');
  String get clearHistoryConfirm => _t('clearHistoryConfirm');
  String get historyCleared => _t('historyCleared');
  String get storedResult => _t('storedResult');
  String get currentResult => _t('currentResult');
  String get currentResultNote => _t('currentResultNote');
  String get restoreToCalculator => _t('restoreToCalculator');
  String get restoredToCalculator => _t('restoredToCalculator');
  String get deleteEntry => _t('deleteEntry');
  String get entryDeleted => _t('entryDeleted');
  String get savedWithLiveRates => _t('savedWithLiveRates');
  String get savedWithCachedRates => _t('savedWithCachedRates');
  String get savedWithUnavailableRates => _t('savedWithUnavailableRates');
  String get calculationDetails => _t('calculationDetails');
  String get currentRatesUnavailable => _t('currentRatesUnavailable');
  String get historyRateSnapshotNote => _t('historyRateSnapshotNote');
  String get marketsTitle => _t('marketsTitle');
  String get marketsSubtitle => _t('marketsSubtitle');
  String get cryptoMarkets => _t('cryptoMarkets');
  String get stockMarkets => _t('stockMarkets');
  String get metalMarkets => _t('metalMarkets');
  String get fiatMarkets => _t('fiatMarkets');
  String get indexOverview => _t('indexOverview');
  String get filter => _t('filter');
  String get filterAll => _t('filterAll');
  String get filterTop100 => _t('filterTop100');
  String get filterPopular => _t('filterPopular');
  String get filterGainers => _t('filterGainers');
  String get filterLosers => _t('filterLosers');
  String get filterFavorites => _t('filterFavorites');
  String get sortBy => _t('sortBy');
  String get sortMarketCap => _t('sortMarketCap');
  String get sortPrice => _t('sortPrice');
  String get sortChange => _t('sortChange');
  String get sortName => _t('sortName');
  String get sortRate => _t('sortRate');
  String get ascending => _t('ascending');
  String get descending => _t('descending');
  String get loadMore => _t('loadMore');
  String get loadingMore => _t('loadingMore');
  String get marketUnavailableTitle => _t('marketUnavailableTitle');
  String get marketUnavailableBody => _t('marketUnavailableBody');
  String get marketEmpty => _t('marketEmpty');
  String get marketRefreshError => _t('marketRefreshError');
  String get marketPricesInOutput => _t('marketPricesInOutput');
  String get marketPricesInUsd => _t('marketPricesInUsd');
  String get marketDataDisclaimer => _t('marketDataDisclaimer');
  String get marketsDataBy => _t('marketsDataBy');
  String get noMarketMatches => _t('noMarketMatches');
  String get noFavoriteAssets => _t('noFavoriteAssets');
  String get filterNoResults => _t('filterNoResults');
  String get marketCap => _t('marketCap');
  String get volume24h => _t('volume24h');
  String get change24h => _t('change24h');
  String get high => _t('high');
  String get low => _t('low');
  String get periodChange => _t('periodChange');
  String get chartLoading => _t('chartLoading');
  String get chartUnavailable => _t('chartUnavailable');
  String get chartCachedNote => _t('chartCachedNote');
  String get chartError => _t('chartError');
  String get chartRetry => _t('chartRetry');
  String get chartRange => _t('chartRange');
  String get chart24h => _t('chart24h');
  String get chart7d => _t('chart7d');
  String get chart30d => _t('chart30d');
  String get chartUsdNote => _t('chartUsdNote');
  String get viewChart => _t('viewChart');
  String get referenceCurrency => _t('referenceCurrency');
  String get selectReference => _t('selectReference');
  String get fiatRateListNote => _t('fiatRateListNote');
  String get noFiatRates => _t('noFiatRates');
  String get fiatMarketStatus => _t('fiatMarketStatus');
  String get selectOutputOrRow => _t('selectOutputOrRow');
  String get settingsTitle => _t('settingsTitle');
  String get settingsSubtitle => _t('settingsSubtitle');
  String get preferencesTitle => _t('preferencesTitle');
  String get appearance => _t('appearance');
  String get appearanceDescription => _t('appearanceDescription');
  String get themeDark => _t('themeDark');
  String get themeLight => _t('themeLight');
  String get themeSystem => _t('themeSystem');
  String get language => _t('language');
  String get languageDescription => _t('languageDescription');
  String get languageNamesNative => _t('languageNamesNative');
  String get settingsOutputDescription => _t('settingsOutputDescription');
  String get settingsRatesDescription => _t('settingsRatesDescription');
  String get marketOverview => _t('marketOverview');
  String get english => _t('english');
  String get turkish => _t('turkish');
  String get storage => _t('storage');
  String get storageDescription => _t('storageDescription');
  String get attribution => _t('attribution');
  String get fiatDataBy => _t('fiatDataBy');
  String get cryptoDataBy => _t('cryptoDataBy');
  String get equityDataBy => _t('equityDataBy');
  String get metalDataBy => _t('metalDataBy');
  String get dataDescription => _t('dataDescription');
  String get about => _t('about');
  String get aboutBody => _t('aboutBody');
  String get aboutDeveloper => _t('aboutDeveloper');
  String get developedBy => _t('developedBy');
  String get projectLink => _t('projectLink');
  String get developerLink => _t('developerLink');
  String get thirdPartyLicenses => _t('thirdPartyLicenses');
  String get dataSources => _t('dataSources');
  String get appVersion => _t('appVersion');
  String get softwareCredits => _t('softwareCredits');
  String get sourceAvailableLicense => _t('sourceAvailableLicense');
  String get stocksUnavailable => _t('stocksUnavailable');
  String get stocksNeedProxy => _t('stocksNeedProxy');
  String get metalUnavailable => _t('metalUnavailable');
  String get marketPartial => _t('marketPartial');
  String get marketSource => _t('marketSource');
  String get perOunce => _t('perOunce');
  String get perGram => _t('perGram');
  String get gold => _t('gold');
  String get silver => _t('silver');
  String get goldGram => _t('goldGram');
  String get silverGram => _t('silverGram');
  String get goldOunce => _t('goldOunce');
  String get silverOunce => _t('silverOunce');
  String get closeSettings => _t('closeSettings');
  String get tryAnotherSearch => _t('tryAnotherSearch');
  String get quickDefaults => _t('quickDefaults');
  String get errorNetwork => _t('errorNetwork');
  String get errorRateLimit => _t('errorRateLimit');
  String get errorProvider => _t('errorProvider');

}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
