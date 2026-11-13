import 'currency.dart';

class _FiatMeta {
  const _FiatMeta(this.name, this.symbol);

  final String name;
  final String symbol;
}

/// Static display metadata plus provider identifiers for every asset.
///
/// Exchange rates and prices themselves are never defined here. Only names,
/// symbols, search aliases and provider identifiers live in this catalog.
abstract final class CurrencyCatalog {
  static const List<Currency> cryptoCurrencies = [
    Currency(
      code: 'BTC',
      name: 'Bitcoin',
      symbol: '₿',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'bitcoin',
    ),
    Currency(
      code: 'ETH',
      name: 'Ethereum',
      symbol: 'Ξ',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'ethereum',
    ),
    Currency(
      code: 'BNB',
      name: 'BNB',
      symbol: 'BNB',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'binancecoin',
    ),
    Currency(
      code: 'SOL',
      name: 'Solana',
      symbol: 'SOL',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'solana',
    ),
    Currency(
      code: 'XRP',
      name: 'XRP',
      symbol: 'XRP',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'ripple',
    ),
    Currency(
      code: 'ADA',
      name: 'Cardano',
      symbol: 'ADA',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'cardano',
    ),
    Currency(
      code: 'DOGE',
      name: 'Dogecoin',
      symbol: 'Ð',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'dogecoin',
    ),
    Currency(
      code: 'TRX',
      name: 'TRON',
      symbol: 'TRX',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'tron',
    ),
    Currency(
      code: 'USDT',
      name: 'Tether',
      symbol: '₮',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'tether',
    ),
    Currency(
      code: 'USDC',
      name: 'USD Coin',
      symbol: r'$',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'usd-coin',
    ),
    Currency(
      code: 'LINK',
      name: 'Chainlink',
      symbol: 'LINK',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'chainlink',
    ),
    Currency(
      code: 'AVAX',
      name: 'Avalanche',
      symbol: 'AVAX',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'avalanche-2',
    ),
    Currency(
      code: 'DOT',
      name: 'Polkadot',
      symbol: 'DOT',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'polkadot',
    ),
    Currency(
      code: 'LTC',
      name: 'Litecoin',
      symbol: 'Ł',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'litecoin',
    ),
    Currency(
      code: 'BCH',
      name: 'Bitcoin Cash',
      symbol: 'BCH',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'bitcoin-cash',
    ),
    Currency(
      code: 'XLM',
      name: 'Stellar',
      symbol: 'XLM',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'stellar',
    ),
    Currency(
      code: 'TON',
      name: 'Toncoin',
      symbol: 'TON',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'the-open-network',
    ),
    Currency(
      code: 'SHIB',
      name: 'Shiba Inu',
      symbol: 'SHIB',
      kind: CurrencyKind.crypto,
      coinGeckoId: 'shiba-inu',
    ),
  ];

