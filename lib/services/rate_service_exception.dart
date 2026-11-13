enum MarketFailure { network, rateLimit, provider, needProxy, missingRate }

class RateServiceException implements Exception {
  const RateServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class MarketServiceException extends RateServiceException {
  const MarketServiceException(
    super.message, {
    required this.reason,
    super.cause,
  });

  final MarketFailure reason;
}
