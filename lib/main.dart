import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/calculator_controller.dart';
import 'providers/markets_controller.dart';
import 'services/app_storage.dart';
import 'services/crypto_rate_service.dart';
import 'services/equity_market_service.dart';
import 'services/exchange_rate_repository.dart';
import 'services/fiat_rate_service.dart';
import 'services/market_service.dart';
import 'services/metal_market_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final storage = AppStorage(SharedPreferencesStore(preferences));
  final client = http.Client();
  final controller = CalculatorController(
    ratesRepository: ExchangeRateRepository(
      fiatService: OpenErApiFiatRateService(client: client),
      cryptoService: CoinGeckoCryptoRateService(client: client),
      storage: storage,
    ),
    storage: storage,
    autoRefreshInterval: const Duration(hours: 1),
  );
  final marketsController = MarketsController(
    service: CoinGeckoMarketDataService(client: client),
    equityService: YahooFinanceMarketService(
      client: client,
      fiatUnitsPerUsd: () =>
          controller.rateBundle?.fiatUnitsPerUsd ?? const {},
    ),
    metalService: GoldApiMetalMarketService(client: client),
    storage: storage,
    autoRefreshInterval: const Duration(minutes: 5),
  );

  runApp(
    CurrencyCalculatorApp(
      controller: controller,
      marketsController: marketsController,
    ),
  );
}