  static const List<Currency> stockCurrencies = [
    // Major international companies, quoted in USD.
    Currency(code: 'AAPL', name: 'Apple', symbol: 'AAPL', kind: CurrencyKind.stock, yahooSymbol: 'AAPL', aliases: ['apple', 'iphone']),
    Currency(code: 'MSFT', name: 'Microsoft', symbol: 'MSFT', kind: CurrencyKind.stock, yahooSymbol: 'MSFT', aliases: ['microsoft']),
    Currency(code: 'GOOGL', name: 'Alphabet', symbol: 'GOOGL', kind: CurrencyKind.stock, yahooSymbol: 'GOOGL', aliases: ['google', 'alphabet']),
    Currency(code: 'AMZN', name: 'Amazon', symbol: 'AMZN', kind: CurrencyKind.stock, yahooSymbol: 'AMZN', aliases: ['amazon']),
    Currency(code: 'NVDA', name: 'NVIDIA', symbol: 'NVDA', kind: CurrencyKind.stock, yahooSymbol: 'NVDA', aliases: ['nvidia']),
    Currency(code: 'META', name: 'Meta Platforms', symbol: 'META', kind: CurrencyKind.stock, yahooSymbol: 'META', aliases: ['facebook', 'meta']),
    Currency(code: 'TSLA', name: 'Tesla', symbol: 'TSLA', kind: CurrencyKind.stock, yahooSymbol: 'TSLA', aliases: ['tesla']),
    Currency(code: 'BRK-B', name: 'Berkshire Hathaway', symbol: 'BRK.B', kind: CurrencyKind.stock, yahooSymbol: 'BRK-B', aliases: ['berkshire']),
    Currency(code: 'JPM', name: 'JPMorgan Chase', symbol: 'JPM', kind: CurrencyKind.stock, yahooSymbol: 'JPM', aliases: ['jpmorgan']),
    Currency(code: 'V', name: 'Visa', symbol: 'V', kind: CurrencyKind.stock, yahooSymbol: 'V', aliases: ['visa']),
    Currency(code: 'JNJ', name: 'Johnson & Johnson', symbol: 'JNJ', kind: CurrencyKind.stock, yahooSymbol: 'JNJ', aliases: ['johnson']),
    Currency(code: 'WMT', name: 'Walmart', symbol: 'WMT', kind: CurrencyKind.stock, yahooSymbol: 'WMT', aliases: ['walmart']),
    Currency(code: 'XOM', name: 'Exxon Mobil', symbol: 'XOM', kind: CurrencyKind.stock, yahooSymbol: 'XOM', aliases: ['exxon']),
    Currency(code: 'UNH', name: 'UnitedHealth', symbol: 'UNH', kind: CurrencyKind.stock, yahooSymbol: 'UNH', aliases: ['unitedhealth']),
    Currency(code: 'MA', name: 'Mastercard', symbol: 'MA', kind: CurrencyKind.stock, yahooSymbol: 'MA', aliases: ['mastercard']),
    Currency(code: 'PG', name: 'Procter & Gamble', symbol: 'PG', kind: CurrencyKind.stock, yahooSymbol: 'PG', aliases: ['procter', 'gamble']),
    Currency(code: 'HD', name: 'Home Depot', symbol: 'HD', kind: CurrencyKind.stock, yahooSymbol: 'HD', aliases: ['home depot']),
    Currency(code: 'COST', name: 'Costco', symbol: 'COST', kind: CurrencyKind.stock, yahooSymbol: 'COST', aliases: ['costco']),
    Currency(code: 'NFLX', name: 'Netflix', symbol: 'NFLX', kind: CurrencyKind.stock, yahooSymbol: 'NFLX', aliases: ['netflix']),
    Currency(code: 'AMD', name: 'AMD', symbol: 'AMD', kind: CurrencyKind.stock, yahooSymbol: 'AMD', aliases: ['advanced micro devices']),
    Currency(code: 'INTC', name: 'Intel', symbol: 'INTC', kind: CurrencyKind.stock, yahooSymbol: 'INTC', aliases: ['intel']),
    Currency(code: 'DIS', name: 'Walt Disney', symbol: 'DIS', kind: CurrencyKind.stock, yahooSymbol: 'DIS', aliases: ['disney']),
    Currency(code: 'KO', name: 'Coca-Cola', symbol: 'KO', kind: CurrencyKind.stock, yahooSymbol: 'KO', aliases: ['coca cola']),
    Currency(code: 'PEP', name: 'PepsiCo', symbol: 'PEP', kind: CurrencyKind.stock, yahooSymbol: 'PEP', aliases: ['pepsi']),
    Currency(code: 'ADBE', name: 'Adobe', symbol: 'ADBE', kind: CurrencyKind.stock, yahooSymbol: 'ADBE', aliases: ['adobe']),
    Currency(code: 'CRM', name: 'Salesforce', symbol: 'CRM', kind: CurrencyKind.stock, yahooSymbol: 'CRM', aliases: ['salesforce']),
    Currency(code: 'ORCL', name: 'Oracle', symbol: 'ORCL', kind: CurrencyKind.stock, yahooSymbol: 'ORCL', aliases: ['oracle']),
    Currency(code: 'CSCO', name: 'Cisco', symbol: 'CSCO', kind: CurrencyKind.stock, yahooSymbol: 'CSCO', aliases: ['cisco']),
    Currency(code: 'QCOM', name: 'Qualcomm', symbol: 'QCOM', kind: CurrencyKind.stock, yahooSymbol: 'QCOM', aliases: ['qualcomm']),
    Currency(code: 'AVGO', name: 'Broadcom', symbol: 'AVGO', kind: CurrencyKind.stock, yahooSymbol: 'AVGO', aliases: ['broadcom']),
    Currency(code: 'TSM', name: 'TSMC', symbol: 'TSM', kind: CurrencyKind.stock, yahooSymbol: 'TSM', aliases: ['taiwan semiconductor']),
    Currency(code: 'BABA', name: 'Alibaba', symbol: 'BABA', kind: CurrencyKind.stock, yahooSymbol: 'BABA', aliases: ['alibaba']),
    Currency(code: 'NKE', name: 'Nike', symbol: 'NKE', kind: CurrencyKind.stock, yahooSymbol: 'NKE', aliases: ['nike']),
    Currency(code: 'MCD', name: "McDonald's", symbol: 'MCD', kind: CurrencyKind.stock, yahooSymbol: 'MCD', aliases: ['mcdonalds']),
    Currency(code: 'BA', name: 'Boeing', symbol: 'BA', kind: CurrencyKind.stock, yahooSymbol: 'BA', aliases: ['boeing']),
    Currency(code: 'CAT', name: 'Caterpillar', symbol: 'CAT', kind: CurrencyKind.stock, yahooSymbol: 'CAT', aliases: ['caterpillar']),
    Currency(code: 'GE', name: 'GE Aerospace', symbol: 'GE', kind: CurrencyKind.stock, yahooSymbol: 'GE', aliases: ['general electric']),
    Currency(code: 'IBM', name: 'IBM', symbol: 'IBM', kind: CurrencyKind.stock, yahooSymbol: 'IBM', aliases: ['ibm']),
    Currency(code: 'UBER', name: 'Uber', symbol: 'UBER', kind: CurrencyKind.stock, yahooSymbol: 'UBER', aliases: ['uber']),
    Currency(code: 'PYPL', name: 'PayPal', symbol: 'PYPL', kind: CurrencyKind.stock, yahooSymbol: 'PYPL', aliases: ['paypal']),
    Currency(code: 'SHOP', name: 'Shopify', symbol: 'SHOP', kind: CurrencyKind.stock, yahooSymbol: 'SHOP', aliases: ['shopify']),
    Currency(code: 'SONY', name: 'Sony', symbol: 'SONY', kind: CurrencyKind.stock, yahooSymbol: 'SONY', aliases: ['sony']),
    Currency(code: 'TM', name: 'Toyota', symbol: 'TM', kind: CurrencyKind.stock, yahooSymbol: 'TM', aliases: ['toyota']),
    Currency(code: 'SAP', name: 'SAP', symbol: 'SAP', kind: CurrencyKind.stock, yahooSymbol: 'SAP', aliases: ['sap']),
    Currency(code: 'NVO', name: 'Novo Nordisk', symbol: 'NVO', kind: CurrencyKind.stock, yahooSymbol: 'NVO', aliases: ['novo nordisk']),
    Currency(code: 'ASML', name: 'ASML', symbol: 'ASML', kind: CurrencyKind.stock, yahooSymbol: 'ASML', aliases: ['asml']),
    Currency(code: 'SHEL', name: 'Shell', symbol: 'SHEL', kind: CurrencyKind.stock, yahooSymbol: 'SHEL', aliases: ['shell']),
    Currency(code: 'BP', name: 'BP', symbol: 'BP', kind: CurrencyKind.stock, yahooSymbol: 'BP', aliases: ['british petroleum']),
    Currency(code: 'UL', name: 'Unilever', symbol: 'UL', kind: CurrencyKind.stock, yahooSymbol: 'UL', aliases: ['unilever']),
    Currency(code: 'HSBC', name: 'HSBC', symbol: 'HSBC', kind: CurrencyKind.stock, yahooSymbol: 'HSBC', aliases: ['hsbc']),
    Currency(code: 'TTE', name: 'TotalEnergies', symbol: 'TTE', kind: CurrencyKind.stock, yahooSymbol: 'TTE', aliases: ['total', 'totalenergies']),
    Currency(code: 'SNY', name: 'Sanofi', symbol: 'SNY', kind: CurrencyKind.stock, yahooSymbol: 'SNY', aliases: ['sanofi']),
    Currency(code: 'DEO', name: 'Diageo', symbol: 'DEO', kind: CurrencyKind.stock, yahooSymbol: 'DEO', aliases: ['diageo']),
    Currency(code: 'RIO', name: 'Rio Tinto', symbol: 'RIO', kind: CurrencyKind.stock, yahooSymbol: 'RIO', aliases: ['rio tinto']),
    Currency(code: 'BHP', name: 'BHP', symbol: 'BHP', kind: CurrencyKind.stock, yahooSymbol: 'BHP', aliases: ['bhp']),
    Currency(code: 'VALE', name: 'Vale', symbol: 'VALE', kind: CurrencyKind.stock, yahooSymbol: 'VALE', aliases: ['vale']),
    Currency(code: 'PBR', name: 'Petrobras', symbol: 'PBR', kind: CurrencyKind.stock, yahooSymbol: 'PBR', aliases: ['petrobras']),
    Currency(code: 'INFY', name: 'Infosys', symbol: 'INFY', kind: CurrencyKind.stock, yahooSymbol: 'INFY', aliases: ['infosys']),
    Currency(code: 'HDB', name: 'HDFC Bank', symbol: 'HDB', kind: CurrencyKind.stock, yahooSymbol: 'HDB', aliases: ['hdfc']),
    Currency(code: 'IBN', name: 'ICICI Bank', symbol: 'IBN', kind: CurrencyKind.stock, yahooSymbol: 'IBN', aliases: ['icici']),
    // Borsa İstanbul, quoted in TRY and normalized to USD by the service.
    Currency(code: 'THYAO', name: 'Türk Hava Yolları', symbol: 'THYAO', kind: CurrencyKind.stock, yahooSymbol: 'THYAO.IS', quoteCurrency: 'TRY', aliases: ['turkish airlines', 'thy', 'türk hava yolları']),
    Currency(code: 'ASELS', name: 'Aselsan', symbol: 'ASELS', kind: CurrencyKind.stock, yahooSymbol: 'ASELS.IS', quoteCurrency: 'TRY', aliases: ['aselsan']),
    Currency(code: 'BIMAS', name: 'BİM', symbol: 'BIMAS', kind: CurrencyKind.stock, yahooSymbol: 'BIMAS.IS', quoteCurrency: 'TRY', aliases: ['bim', 'bimas']),
    Currency(code: 'KCHOL', name: 'Koç Holding', symbol: 'KCHOL', kind: CurrencyKind.stock, yahooSymbol: 'KCHOL.IS', quoteCurrency: 'TRY', aliases: ['koc holding', 'koç']),
    Currency(code: 'SAHOL', name: 'Sabancı Holding', symbol: 'SAHOL', kind: CurrencyKind.stock, yahooSymbol: 'SAHOL.IS', quoteCurrency: 'TRY', aliases: ['sabanci', 'sabancı']),
    Currency(code: 'TUPRS', name: 'Tüpraş', symbol: 'TUPRS', kind: CurrencyKind.stock, yahooSymbol: 'TUPRS.IS', quoteCurrency: 'TRY', aliases: ['tupras', 'tüpraş']),
    Currency(code: 'EREGL', name: 'Ereğli Demir Çelik', symbol: 'EREGL', kind: CurrencyKind.stock, yahooSymbol: 'EREGL.IS', quoteCurrency: 'TRY', aliases: ['eregli', 'erdemir']),
    Currency(code: 'SISE', name: 'Şişecam', symbol: 'SISE', kind: CurrencyKind.stock, yahooSymbol: 'SISE.IS', quoteCurrency: 'TRY', aliases: ['sisecam', 'şişecam']),
    Currency(code: 'GARAN', name: 'Garanti BBVA', symbol: 'GARAN', kind: CurrencyKind.stock, yahooSymbol: 'GARAN.IS', quoteCurrency: 'TRY', aliases: ['garanti']),
    Currency(code: 'AKBNK', name: 'Akbank', symbol: 'AKBNK', kind: CurrencyKind.stock, yahooSymbol: 'AKBNK.IS', quoteCurrency: 'TRY', aliases: ['akbank']),
    Currency(code: 'ISCTR', name: 'Türkiye İş Bankası', symbol: 'ISCTR', kind: CurrencyKind.stock, yahooSymbol: 'ISCTR.IS', quoteCurrency: 'TRY', aliases: ['is bankasi', 'iş bankası']),
    Currency(code: 'YKBNK', name: 'Yapı Kredi', symbol: 'YKBNK', kind: CurrencyKind.stock, yahooSymbol: 'YKBNK.IS', quoteCurrency: 'TRY', aliases: ['yapi kredi', 'yapı kredi']),
    Currency(code: 'HALKB', name: 'Halkbank', symbol: 'HALKB', kind: CurrencyKind.stock, yahooSymbol: 'HALKB.IS', quoteCurrency: 'TRY', aliases: ['halkbank']),
    Currency(code: 'VAKBN', name: 'Vakıfbank', symbol: 'VAKBN', kind: CurrencyKind.stock, yahooSymbol: 'VAKBN.IS', quoteCurrency: 'TRY', aliases: ['vakifbank', 'vakıfbank']),
    Currency(code: 'TCELL', name: 'Turkcell', symbol: 'TCELL', kind: CurrencyKind.stock, yahooSymbol: 'TCELL.IS', quoteCurrency: 'TRY', aliases: ['turkcell']),
    Currency(code: 'TTKOM', name: 'Türk Telekom', symbol: 'TTKOM', kind: CurrencyKind.stock, yahooSymbol: 'TTKOM.IS', quoteCurrency: 'TRY', aliases: ['turk telekom']),
    Currency(code: 'TOASO', name: 'Tofaş', symbol: 'TOASO', kind: CurrencyKind.stock, yahooSymbol: 'TOASO.IS', quoteCurrency: 'TRY', aliases: ['tofas', 'tofaş']),
    Currency(code: 'FROTO', name: 'Ford Otosan', symbol: 'FROTO', kind: CurrencyKind.stock, yahooSymbol: 'FROTO.IS', quoteCurrency: 'TRY', aliases: ['ford otosan']),
    Currency(code: 'ARCLK', name: 'Arçelik', symbol: 'ARCLK', kind: CurrencyKind.stock, yahooSymbol: 'ARCLK.IS', quoteCurrency: 'TRY', aliases: ['arcelik', 'arçelik']),
    Currency(code: 'ULKER', name: 'Ülker', symbol: 'ULKER', kind: CurrencyKind.stock, yahooSymbol: 'ULKER.IS', quoteCurrency: 'TRY', aliases: ['ulker', 'ülker']),
    Currency(code: 'PETKM', name: 'Petkim', symbol: 'PETKM', kind: CurrencyKind.stock, yahooSymbol: 'PETKM.IS', quoteCurrency: 'TRY', aliases: ['petkim']),
    Currency(code: 'PGSUS', name: 'Pegasus', symbol: 'PGSUS', kind: CurrencyKind.stock, yahooSymbol: 'PGSUS.IS', quoteCurrency: 'TRY', aliases: ['pegasus']),
    Currency(code: 'TAVHL', name: 'TAV Havalimanları', symbol: 'TAVHL', kind: CurrencyKind.stock, yahooSymbol: 'TAVHL.IS', quoteCurrency: 'TRY', aliases: ['tav']),
    Currency(code: 'ENKAI', name: 'Enka İnşaat', symbol: 'ENKAI', kind: CurrencyKind.stock, yahooSymbol: 'ENKAI.IS', quoteCurrency: 'TRY', aliases: ['enka']),
    Currency(code: 'MGROS', name: 'Migros', symbol: 'MGROS', kind: CurrencyKind.stock, yahooSymbol: 'MGROS.IS', quoteCurrency: 'TRY', aliases: ['migros']),
    Currency(code: 'AEFES', name: 'Anadolu Efes', symbol: 'AEFES', kind: CurrencyKind.stock, yahooSymbol: 'AEFES.IS', quoteCurrency: 'TRY', aliases: ['anadolu efes']),
    Currency(code: 'KOZAL', name: 'Koza Altın', symbol: 'KOZAL', kind: CurrencyKind.stock, yahooSymbol: 'KOZAL.IS', quoteCurrency: 'TRY', aliases: ['koza altin']),
    Currency(code: 'HEKTS', name: 'Hektaş', symbol: 'HEKTS', kind: CurrencyKind.stock, yahooSymbol: 'HEKTS.IS', quoteCurrency: 'TRY', aliases: ['hektas', 'hektaş']),
    Currency(code: 'OYAKC', name: 'OYAK Çimento', symbol: 'OYAKC', kind: CurrencyKind.stock, yahooSymbol: 'OYAKC.IS', quoteCurrency: 'TRY', aliases: ['oyak']),
    Currency(code: 'SASA', name: 'Sasa Polyester', symbol: 'SASA', kind: CurrencyKind.stock, yahooSymbol: 'SASA.IS', quoteCurrency: 'TRY', aliases: ['sasa']),
    Currency(code: 'GUBRF', name: 'Gübre Fabrikaları', symbol: 'GUBRF', kind: CurrencyKind.stock, yahooSymbol: 'GUBRF.IS', quoteCurrency: 'TRY', aliases: ['gubre', 'gübre']),
    Currency(code: 'DOAS', name: 'Doğuş Otomotiv', symbol: 'DOAS', kind: CurrencyKind.stock, yahooSymbol: 'DOAS.IS', quoteCurrency: 'TRY', aliases: ['dogus otomotiv']),
    Currency(code: 'OTKAR', name: 'Otokar', symbol: 'OTKAR', kind: CurrencyKind.stock, yahooSymbol: 'OTKAR.IS', quoteCurrency: 'TRY', aliases: ['otokar']),
    Currency(code: 'TKFEN', name: 'Tekfen Holding', symbol: 'TKFEN', kind: CurrencyKind.stock, yahooSymbol: 'TKFEN.IS', quoteCurrency: 'TRY', aliases: ['tekfen']),
    Currency(code: 'ZOREN', name: 'Zorlu Enerji', symbol: 'ZOREN', kind: CurrencyKind.stock, yahooSymbol: 'ZOREN.IS', quoteCurrency: 'TRY', aliases: ['zorlu']),
    Currency(code: 'CCOLA', name: 'Coca-Cola İçecek', symbol: 'CCOLA', kind: CurrencyKind.stock, yahooSymbol: 'CCOLA.IS', quoteCurrency: 'TRY', aliases: ['coca cola icecek']),
  ];

