import 'package:calc2/models/rate_status.dart';
import 'package:calc2/services/app_storage.dart';
import 'package:calc2/services/crypto_rate_service.dart';
import 'package:calc2/services/exchange_rate_repository.dart';
import 'package:calc2/services/fiat_rate_service.dart';
import 'package:calc2/services/rate_service_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_doubles.dart';

void main() {
  late MemoryKeyValueStore store;
  late AppStorage storage;

  setUp(() {
    store = MemoryKeyValueStore();
    storage = AppStorage(store);
  });

  ExchangeRateRepository buildRepository({
    required FakeFiatRateService fiat,
    required FakeCryptoRateService crypto,
  }) {
    return ExchangeRateRepository(
      fiatService: fiat,
      cryptoService: crypto,
      storage: storage,
      clock: () => testNow,
    );
  }

  test('merges live providers and persists one snapshot', () async {
    final fiat = FakeFiatRateService(
      quote: FiatRateQuote(
        unitsPerUsd: testFiatUnitsPerUsd,
        updatedAt: testNow.subtract(const Duration(hours: 1)),
      ),
    );
    final crypto = FakeCryptoRateService(
      quote: CryptoRateQuote(
        unitsPerUsd: testCryptoUnitsPerUsd,
        updatedAt: testNow.subtract(const Duration(minutes: 2)),
      ),
    );
    final repository = buildRepository(fiat: fiat, crypto: crypto);

    final result = await repository.refresh();

    expect(result.fiat.isLive, isTrue);
    expect(result.crypto.isLive, isTrue);
    expect(result.bundle, isNotNull);
    expect(result.bundle!.fiatUnitsPerUsd['EUR'], 0.9);
    expect(result.bundle!.cryptoUnitsPerUsd['BTC'], closeTo(1 / 50000, 1e-12));
    expect(result.bundle!.fetchedAt, testNow);

    final persisted = await storage.loadRateCache();
    expect(persisted, isNotNull);
    expect(persisted!.fiatUnitsPerUsd['TRY'], 30);
    expect(persisted.cryptoUnitsPerUsd['ETH'], closeTo(1 / 2000, 1e-12));
  });

  test('falls back per provider and reports cached origin and error', () async {
    final cached = makeRateBundle(
      fetchedAt: testNow.subtract(const Duration(hours: 5)),
    );
    final fiat = FakeFiatRateService(
      error: const RateServiceException('Fiat service unavailable.'),
    );
    final crypto = FakeCryptoRateService(
      quote: CryptoRateQuote(
        unitsPerUsd: testCryptoUnitsPerUsd,
        updatedAt: testNow,
      ),
    );
    final repository = buildRepository(fiat: fiat, crypto: crypto);

    final result = await repository.refresh(cached: cached);

    expect(result.fiat.isCached, isTrue);
    expect(result.fiat.errorMessage, 'Fiat service unavailable.');
    expect(result.crypto.isLive, isTrue);
    expect(result.bundle!.fiatUnitsPerUsd, cached.fiatUnitsPerUsd);
    expect(result.bundle!.cryptoUnitsPerUsd, testCryptoUnitsPerUsd);
    expect(result.bundle!.fetchedAt, testNow);
    expect(result.hasCachedFallback, isTrue);
    expect(await storage.loadRateCache(), isNotNull);
  });

  test('keeps the cached snapshot when both providers fail', () async {
    final cached = makeRateBundle(
      fetchedAt: testNow.subtract(const Duration(hours: 5)),
    );
    final repository = buildRepository(
      fiat: FakeFiatRateService(
        error: const RateServiceException('Fiat down.'),
      ),
      crypto: FakeCryptoRateService(
        error: const RateServiceException('Crypto down.'),
      ),
    );

    final result = await repository.refresh(cached: cached);

    expect(result.bundle, isNotNull);
    expect(result.fiat.isCached, isTrue);
    expect(result.crypto.isCached, isTrue);
    expect(result.fiat.errorMessage, 'Fiat down.');
    expect(result.crypto.errorMessage, 'Crypto down.');
    expect(result.bundle!.fetchedAt, cached.fetchedAt);
    expect(store.writeCount, 0);
  });

  test('reports unavailable providers when no cache exists', () async {
    final repository = buildRepository(
      fiat: FakeFiatRateService(
        error: const RateServiceException('Fiat down.'),
      ),
      crypto: FakeCryptoRateService(
        error: const RateServiceException('Crypto down.'),
      ),
    );

    final result = await repository.refresh();

    expect(result.bundle, isNull);
    expect(result.hasRates, isFalse);
    expect(result.fiat.isUnavailable, isTrue);
    expect(result.crypto.isUnavailable, isTrue);
    expect(result.fiat.errorMessage, 'Fiat down.');
    expect(result.crypto.errorMessage, 'Crypto down.');
    expect(store.writeCount, 0);
  });

  test(
    'a single live provider still produces a usable partial snapshot',
    () async {
      final repository = buildRepository(
        fiat: FakeFiatRateService(
          quote: FiatRateQuote(
            unitsPerUsd: testFiatUnitsPerUsd,
            updatedAt: testNow,
          ),
        ),
        crypto: FakeCryptoRateService(
          error: const RateServiceException('Crypto down.'),
        ),
      );

      final result = await repository.refresh();

      expect(result.bundle, isNotNull);
      expect(result.bundle!.hasFiat, isTrue);
      expect(result.bundle!.hasCrypto, isFalse);
      expect(result.fiat.isLive, isTrue);
      expect(result.crypto.isUnavailable, isTrue);
    },
  );

  test('unexpected service errors are converted to visible messages', () async {
    final repository = buildRepository(
      fiat: FakeFiatRateService(error: StateError('boom')),
      crypto: FakeCryptoRateService(error: ArgumentError('nope')),
    );

    final result = await repository.refresh();

    expect(result.fiat.origin, RateOrigin.unavailable);
    expect(result.crypto.origin, RateOrigin.unavailable);
    expect(result.fiat.errorMessage, contains('unexpectedly'));
    expect(result.crypto.errorMessage, contains('unexpectedly'));
  });

  test('loads cached rates from storage and ignores malformed data', () async {
    final cached = makeRateBundle();
    await seedRateCache(store, cached);
    final repository = buildRepository(
      fiat: FakeFiatRateService(),
      crypto: FakeCryptoRateService(),
    );

    final loaded = await repository.loadCachedRates();
    expect(loaded, isNotNull);
    expect(loaded!.fetchedAt, cached.fetchedAt);

    store.values[AppStorage.ratesKey] = 'not json';
    expect(await repository.loadCachedRates(), isNull);
  });
}
