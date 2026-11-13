// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'rate_service_exception.dart';

class FiatRateQuote {
  const FiatRateQuote({required this.unitsPerUsd, required this.updatedAt});

  final Map<String, double> unitsPerUsd;
  final DateTime updatedAt;
}

abstract interface class FiatRateService {
  Future<FiatRateQuote> fetchLatestUsdRates();
}

/// Verified free endpoint: https://open.er-api.com/v6/latest/USD
///
/// No API key is required. The provider updates once per day and asks clients
/// to cache, attribute the data, and avoid frequent polling.
class OpenErApiFiatRateService implements FiatRateService {
  OpenErApiFiatRateService({
    required http.Client client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client;

  static final Uri endpoint = Uri.parse(
    'https://open.er-api.com/v6/latest/USD',
  );

  final http.Client _client;
  final Duration timeout;

  @override
  Future<FiatRateQuote> fetchLatestUsdRates() async {
    http.Response response;
    try {
      response = await _client
          .get(endpoint, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw RateServiceException(
        'The fiat rate request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw RateServiceException(
        'Could not reach the fiat rate service.',
        cause: error,
      );
    } catch (error) {
      throw RateServiceException(
        'Could not reach the fiat rate service.',
        cause: error,
      );
    }

    if (response.statusCode == 429) {
      throw const RateServiceException(
        'The fiat rate service is rate limiting requests. Try again later.',
      );
    }
    if (response.statusCode != 200) {
      throw RateServiceException(
        'The fiat rate service returned HTTP ${response.statusCode}.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw RateServiceException(
        'The fiat rate response was not valid JSON.',
        cause: error,
      );
    }
    if (decoded is! Map) {
      throw const RateServiceException(
        'The fiat rate response had an unexpected shape.',
      );
    }
    final json = Map<String, Object?>.from(decoded);

    if (json['result'] != 'success') {
      final errorType = json['error-type'];
      throw RateServiceException(
        errorType is String && errorType.isNotEmpty
            ? 'The fiat rate service rejected the request ($errorType).'
            : 'The fiat rate service did not return a successful result.',
      );
    }
    if (json['base_code'] != 'USD') {
      throw const RateServiceException(
        'The fiat rate response did not use USD as its base.',
      );
    }

    final rawRates = json['rates'];
    if (rawRates is! Map) {
      throw const RateServiceException(
        'The fiat rate response did not include a rate table.',
      );
    }

    final rates = <String, double>{};
    for (final entry in rawRates.entries) {
      final code = entry.key;
      final rawRate = entry.value;
      if (code is! String) continue;
      final normalized = code.trim().toUpperCase();
      if (!RegExp(r'^[A-Z]{2,8}$').hasMatch(normalized)) continue;
      final rate = rawRate is num ? rawRate.toDouble() : null;
      if (rate == null || !rate.isFinite || rate <= 0) continue;
      rates[normalized] = rate;
    }
    if (rates.isEmpty) {
      throw const RateServiceException(
        'The fiat rate response contained no usable rates.',
      );
    }
    // USD is the verified reference base of the endpoint.
    rates['USD'] = 1;

    final updatedUnix = json['time_last_update_unix'];
    if (updatedUnix is! num || updatedUnix <= 0) {
      throw const RateServiceException(
        'The fiat rate response did not include a valid update time.',
      );
    }
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      (updatedUnix * 1000).round(),
      isUtc: true,
    );

    return FiatRateQuote(
      unitsPerUsd: Map.unmodifiable(rates),
      updatedAt: updatedAt,
    );
  }
}