  static const List<Currency> indexCurrencies = [
    Currency(code: 'SPX', name: 'S&P 500', symbol: 'SPX', kind: CurrencyKind.marketIndex, yahooSymbol: '^GSPC', aliases: ['s&p', 'sp500', 's&p 500']),
    Currency(code: 'NDX', name: 'NASDAQ 100', symbol: 'NDX', kind: CurrencyKind.marketIndex, yahooSymbol: '^NDX', aliases: ['nasdaq 100', 'nasdaq']),
    Currency(code: 'IXIC', name: 'NASDAQ Composite', symbol: 'IXIC', kind: CurrencyKind.marketIndex, yahooSymbol: '^IXIC', aliases: ['nasdaq composite', 'nasdaq']),
    Currency(code: 'DJI', name: 'Dow Jones', symbol: 'DJI', kind: CurrencyKind.marketIndex, yahooSymbol: '^DJI', aliases: ['dow', 'dow jones']),
    Currency(code: 'DAX', name: 'DAX', symbol: 'DAX', kind: CurrencyKind.marketIndex, yahooSymbol: '^GDAXI', quoteCurrency: 'EUR', aliases: ['german index']),
    Currency(code: 'FTSE', name: 'FTSE 100', symbol: 'FTSE', kind: CurrencyKind.marketIndex, yahooSymbol: '^FTSE', quoteCurrency: 'GBP', aliases: ['ftse']),
    Currency(code: 'N225', name: 'Nikkei 225', symbol: 'N225', kind: CurrencyKind.marketIndex, yahooSymbol: '^N225', quoteCurrency: 'JPY', aliases: ['nikkei']),
    Currency(code: 'HSI', name: 'Hang Seng', symbol: 'HSI', kind: CurrencyKind.marketIndex, yahooSymbol: '^HSI', quoteCurrency: 'HKD', aliases: ['hang seng']),
    Currency(code: 'SX5E', name: 'Euro Stoxx 50', symbol: 'SX5E', kind: CurrencyKind.marketIndex, yahooSymbol: '^STOXX50E', quoteCurrency: 'EUR', aliases: ['stoxx', 'euro stoxx']),
    Currency(code: 'BIST100', name: 'BIST 100', symbol: 'BIST100', kind: CurrencyKind.marketIndex, yahooSymbol: 'XU100.IS', quoteCurrency: 'TRY', aliases: ['bist', 'bist 100', 'borsa istanbul']),
  ];

