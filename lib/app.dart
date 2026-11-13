import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_info.dart';
import 'l10n/app_localizations.dart';
import 'models/app_preferences.dart';
import 'providers/calculator_controller.dart';
import 'providers/markets_controller.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class CurrencyCalculatorApp extends StatelessWidget {
  const CurrencyCalculatorApp({
    super.key,
    required this.controller,
    required this.marketsController,
  });

  final CalculatorController controller;
  final MarketsController marketsController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CalculatorController>.value(value: controller),
        ChangeNotifierProvider<MarketsController>.value(
          value: marketsController,
        ),
      ],
      child: Selector<CalculatorController, (AppThemePreference, AppLanguage)>(
        selector: (_, state) => (state.theme, state.language),
        builder: (context, settings, _) {
          final (preference, language) = settings;
          return MaterialApp(
            title: AppInfo.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: switch (preference) {
              AppThemePreference.dark => ThemeMode.dark,
              AppThemePreference.light => ThemeMode.light,
              AppThemePreference.system => ThemeMode.system,
            },
            locale: language.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
