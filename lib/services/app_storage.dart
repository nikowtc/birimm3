import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_preferences.dart';
import '../models/calculation_history.dart';
import '../models/market_data.dart';
import '../models/quick_conversion.dart';
import '../models/rate_bundle.dart';
import '../models/user_favorites.dart';

abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesStore implements KeyValueStore {
  const SharedPreferencesStore(this.preferences);

  final SharedPreferences preferences;

  @override
  Future<String?> read(String key) async => preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    final success = await preferences.setString(key, value);
    if (!success) {
      throw StateError('Could not write local preference "$key".');
    }
  }
}

/// Typed local persistence for preferences, history, favorites, rates, and
/// market snapshots.
class AppStorage {
  const AppStorage(this._store);

  static const String ratesKey = 'rates_cache_v1';
  static const String preferencesKey = 'app_preferences_v1';
  static const String favoritesKey = 'favorites_v1';
  static const String historyKey = 'calculation_history_v1';
  static const String marketCacheKey = 'market_cache_v2';
  static const String equityCacheKey = 'equity_cache_v1';
  static const String metalCacheKey = 'metal_cache_v1';
  static const String quickConversionsKey = 'quick_conversions_v1';

  final KeyValueStore _store;

  Future<RateBundle?> loadRateCache() async {
    final raw = await _store.read(ratesKey);
    if (raw == null) return null;
    try {
      return RateBundle.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored('rate cache', error, stackTrace);
      return null;
    }
  }

  Future<void> saveRateCache(RateBundle bundle) async {
    await _store.write(ratesKey, jsonEncode(bundle.toJson()));
  }

  Future<AppPreferences> loadPreferences() async {
    final raw = await _store.read(preferencesKey);
    if (raw == null) return const AppPreferences();
    try {
      return AppPreferences.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored('preferences', error, stackTrace);
      return const AppPreferences();
    }
  }

  Future<void> savePreferences(AppPreferences preferences) async {
    await _store.write(preferencesKey, jsonEncode(preferences.toJson()));
  }

  Future<UserFavorites> loadFavorites() async {
    final raw = await _store.read(favoritesKey);
    if (raw == null) return const UserFavorites();
    try {
      return UserFavorites.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored('favorites', error, stackTrace);
      return const UserFavorites();
    }
  }

  Future<void> saveFavorites(UserFavorites favorites) async {
    await _store.write(favoritesKey, jsonEncode(favorites.toJson()));
  }

  Future<List<CalculationHistoryEntry>> loadHistory() async {
    final raw = await _store.read(historyKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final json = Map<String, Object?>.from(decoded);
      final rawEntries = json['entries'];
      if (rawEntries is! List) return const [];
      final entries = <CalculationHistoryEntry>[];
      final seen = <String>{};
      for (final rawEntry in rawEntries) {
        final entry = CalculationHistoryEntry.fromJson(rawEntry);
        if (entry == null || !seen.add(entry.id)) continue;
        entries.add(entry);
      }
      return List.unmodifiable(entries);
    } catch (error, stackTrace) {
      _logIgnored('calculation history', error, stackTrace);
      return const [];
    }
  }

  Future<void> saveHistory(List<CalculationHistoryEntry> entries) async {
    await _store.write(
      historyKey,
      jsonEncode({
        'version': 1,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
    );
  }

  Future<MarketSnapshot?> loadMarketCache() async {
    final raw = await _store.read(marketCacheKey);
    if (raw == null) return null;
    try {
      return MarketSnapshot.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored('market cache', error, stackTrace);
      return null;
    }
  }

  Future<void> saveMarketCache(MarketSnapshot snapshot) async {
    await _store.write(marketCacheKey, jsonEncode(snapshot.toJson()));
  }

  Future<MarketSnapshot?> loadEquityCache() async {
    return _loadSnapshot(equityCacheKey, 'equity cache');
  }

  Future<void> saveEquityCache(MarketSnapshot snapshot) async {
    await _store.write(equityCacheKey, jsonEncode(snapshot.toJson()));
  }

  Future<MarketSnapshot?> loadMetalCache() async {
    return _loadSnapshot(metalCacheKey, 'metal cache');
  }

  Future<void> saveMetalCache(MarketSnapshot snapshot) async {
    await _store.write(metalCacheKey, jsonEncode(snapshot.toJson()));
  }

  Future<QuickConversionData> loadQuickConversions() async {
    final raw = await _store.read(quickConversionsKey);
    if (raw == null) return const QuickConversionData();
    try {
      return QuickConversionData.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored('quick conversions', error, stackTrace);
      return const QuickConversionData();
    }
  }

  Future<void> saveQuickConversions(QuickConversionData data) async {
    await _store.write(quickConversionsKey, jsonEncode(data.toJson()));
  }

  Future<MarketSnapshot?> _loadSnapshot(String key, String label) async {
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      return MarketSnapshot.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored(label, error, stackTrace);
      return null;
    }
  }

  String priceHistoryKey(String currencyCode, PriceHistoryRange range) {
    return 'price_history_v1_${currencyCode.toUpperCase()}_${range.name}';
  }

  Future<PriceHistory?> loadPriceHistory(
    String currencyCode,
    PriceHistoryRange range,
  ) async {
    final raw = await _store.read(priceHistoryKey(currencyCode, range));
    if (raw == null) return null;
    try {
      return PriceHistory.fromJson(jsonDecode(raw));
    } catch (error, stackTrace) {
      _logIgnored('price history', error, stackTrace);
      return null;
    }
  }

  Future<void> savePriceHistory(PriceHistory history) async {
    await _store.write(
      priceHistoryKey(history.currencyCode, history.range),
      jsonEncode(history.toJson()),
    );
  }

  void _logIgnored(String label, Object error, StackTrace stackTrace) {
    developer.log(
      'Ignoring unreadable $label.',
      name: 'AppStorage',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
