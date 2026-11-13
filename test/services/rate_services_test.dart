import 'dart:convert';

import 'package:calc2/services/crypto_rate_service.dart';
import 'package:calc2/services/fiat_rate_service.dart';
import 'package:calc2/services/rate_service_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenErApiFiatRateService', () {
    test('parses a successful USD response and normalizes rates', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'result': 'success',
            'base_code': 'USD',
            'time_last_update_unix': 1700000000,
            'rates': {
              'USD': 1,
              'EUR': 0.9,
              'TRY': 30.5,
              'BAD': 0,
              'NEGATIVE': -2,
              'TOOLONGCODE': 5,
              'NOT_A_NUMBER': 'x',
            },
          }),
          200,
        );
      });

      final service = OpenErApiFiatRateService(client: client);
      final quote = await service.fetchLatestUsdRates();

      expect(
        captured.url.toString(),
        OpenErApiFiatRateService.endpoint.toString(),
      );
      expect(captured.headers['Accept'], 'application/json');
      expect(quote.unitsPerUsd['EUR'], 0.9);
      expect(quote.unitsPerUsd['TRY'], 30.5);
      expect(quote.unitsPerUsd['USD'], 1);
      expect(quote.unitsPerUsd.containsKey('BAD'), isFalse);
      expect(quote.unitsPerUsd.containsKey('NEGATIVE'), isFalse);
      expect(quote.unitsPerUsd.containsKey('TOOLONGCODE'), isFalse);
      expect(
        quote.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
    });

    test(
      'rejects provider errors, wrong base, and malformed payloads',
      () async {
        Future<void> expectFailure(http.Response response) async {
          final service = OpenErApiFiatRateService(
            client: MockClient((_) async => response),
          );
          await expectLater(
            service.fetchLatestUsdRates(),
            throwsA(isA<RateServiceException>()),
          );
        }

        await expectFailure(
          http.Response(
            jsonEncode({'result': 'error', 'error-type': 'quota'}),
            200,
          ),
        );
        await expectFailure(
          http.Response(
            jsonEncode({
              'result': 'success',
              'base_code': 'EUR',
              'time_last_update_unix': 1700000000,
              'rates': {'USD': 1},
            }),
            200,
          ),
        );
        await expectFailure(http.Response('not json', 200));
        await expectFailure(http.Response('{}', 200));
        await expectFailure(
          http.Response(
            jsonEncode({
              'result': 'success',
              'base_code': 'USD',
              'time_last_update_unix': 1700000000,
              'rates': {'BAD': 0},
            }),
            200,
          ),
        );
        await expectFailure(
          http.Response(
            jsonEncode({
              'result': 'success',
              'base_code': 'USD',
              'rates': {'EUR': 0.9},
            }),
            200,
          ),
        );
        await expectFailure(http.Response('server error', 500));
        await expectFailure(http.Response('rate limited', 429));
      },
    );

    test('turns a timeout into a readable exception', () async {
      final service = OpenErApiFiatRateService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.fetchLatestUsdRates(),
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

  group('CoinGeckoCryptoRateService', () {
    test(
      'parses prices into units per USD and keeps the latest timestamp',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'bitcoin': {'usd': 50000, 'last_updated_at': 1700000000},
              'ethereum': {'usd': 2000, 'last_updated_at': 1700000100},
              'solana': {'usd': 100, 'last_updated_at': 1700000050},
              'ripple': {'usd': 0},
              'cardano': {'usd': 'bad'},
            }),
            200,
          );
        });

        final service = CoinGeckoCryptoRateService(
          client: client,
          apiKey: 'demo',
        );
        final quote = await service.fetchLatestUsdRates();

        expect(captured.url.path, '/api/v3/simple/price');
        expect(captured.url.queryParameters['vs_currencies'], 'usd');
        expect(captured.url.queryParameters['include_last_updated_at'], 'true');
        expect(captured.url.queryParameters['ids'], contains('bitcoin'));
        expect(captured.headers['x-cg-demo-api-key'], 'demo');
        expect(captured.headers['User-Agent'], 'CurrencyCalculator/1.0');
        expect(quote.unitsPerUsd['BTC'], closeTo(1 / 50000, 0.000000001));
        expect(quote.unitsPerUsd['ETH'], closeTo(1 / 2000, 0.000000001));
        expect(quote.unitsPerUsd['SOL'], closeTo(1 / 100, 0.000000001));
        expect(quote.unitsPerUsd.containsKey('XRP'), isFalse);
        expect(
          quote.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(1700000100000, isUtc: true),
        );
      },
    );

    test('rejects HTTP and payload failures', () async {
      Future<void> expectFailure(http.Response response) async {
        final service = CoinGeckoCryptoRateService(
          client: MockClient((_) async => response),
        );
        await expectLater(
          service.fetchLatestUsdRates(),
          throwsA(isA<RateServiceException>()),
        );
      }

      await expectFailure(http.Response('not json', 200));
      await expectFailure(http.Response('{}', 200));
      await expectFailure(http.Response('[]', 200));
      await expectFailure(http.Response('rate limited', 429));
      await expectFailure(http.Response('forbidden', 403));
      await expectFailure(http.Response('server error', 500));
    });

    test(
      'a malformed asset entry is skipped without inventing a price',
      () async {
        final service = CoinGeckoCryptoRateService(
          client: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'bitcoin': {'usd': 50000, 'last_updated_at': 1700000000},
                'ethereum': {'usd': -1},
              }),
              200,
            );
          }),
        );

        final quote = await service.fetchLatestUsdRates();
        expect(quote.unitsPerUsd.keys.toList(), ['BTC']);
      },
    );

    test('timeout is surfaced', () async {
      final service = CoinGeckoCryptoRateService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.fetchLatestUsdRates(),
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
}
