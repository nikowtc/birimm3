import '../models/currency.dart';
import '../models/currency_catalog.dart';
import '../providers/calculator_controller.dart';

/// The currency and USD conversion currently used to present market prices.
///
/// CoinGecko quotes are always in USD. When the calculator's output currency
/// has a usable USD rate we show prices in that currency; otherwise we show the
/// raw USD quote and say so instead of inventing a conversion.
class MarketPriceView {
  const MarketPriceView({required this.currency, required this.usdToDisplay});

  final Currency currency;
  final double? usdToDisplay;

  bool get isUsdFallback => currency.code == 'USD' && usdToDisplay == null;

  double priceFor(double usdPrice) => usdPrice * (usdToDisplay ?? 1);
}

MarketPriceView marketPriceView(CalculatorController controller) {
  final output = controller.outputCurrency;
  if (output.code == 'USD') {
    return MarketPriceView(currency: output, usdToDisplay: 1);
  }
  final rate = controller.conversionRate('USD', output.code);
  if (rate == null || !rate.isFinite || rate <= 0) {
    return MarketPriceView(
      currency: CurrencyCatalog.fiatCurrency('USD'),
      usdToDisplay: null,
    );
  }
  return MarketPriceView(currency: output, usdToDisplay: rate);
}