  static const List<Currency> metalCurrencies = [
    Currency(code: 'XAU_G', name: 'Gold (gram)', symbol: 'g', kind: CurrencyKind.metal, quoteCurrency: 'USD', aliases: ['gold', 'gram gold', 'gold gram', 'altin', 'gram altin', 'altın', 'gram altın', 'золото', '金', 'ゴールド', 'ouro']),
    Currency(code: 'XAG_G', name: 'Silver (gram)', symbol: 'g', kind: CurrencyKind.metal, quoteCurrency: 'USD', aliases: ['silver', 'gram silver', 'silver gram', 'gumus', 'gram gumus', 'gümüş', 'gram gümüş', 'серебро', '银', 'シルバー', 'prata']),
    Currency(code: 'XAU', name: 'Gold (ounce)', symbol: 'oz', kind: CurrencyKind.metal, quoteCurrency: 'USD', aliases: ['gold ounce', 'altin ons', 'altın ons', 'унция золота', '金衡盎司', 'ゴールドオンス', 'onça de ouro']),
    Currency(code: 'XAG', name: 'Silver (ounce)', symbol: 'oz', kind: CurrencyKind.metal, quoteCurrency: 'USD', aliases: ['silver ounce', 'gumus ons', 'gümüş ons', 'унция серебра', 'シルバーオンス', 'onça de prata']),
  ];

