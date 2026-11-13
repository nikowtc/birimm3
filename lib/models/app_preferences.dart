import 'package:flutter/widgets.dart';

enum AppThemePreference { dark, light, system }

enum AppLanguage { en, tr, ru, es, fr, zh, ja, ptBr }

extension AppThemePreferenceStorage on AppThemePreference {
  String get storageValue => name;

  static AppThemePreference parse(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => AppThemePreference.dark,
    );
  }
}

extension AppLanguageInfo on AppLanguage {
  String get storageValue => switch (this) {
    AppLanguage.ptBr => 'pt-BR',
    _ => name,
  };

  String get languageCode => switch (this) {
    AppLanguage.ptBr => 'pt',
    _ => name,
  };

  String? get countryCode => this == AppLanguage.ptBr ? 'BR' : null;

  Locale get locale => Locale(languageCode, countryCode);

  static AppLanguage parse(String? value) {
    if (value == null) return AppLanguage.en;
    final normalized = value.trim().toLowerCase().replaceAll('_', '-');
    final primary = normalized.split('-').first;
    return AppLanguage.values.firstWhere(
      (language) =>
          language.storageValue.toLowerCase() == normalized ||
          language.name.toLowerCase() == normalized ||
          language.languageCode == primary,
      orElse: () => AppLanguage.en,
    );
  }
}

class AppPreferences {
  const AppPreferences({
    this.theme = AppThemePreference.dark,
    this.language = AppLanguage.en,
    this.outputCurrencyCode = 'EUR',
  });

  final AppThemePreference theme;
  final AppLanguage language;
  final String outputCurrencyCode;

  Map<String, Object?> toJson() => {
    'theme': theme.storageValue,
    'language': language.storageValue,
    'outputCurrency': outputCurrencyCode,
  };

  static AppPreferences fromJson(Object? value) {
    if (value is! Map) return const AppPreferences();
    final json = Map<String, Object?>.from(value);
    // `targetCurrency` is the version-1 key. Keep reading it so existing
    // installs retain their preferred output currency.
    final rawOutput = json['outputCurrency'] ?? json['targetCurrency'];
    final output = rawOutput is String ? rawOutput.trim().toUpperCase() : 'EUR';
    return AppPreferences(
      theme: AppThemePreferenceStorage.parse(json['theme'] as String?),
      language: AppLanguageInfo.parse(json['language'] as String?),
      outputCurrencyCode: output.isEmpty ? 'EUR' : output,
    );
  }
}
