import 'dart:convert';

import 'package:calc2/models/currency_catalog.dart';
import 'package:calc2/models/market_data.dart';
import 'package:calc2/services/market_service.dart';
import 'package:calc2/services/rate_service_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CoinGeckoMarketDataService markets', () {
    test('parses usable quotes and skips unknown or invalid entries', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'id': 'bitcoin',
              'symbol': 'btc',
              'name': 'Bitcoin',
              'current_price': 50000,
              'price_change_percentage_24h': 2.5,
              'market_cap': 1000000000000,
              'total_volume': 25000000000,
              'image': 'https://example.com/btc.png',
              'last_updated': '2026-10-25T11:58:00.000Z',
            },
            {
              'id': 'ethereum',
              'symbol': 'eth',
              'name': 'Ethereum',
              'current_price': 2000,
              'price_change_percentage_24h': null,
              'market_cap': 240000000000,
              'total_volume': 9000000000,
              'last_updated': '2026-10-25T11:59:00.000Z',
            },
            {'id': 'unknown-asset', 'symbol': 'bad', 'current_price': 12},
            {
              'id': 'solana',
              'symbol': 'sol',
              'name': 'Solana',
              'current_price': 0,
            },
            {
              'id': 'ripple',
              'symbol': 'xrp',
              'name': 'XRP',
              'current_price': 'not-a-number',
            },
            {
              'id': 'bitcoin',
              'symbol': 'btc',
              'name': 'Bitcoin',
              'current_price': 1,
            },
          ]),
          200,
        );
      });
      final service = CoinGeckoMarketDataService(
        client: client,
        apiKey: 'demo-key',
        clock: () => DateTime.utc(2026, 10, 25, 12),
      );

      final snapshot = await service.fetchMarkets();

      expect(captured.url.path, '/api/v3/coins/markets');
      expect(captured.url.queryParameters['vs_currency'], 'usd');
      expect(captured.url.queryParameters['order'], 'market_cap_desc');
      expect(captured.url.queryParameters['per_page'], '100');
      expect(captured.url.queryParameters['page'], '1');
      expect(captured.url.queryParameters['sparkline'], 'false');
      expect(captured.url.queryParameters.containsKey('ids'), isFalse);
      expect(captured.headers['x-cg-demo-api-key'], 'demo-key');
      expect(captured.headers['User-Agent'], 'Birimm/1.0');
      expect(captured.url.queryParameters['price_change_percentage'], '24h');

      expect(snapshot.quotes, hasLength(2));
      expect(snapshot.quotes.map((quote) => quote.code), ['BTC', 'ETH']);
      final bitcoin = snapshot.quotes.first;
      expect(bitcoin.usdPrice, 50000);
      expect(bitcoin.change24hPercent, 2.5);
      expect(bitcoin.marketCapUsd, 1000000000000);
      expect(bitcoin.volume24hUsd, 25000000000);
      expect(bitcoin.imageUrl, 'https://example.com/btc.png');
      expect(bitcoin.fetchedAt, DateTime.utc(2026, 10, 25, 12));
      expect(snapshot.providerUpdatedAt, DateTime.utc(2026, 10, 25, 11, 59));
      expect(snapshot.fetchedAt, DateTime.utc(2026, 10, 25, 12));
      expect(snapshot.nextPage, 2);
      expect(snapshot.hasMore, isFalse);
    });

    test('requests the selected page and clamps page size', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'id': 'bitcoin',
              'symbol': 'btc',
              'name': 'Bitcoin',
              'current_price': 50000,
              'last_updated': '2026-10-25T11:58:00.000Z',
            },
          ]),
          200,
        );
      });
      final service = CoinGeckoMarketDataService(
        client: client,
        clock: () => DateTime.utc(2026, 10, 25, 12),
      );

      final snapshot = await service.fetchMarkets(page: 3, perPage: 999);

      expect(captured.url.queryParameters['page'], '3');
      expect(captured.url.queryParameters['per_page'], '250');
      expect(snapshot.nextPage, 4);
      expect(snapshot.hasMore, isFalse);
    });

    test('rejects malformed and empty market responses', () async {
      Future<void> expectFailure(Object body) async {
        final service = CoinGeckoMarketDataService(
          client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
        );
        await expectLater(
          service.fetchMarkets(),
          throwsA(isA<RateServiceException>()),
        );
      }

      await expectFailure({'not': 'a list'});
      await expectFailure(<Object>[]);
      await expectFailure([
        {'id': 'bitcoin', 'current_price': -5},
      ]);
    });

    test('reports HTTP failures readably', () async {
      Future<void> expectFailure(int status, String fragment) async {
        final service = CoinGeckoMarketDataService(
          client: MockClient((_) async => http.Response('failure', status)),
        );
        await expectLater(
          service.fetchMarkets(),
          throwsA(
            isA<RateServiceException>().having(
              (error) => error.message,
              'message',
              contains(fragment),
            ),
          ),
        );
      }

      await expectFailure(429, 'rate limiting');
      await expectFailure(403, 'rejected');
      await expectFailure(500, 'HTTP 500');
    });

    test('surfaces invalid JSON and timeouts', () async {
      final malformed = CoinGeckoMarketDataService(
        client: MockClient((_) async => http.Response('not json', 200)),
      );
      await expectLater(
        malformed.fetchMarkets(),
        throwsA(
          isA<RateServiceException>().having(
            (error) => error.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );

      final timedOut = CoinGeckoMarketDataService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response('[]', 200);
        }),
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        timedOut.fetchMarkets(),
        throwsA(
          isA<RateServiceException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });

  group('CoinGeckoMarketDataService history', () {
    test('parses, filters, and sorts chart points', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'prices': [
              [1700003600000, 102],
              [1700000000000, 100],
              [1700007200000, 0],
              [1700010800000, -1],
              ['bad', 5],
              [1700014400000, 103],
            ],
          }),
          200,
        );
      });
      final service = CoinGeckoMarketDataService(
        client: client,
        clock: () => DateTime.utc(2026, 10, 25, 12),
      );
      final currency = CurrencyCatalog.byCode('BTC')!;

      final history = await service.fetchPriceHistory(
        currency: currency,
        range: PriceHistoryRange.week,
      );

      expect(captured.url.path, '/api/v3/coins/bitcoin/market_chart');
      expect(captured.url.queryParameters['vs_currency'], 'usd');
      expect(captured.url.queryParameters['days'], '7');
      expect(history.currencyCode, 'BTC');
      expect(history.range, PriceHistoryRange.week);
      expect(history.points, hasLength(3));
      expect(history.firstPrice, 100);
      expect(history.lastPrice, 103);
      expect(history.highPrice, 103);
      expect(history.lowPrice, 100);
      expect(history.periodChangePercent, closeTo(3, 0.000001));
      expect(history.fetchedAt, DateTime.utc(2026, 10, 25, 12));
    });

    test('reports provider payload and HTTP failures', () async {
      Future<void> expectFailure(http.Response response) async {
        final service = CoinGeckoMarketDataService(
          client: MockClient((_) async => response),
        );
        await expectLater(
          service.fetchPriceHistory(
            currency: CurrencyCatalog.byCode('BTC')!,
            range: PriceHistoryRange.day,
          ),
          throwsA(isA<RateServiceException>()),
        );
      }

      await expectFailure(http.Response('{}', 200));
      await expectFailure(http.Response('{"prices":[]}', 200));
      await expectFailure(http.Response('not json', 200));
      await expectFailure(http.Response('failure', 500));
      await expectFailure(http.Response('failure', 429));
    });

    test('rejects assets without a CoinGecko identifier before HTTP', () async {
      var calls = 0;
      final service = CoinGeckoMarketDataService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.fetchPriceHistory(
          currency: CurrencyCatalog.fiatCurrency('EUR'),
          range: PriceHistoryRange.day,
        ),
        throwsA(
          isA<RateServiceException>().having(
            (error) => error.message,
            'message',
            contains('No CoinGecko identifier'),
          ),
        ),
      );
      expect(calls, 0);
    });
  });
}