  static const Map<String, _FiatMeta> _fiatMeta = {
    'USD': _FiatMeta('United States Dollar', r'$'),
    'EUR': _FiatMeta('Euro', '€'),
    'GBP': _FiatMeta('British Pound', '£'),
    'TRY': _FiatMeta('Turkish Lira', '₺'),
    'AZN': _FiatMeta('Azerbaijani Manat', '₼'),
    'JPY': _FiatMeta('Japanese Yen', '¥'),
    'CHF': _FiatMeta('Swiss Franc', 'CHF'),
    'CAD': _FiatMeta('Canadian Dollar', r'C$'),
    'AUD': _FiatMeta('Australian Dollar', r'A$'),
    'CNY': _FiatMeta('Chinese Yuan', '¥'),
    'CNH': _FiatMeta('Offshore Chinese Yuan', '¥'),
    'INR': _FiatMeta('Indian Rupee', '₹'),
    'RUB': _FiatMeta('Russian Ruble', '₽'),
    'AED': _FiatMeta('UAE Dirham', 'د.إ'),
    'SAR': _FiatMeta('Saudi Riyal', '﷼'),
    'QAR': _FiatMeta('Qatari Riyal', '﷼'),
    'KWD': _FiatMeta('Kuwaiti Dinar', 'د.ك'),
    'BHD': _FiatMeta('Bahraini Dinar', 'د.ب'),
    'OMR': _FiatMeta('Omani Rial', '﷼'),
    'JOD': _FiatMeta('Jordanian Dinar', 'د.ا'),
    'KZT': _FiatMeta('Kazakhstani Tenge', '₸'),
    'GEL': _FiatMeta('Georgian Lari', '₾'),
    'UAH': _FiatMeta('Ukrainian Hryvnia', '₴'),
    'PLN': _FiatMeta('Polish Zloty', 'zł'),
    'SEK': _FiatMeta('Swedish Krona', 'kr'),
    'NOK': _FiatMeta('Norwegian Krone', 'kr'),
    'DKK': _FiatMeta('Danish Krone', 'kr'),
    'ISK': _FiatMeta('Icelandic Krona', 'kr'),
    'CZK': _FiatMeta('Czech Koruna', 'Kč'),
    'HUF': _FiatMeta('Hungarian Forint', 'Ft'),
    'RON': _FiatMeta('Romanian Leu', 'lei'),
    'BGN': _FiatMeta('Bulgarian Lev', 'лв'),
    'RSD': _FiatMeta('Serbian Dinar', 'дин'),
    'MXN': _FiatMeta('Mexican Peso', r'$'),
    'BRL': _FiatMeta('Brazilian Real', r'R$'),
    'ZAR': _FiatMeta('South African Rand', 'R'),
    'KRW': _FiatMeta('South Korean Won', '₩'),
    'SGD': _FiatMeta('Singapore Dollar', r'S$'),
    'HKD': _FiatMeta('Hong Kong Dollar', r'HK$'),
    'NZD': _FiatMeta('New Zealand Dollar', r'NZ$'),
    'THB': _FiatMeta('Thai Baht', '฿'),
    'IDR': _FiatMeta('Indonesian Rupiah', 'Rp'),
    'MYR': _FiatMeta('Malaysian Ringgit', 'RM'),
    'PHP': _FiatMeta('Philippine Peso', '₱'),
    'VND': _FiatMeta('Vietnamese Dong', '₫'),
    'EGP': _FiatMeta('Egyptian Pound', 'E£'),
    'ILS': _FiatMeta('Israeli New Shekel', '₪'),
    'PKR': _FiatMeta('Pakistani Rupee', '₨'),
    'BDT': _FiatMeta('Bangladeshi Taka', '৳'),
    'LKR': _FiatMeta('Sri Lankan Rupee', 'Rs'),
    'NPR': _FiatMeta('Nepalese Rupee', 'Rs'),
    'ARS': _FiatMeta('Argentine Peso', r'$'),
    'CLP': _FiatMeta('Chilean Peso', r'$'),
    'COP': _FiatMeta('Colombian Peso', r'$'),
    'PEN': _FiatMeta('Peruvian Sol', 'S/'),
    'UYU': _FiatMeta('Uruguayan Peso', r'$U'),
    'DOP': _FiatMeta('Dominican Peso', r'RD$'),
    'TWD': _FiatMeta('New Taiwan Dollar', r'NT$'),
    'MAD': _FiatMeta('Moroccan Dirham', 'د.م.'),
    'TND': _FiatMeta('Tunisian Dinar', 'د.ت'),
    'NGN': _FiatMeta('Nigerian Naira', '₦'),
    'KES': _FiatMeta('Kenyan Shilling', 'KSh'),
    'GHS': _FiatMeta('Ghanaian Cedi', '₵'),
    'AFN': _FiatMeta('Afghan Afghani', '؋'),
    'AMD': _FiatMeta('Armenian Dram', '֏'),
    'BAM': _FiatMeta('Bosnian Convertible Mark', 'KM'),
    'BYN': _FiatMeta('Belarusian Ruble', 'Br'),
    'CRC': _FiatMeta('Costa Rican Colón', '₡'),
    'DZD': _FiatMeta('Algerian Dinar', 'د.ج'),
    'ETB': _FiatMeta('Ethiopian Birr', 'Br'),
    'GNF': _FiatMeta('Guinean Franc', 'FG'),
    'GTQ': _FiatMeta('Guatemalan Quetzal', 'Q'),
    'HNL': _FiatMeta('Honduran Lempira', 'L'),
    'JMD': _FiatMeta('Jamaican Dollar', r'$'),
    'KGS': _FiatMeta('Kyrgyzstani Som', 'с'),
    'KHR': _FiatMeta('Cambodian Riel', '៛'),
    'MNT': _FiatMeta('Mongolian Tugrik', '₮'),
    'MUR': _FiatMeta('Mauritian Rupee', '₨'),
    'MZN': _FiatMeta('Mozambican Metical', 'MT'),
    'NAD': _FiatMeta('Namibian Dollar', r'$'),
    'NIO': _FiatMeta('Nicaraguan Córdoba', r'C$'),
    'PAB': _FiatMeta('Panamanian Balboa', 'B/.'),
    'PYG': _FiatMeta('Paraguayan Guarani', '₲'),
    'RWF': _FiatMeta('Rwandan Franc', 'FRw'),
    'SDG': _FiatMeta('Sudanese Pound', 'ج.س.'),
    'SOS': _FiatMeta('Somali Shilling', 'Sh'),
    'SYP': _FiatMeta('Syrian Pound', '£'),
    'TJS': _FiatMeta('Tajikistani Somoni', 'SM'),
    'TZS': _FiatMeta('Tanzanian Shilling', 'TSh'),
    'UGX': _FiatMeta('Ugandan Shilling', 'USh'),
    'UZS': _FiatMeta('Uzbekistani Som', "so'm"),
    'VES': _FiatMeta('Venezuelan Bolívar', 'Bs.'),
    'XAF': _FiatMeta('Central African CFA Franc', 'FCFA'),
    'XOF': _FiatMeta('West African CFA Franc', 'CFA'),
    'XPF': _FiatMeta('CFP Franc', '₣'),
    'YER': _FiatMeta('Yemeni Rial', '﷼'),
    'ZMW': _FiatMeta('Zambian Kwacha', 'ZK'),
  };

