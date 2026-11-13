import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

const String exchangeRateApiUrl = 'https://www.exchangerate-api.com';
const String coinGeckoUrl = 'https://www.coingecko.com';

/// Opens provider attribution links without letting a launcher failure become
/// a silent dead button.
Future<void> openExternalLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = context.l10n.linkOpenFailed;
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
