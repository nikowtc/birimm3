import '../l10n/app_localizations.dart';
import '../logic/row_calculator.dart';

String rowErrorText(AppLocalizations l10n, RowCalculationError? error) {
  if (error == null) return '';
  return switch (error.kind) {
    RowCalculationErrorKind.invalidAmount => l10n.invalidAmount,
    RowCalculationErrorKind.amountTooLarge => l10n.amountTooLarge,
    RowCalculationErrorKind.missingRate => l10n.errorNoRate(
      error.currencyCode ?? '—',
    ),
    RowCalculationErrorKind.overflow => l10n.resultTooLarge,
  };
}

String localizePersistenceMessage(AppLocalizations l10n, String message) {
  return switch (message) {
    'Local preferences could not be loaded.' => l10n.preferencesLoadError,
    'Favorites could not be loaded.' => l10n.favoritesLoadError,
    'Preferences could not be saved locally.' => l10n.preferencesSaveError,
    'Favorites could not be saved locally.' => l10n.favoritesSaveError,
    'Cached rates could not be loaded.' => l10n.cachedRatesLoadError,
    'Could not update rates. Existing data was kept.' => l10n.ratesUpdateError,
    'Calculation history could not be loaded.' => l10n.historyLoadError,
    'Calculation history could not be saved locally.' => l10n.historySaveError,
    _ => message,
  };
}