  static const Map<String, List<String>> _extraAliases = {
    'USD': ['dollar', 'us dollar', 'buck', 'dolar', 'доллар', '美元', 'ドル', 'dólar'],
    'EUR': ['euro', 'евро', '欧元', 'ユーロ'],
    'GBP': ['pound', 'sterling', 'sterlin', 'libra', 'фунт', '英镑', 'ポンド'],
    'TRY': ['tl', 'lira', 'turkish lira', 'turk lirasi', 'türk lirası', 'лира', '土耳其里拉', 'トルコリラ'],
    'AZN': ['manat', 'azerbaijani manat', 'azerbaijan manat', 'манат', '阿塞拜疆马纳特', 'マナト'],
    'JPY': ['yen', 'iene', 'иена', '日元', '円'],
    'CHF': ['franc', 'swiss franc', 'franco', 'франк', '瑞士法郎', 'フラン'],
    'CAD': ['canadian dollar', 'dolar canadiense', 'канадский доллар', '加元', 'カナダドル'],
    'AUD': ['australian dollar', 'dolar australiano', 'австралийский доллар', '澳元', '豪ドル'],
    'CNY': ['yuan', 'renminbi', 'юань', '人民币', '元'],
    'INR': ['rupee', 'rupia', 'рупия', '卢比', 'ルピー'],
    'RUB': ['ruble', 'rouble', 'rublo', 'рубль', '卢布', 'ルーブル'],
    'AED': ['dirham', 'дирхам', '迪拉姆', 'ディルハム'],
    'SAR': ['riyal', 'риял', '里亚尔', 'リヤル'],
    'KZT': ['tenge', 'тенге', '坚戈', 'テンゲ'],
    'GEL': ['lari', 'лари', '拉里', 'ラリ'],
    'UAH': ['hryvnia', 'grivna', 'гривна', '格里夫纳', 'フリヴニャ'],
    'PLN': ['zloty', 'złoty', 'злотый', '兹罗提', 'ズウォティ'],
    'BRL': ['real', 'реал', '雷亚尔', 'レアル'],
    'CNH': ['offshore yuan', '离岸人民币'],
    'BTC': ['bitcoin', 'биткоин', '比特币', 'ビットコイン'],
    'ETH': ['ethereum', 'ether', 'эфириум', '以太坊', 'イーサリアム'],
    'BNB': ['binance coin', 'бинанс'],
    'SOL': ['solana', 'солана', '索拉纳'],
    'XRP': ['ripple', 'рипл', '瑞波'],
    'ADA': ['cardano', 'кардано'],
    'DOGE': ['dogecoin', 'догикоин', '狗狗币'],
    'TRX': ['tron', 'трон', '波场'],
    'USDT': ['tether', 'тезер', '泰达币'],
    'USDC': ['usd coin', 'юсдс'],
    'LINK': ['chainlink', 'чейнлинк'],
    'AVAX': ['avalanche', 'аваланч'],
    'DOT': ['polkadot', 'полкадот'],
    'LTC': ['litecoin', 'лайткоин', '莱特币'],
    'BCH': ['bitcoin cash', 'биткоин кэш', '比特币现金'],
    'XLM': ['stellar', 'стеллар'],
    'TON': ['toncoin', 'тонкоин'],
    'SHIB': ['shiba inu', 'шиба'],
  };

