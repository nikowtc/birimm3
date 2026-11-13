import 'rate_bundle.dart';

enum RateOrigin { live, cached, unavailable }

class RateOriginInfo {
  const RateOriginInfo({
    required this.origin,
    this.updatedAt,
    this.errorMessage,
  });

  const RateOriginInfo.unavailable({this.errorMessage})
    : origin = RateOrigin.unavailable,
      updatedAt = null;

  final RateOrigin origin;
  final DateTime? updatedAt;
  final String? errorMessage;

  bool get isLive => origin == RateOrigin.live;
  bool get isCached => origin == RateOrigin.cached;
  bool get isUnavailable => origin == RateOrigin.unavailable;
}

class RateRefreshResult {
  const RateRefreshResult({
    required this.bundle,
    required this.fiat,
    required this.crypto,
  });

  final RateBundle? bundle;
  final RateOriginInfo fiat;
  final RateOriginInfo crypto;

  bool get hasRates => bundle?.hasAnyRates ?? false;
  bool get hasCachedFallback => fiat.isCached || crypto.isCached;
  bool get hasError =>
      (fiat.errorMessage?.isNotEmpty ?? false) ||
      (crypto.errorMessage?.isNotEmpty ?? false);
}
