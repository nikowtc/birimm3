import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/rate_status.dart';
import '../providers/calculator_controller.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../utils/external_links.dart';
import '../utils/formatting.dart';
import 'panel.dart';

/// Compact live/cached/unavailable state for the two rate providers.
class RateStatusStrip extends StatelessWidget {
  const RateStatusStrip({super.key, this.showAttribution = true});

  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();
    final colors = context.colors;
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final error = controller.rateRefreshError;
    final persistenceError = controller.persistenceError;

    return AppPanel(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 9,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ProviderBadge(
                      label: l10n.fiatRates,
                      source: 'ExchangeRate-API',
                      status: controller.fiatStatus,
                      localeName: localeName,
                    ),
                    _ProviderBadge(
                      label: l10n.cryptoPrices,
                      source: 'CoinGecko',
                      status: controller.cryptoMarketStatus,
                      localeName: localeName,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('refresh-rates-button'),
                tooltip: controller.isLoadingRates
                    ? l10n.updating
                    : l10n.refreshAll,
                onPressed: controller.isLoadingRates
                    ? null
                    : controller.refreshAllData,
                icon: controller.isLoadingRates
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colors.accent,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 19),
              ),
            ],
          ),
          if (showAttribution) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.data,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    letterSpacing: 0.6,
                    fontSize: 9,
                  ),
                ),
                _LinkLabel(label: 'ExchangeRate-API', url: exchangeRateApiUrl),
                Text(
                  '·',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
                _LinkLabel(label: 'CoinGecko', url: coinGeckoUrl),
                if (controller.ratesFetchedAt != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· ${formatTimestamp(controller.ratesFetchedAt, localeName: localeName)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 9),
            NoticeBanner(
              icon: Icons.error_outline_rounded,
              tone: NoticeTone.danger,
              message: localizePersistenceMessage(l10n, error),
            ),
          ],
          if (persistenceError != null) ...[
            const SizedBox(height: 9),
            NoticeBanner(
              icon: Icons.save_outlined,
              tone: NoticeTone.warning,
              message: localizePersistenceMessage(l10n, persistenceError),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({
    required this.label,
    required this.source,
    required this.status,
    required this.localeName,
  });

  final String label;
  final String source;
  final RateOriginInfo status;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final color = status.isLive
        ? colors.positive
        : status.isCached
        ? colors.warning
        : colors.danger;
    final origin = status.isLive
        ? l10n.live
        : status.isCached
        ? l10n.cached
        : l10n.unavailable;

    return Tooltip(
      message: status.isUnavailable
          ? status.errorMessage ?? l10n.ratesUnavailable
          : l10n.providerTooltip(
              source,
              formatFullTimestamp(status.updatedAt, localeName: localeName),
            ),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(color: color, size: 6),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          Text(
            origin,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, letterSpacing: 0.5, fontSize: 9),
          ),
          if (status.updatedAt != null)
            Text(
              formatTimestamp(status.updatedAt, localeName: localeName),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textMuted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _LinkLabel extends StatelessWidget {
  const _LinkLabel({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => openExternalLink(context, url),
      borderRadius: BorderRadius.circular(3),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textSecondary,
          fontSize: 11,
          decoration: TextDecoration.underline,
          decorationColor: colors.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