  static const Map<String, Map<String, String>> _localizedNames = {
    'USD': {'tr': 'ABD Doları', 'ru': 'Доллар США', 'es': 'Dólar estadounidense', 'fr': 'Dollar américain', 'zh': '美元', 'ja': '米ドル', 'pt': 'Dólar americano'},
    'EUR': {'tr': 'Euro', 'ru': 'Евро', 'es': 'Euro', 'fr': 'Euro', 'zh': '欧元', 'ja': 'ユーロ', 'pt': 'Euro'},
    'GBP': {'tr': 'İngiliz Sterlini', 'ru': 'Фунт стерлингов', 'es': 'Libra esterlina', 'fr': 'Livre sterling', 'zh': '英镑', 'ja': '英ポンド', 'pt': 'Libra esterlina'},
    'TRY': {'tr': 'Türk Lirası', 'ru': 'Турецкая лира', 'es': 'Lira turca', 'fr': 'Lire turque', 'zh': '土耳其里拉', 'ja': 'トルコリラ', 'pt': 'Lira turca'},
    'AZN': {'tr': 'Azerbaycan Manatı', 'ru': 'Азербайджанский манат', 'es': 'Manat azerbaiyano', 'fr': 'Manat azerbaïdjanais', 'zh': '阿塞拜疆马纳特', 'ja': 'アゼルバイジャンマナト', 'pt': 'Manat azerbaijano'},
    'JPY': {'tr': 'Japon Yeni', 'ru': 'Японская иена', 'es': 'Yen japonés', 'fr': 'Yen japonais', 'zh': '日元', 'ja': '日本円', 'pt': 'Iene japonês'},
    'CHF': {'tr': 'İsviçre Frangı', 'ru': 'Швейцарский франк', 'es': 'Franco suizo', 'fr': 'Franc suisse', 'zh': '瑞士法郎', 'ja': 'スイスフラン', 'pt': 'Franco suíço'},
    'CAD': {'tr': 'Kanada Doları', 'ru': 'Канадский доллар', 'es': 'Dólar canadiense', 'fr': 'Dollar canadien', 'zh': '加元', 'ja': 'カナダドル', 'pt': 'Dólar canadense'},
    'AUD': {'tr': 'Avustralya Doları', 'ru': 'Австралийский доллар', 'es': 'Dólar australiano', 'fr': 'Dollar australien', 'zh': '澳元', 'ja': '豪ドル', 'pt': 'Dólar australiano'},
    'CNY': {'tr': 'Çin Yuanı', 'ru': 'Китайский юань', 'es': 'Yuan chino', 'fr': 'Yuan chinois', 'zh': '人民币', 'ja': '人民元', 'pt': 'Yuan chinês'},
    'INR': {'tr': 'Hindistan Rupisi', 'ru': 'Индийская рупия', 'es': 'Rupia india', 'fr': 'Roupie indienne', 'zh': '印度卢比', 'ja': 'インドルピー', 'pt': 'Rupia indiana'},
    'RUB': {'tr': 'Rus Rublesi', 'ru': 'Российский рубль', 'es': 'Rublo ruso', 'fr': 'Rouble russe', 'zh': '俄罗斯卢布', 'ja': 'ロシアルーブル', 'pt': 'Rublo russo'},
    'AED': {'tr': 'BAE Dirhemi', 'ru': 'Дирхам ОАЭ', 'es': 'Dírham de los EAU', 'fr': 'Dirham des Émirats', 'zh': '阿联酋迪拉姆', 'ja': 'UAEディルハム', 'pt': 'Dirham dos EAU'},
    'KZT': {'tr': 'Kazak Tengesi', 'ru': 'Казахстанский тенге', 'es': 'Tenge kazajo', 'fr': 'Tenge kazakh', 'zh': '哈萨克斯坦坚戈', 'ja': 'カザフテンゲ', 'pt': 'Tenge cazaque'},
    'GEL': {'tr': 'Gürcü Larisi', 'ru': 'Грузинский лари', 'es': 'Lari georgiano', 'fr': 'Lari géorgien', 'zh': '格鲁吉亚拉里', 'ja': 'ジョージアラリ', 'pt': 'Lari georgiano'},
    'UAH': {'tr': 'Ukrayna Grivnası', 'ru': 'Украинская гривна', 'es': 'Grivna ucraniana', 'fr': 'Hryvnia ukrainienne', 'zh': '乌克兰格里夫纳', 'ja': 'ウクライナフリヴニャ', 'pt': 'Hryvnia ucraniana'},
    'XAU_G': {'tr': 'Altın (gram)', 'ru': 'Золото (грамм)', 'es': 'Oro (gramo)', 'fr': 'Or (gramme)', 'zh': '黄金（克）', 'ja': '金（グラム）', 'pt': 'Ouro (grama)'},
    'XAG_G': {'tr': 'Gümüş (gram)', 'ru': 'Серебро (грамм)', 'es': 'Plata (gramo)', 'fr': 'Argent (gramme)', 'zh': '白银（克）', 'ja': '銀（グラム）', 'pt': 'Prata (grama)'},
    'XAU': {'tr': 'Altın (ons)', 'ru': 'Золото (унция)', 'es': 'Oro (onza)', 'fr': 'Or (once)', 'zh': '黄金（盎司）', 'ja': '金（オンス）', 'pt': 'Ouro (onça)'},
    'XAG': {'tr': 'Gümüş (ons)', 'ru': 'Серебро (унция)', 'es': 'Plata (onza)', 'fr': 'Argent (once)', 'zh': '白银（盎司）', 'ja': '銀（オンス）', 'pt': 'Prata (onça)'},
  };

