/// Single source of truth for user-visible product and developer identity.
class AppInfo {
  const AppInfo._();

  static const String appName = 'Birimm';
  static const String tagline = 'Add up the world in one clear total.';
  static const String version = '1.1.0';
  static const String developer = 'nicatdev';
  static const String projectUrl = 'https://github.com/nicatdev/birimm';
  static const String developerUrl = 'https://github.com/nicatdev';
  static const String licenseNotice = 'Source-available · All rights reserved';

  static const List<(String label, String url)> dataSources = [
    ('ExchangeRate-API', 'https://www.exchangerate-api.com'),
    ('CoinGecko', 'https://www.coingecko.com'),
    ('Yahoo Finance', 'https://finance.yahoo.com'),
    ('Gold API', 'https://www.gold-api.com'),
  ];
}