  static const Map<String, int> _fiatRank = {
    'USD': 0, 'EUR': 1, 'GBP': 2, 'TRY': 3, 'AZN': 4, 'JPY': 5,
    'CHF': 6, 'CAD': 7, 'AUD': 8, 'CNY': 9, 'INR': 10, 'AED': 11,
    'KZT': 12, 'GEL': 13, 'UAH': 14, 'RUB': 15,
  };

  static final Set<String> _baseFiatCodes = _fiatMeta.keys.toSet();

  /// Returns the complete selectable catalog.
  ///
  /// Fiat codes returned by the rate API are added even when they do not have
  /// curated display metadata. A missing name/symbol therefore never makes a
  /// rate impossible to select.
  static List<Currency> build({Iterable<String> fiatCodes = const []}) {
    final codes = <String>{
      ..._baseFiatCodes,
      ...fiatCodes
          .map((code) => code.trim().toUpperCase())
          .where((code) => code.isNotEmpty),
    };
    final currencies = <Currency>[
      for (final code in codes) fiatCurrency(code),
      for (final currency in cryptoCurrencies) _enrich(currency),
      ...stockCurrencies,
      ...indexCurrencies,
      for (final currency in metalCurrencies) _enrich(currency),
    ];
    currencies.sort(_compare);
    return List<Currency>.unmodifiable(currencies);
  }

  static Currency fiatCurrency(String code) {
    final normalized = code.trim().toUpperCase();
    final meta = _fiatMeta[normalized];
    return _enrich(
      Currency(
        code: normalized,
        name: meta?.name ?? normalized,
        symbol: meta?.symbol ?? normalized,
        kind: CurrencyKind.fiat,
      ),
    );
  }

  static Currency? byCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    for (final currency in stockCurrencies) {
      if (currency.code == normalized) return currency;
    }
    for (final currency in indexCurrencies) {
      if (currency.code == normalized) return currency;
    }
    for (final currency in metalCurrencies) {
      if (currency.code == normalized) return _enrich(currency);
    }
    for (final crypto in cryptoCurrencies) {
      if (crypto.code == normalized) return _enrich(crypto);
    }
    if (_fiatMeta.containsKey(normalized) || _looksLikeFiatCode(normalized)) {
      return fiatCurrency(normalized);
    }
    return null;
  }

  static Currency? byCoinGeckoId(String? id) {
    if (id == null) return null;
    final normalized = id.trim();
    for (final crypto in cryptoCurrencies) {
      if (crypto.coinGeckoId == normalized) return _enrich(crypto);
    }
    return null;
  }

  static Currency? byYahooSymbol(String? symbol) {
    if (symbol == null) return null;
    final normalized = symbol.trim().toUpperCase();
    for (final currency in [...stockCurrencies, ...indexCurrencies]) {
      if (currency.yahooSymbol?.toUpperCase() == normalized) return currency;
    }
    return null;
  }

  static Currency? byProviderSymbol(String? symbol) {
    if (symbol == null || symbol.trim().isEmpty) return null;
    final normalized = symbol.trim().toUpperCase();
    return byCode(normalized) ??
        byYahooSymbol(normalized) ??
        (normalized == 'XAU' ? _enrich(metalCurrencies[2]) : null) ??
        (normalized == 'XAG' ? _enrich(metalCurrencies[3]) : null);
  }

  static bool _looksLikeFiatCode(String code) =>
      RegExp(r'^[A-Z]{2,8}$').hasMatch(code);

  static Currency _enrich(Currency currency) {
    final aliases = _extraAliases[currency.code];
    final names = _localizedNames[currency.code];
    if (aliases == null && names == null) return currency;
    return Currency(
      code: currency.code,
      name: currency.name,
      symbol: currency.symbol,
      kind: currency.kind,
      coinGeckoId: currency.coinGeckoId,
      yahooSymbol: currency.yahooSymbol,
      quoteCurrency: currency.quoteCurrency,
      aliases: List.unmodifiable({...currency.aliases, ...?aliases}),
      localizedNames: Map.unmodifiable({...currency.localizedNames, ...?names}),
    );
  }

  static int _compare(Currency a, Currency b) {
    if (a.kind != b.kind) {
      return _kindRank(a.kind).compareTo(_kindRank(b.kind));
    }
    if (a.isFiat) {
      final aRank = _fiatRank[a.code] ?? 1000;
      final bRank = _fiatRank[b.code] ?? 1000;
      if (aRank != bRank) return aRank.compareTo(bRank);
    }
    return a.code.compareTo(b.code);
  }

  static int _kindRank(CurrencyKind kind) => switch (kind) {
    CurrencyKind.fiat => 0,
    CurrencyKind.crypto => 1,
    CurrencyKind.stock => 2,
    CurrencyKind.marketIndex => 3,
    CurrencyKind.metal => 4,
  };
}
