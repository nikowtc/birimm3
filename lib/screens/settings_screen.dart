import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../app_info.dart';
import '../models/app_preferences.dart';
import '../models/rate_status.dart';
import '../providers/calculator_controller.dart';
import '../providers/markets_controller.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../utils/external_links.dart';
import '../utils/formatting.dart';
import '../widgets/brand_mark.dart';
import '../widgets/currency_picker_dialog.dart';
import '../widgets/panel.dart';

/// Appearance, language, output currency, data transparency, and attribution.
///
/// This is a full destination rather than a dialog so the controls never fight
/// the calculator for space on compact screens.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _refreshing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickOutputCurrency(CalculatorController controller) async {
    final selected = await showCurrencyPicker(
      context,
      currencies: controller.currencies,
      selected: controller.outputCurrency,
      title: context.l10n.selectOutputCurrency,
      favoriteCodes: [
        for (final currency in controller.favoriteCurrencies) currency.code,
      ],
      onFavoriteToggle: controller.toggleCurrencyFavorite,
    );
    if (!mounted || selected == null) return;
    controller.setOutputCurrency(selected);
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final calculator = context.read<CalculatorController>();
    try {
      await calculator.refreshAllData();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculator = context.watch<CalculatorController>();
    final markets = context.watch<MarketsController>();
    final l10n = context.l10n;
    final colors = context.colors;
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 760
        ? 30.0
        : 16.0;
    final busy =
        _refreshing ||
        calculator.isLoadingRates ||
        markets.isLoading ||
        markets.isLoadingEquities ||
        markets.isLoadingMetals;

    return SingleChildScrollView(
      key: const Key('settings-page'),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        24,
        horizontalPadding,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                eyebrow: l10n.appName,
                title: l10n.settingsTitle,
                subtitle: l10n.settingsSubtitle,
                trailing: IconButton(
                  key: const Key('settings-refresh-button'),
                  tooltip: busy ? l10n.updating : l10n.refreshAll,
                  onPressed: busy ? null : _refreshAll,
                  icon: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: colors.accent,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              if (calculator.persistenceError != null) ...[
                NoticeBanner(
                  icon: Icons.save_outlined,
                  tone: NoticeTone.warning,
                  message: localizePersistenceMessage(
                    l10n,
                    calculator.persistenceError!,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (calculator.rateRefreshError != null) ...[
                NoticeBanner(
                  icon: Icons.error_outline_rounded,
                  tone: NoticeTone.danger,
                  message: l10n.ratesUpdateError,
                  detail: calculator.rateRefreshError,
                ),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  final preferencesColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PreferencesPanel(
                        calculator: calculator,
                        onPickOutput: () => _pickOutputCurrency(calculator),
                      ),
                      const SizedBox(height: 16),
                      _StoragePanel(calculator: calculator),
                    ],
                  );
                  final dataColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DataPanel(
                        calculator: calculator,
                        markets: markets,
                        busy: busy,
                        onRefresh: _refreshAll,
                      ),
                      const SizedBox(height: 16),
                      const _AboutPanel(),
                    ],
                  );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        preferencesColumn,
                        const SizedBox(height: 16),
                        dataColumn,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: preferencesColumn),
                      const SizedBox(width: 16),
                      Expanded(child: dataColumn),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel({
    required this.calculator,
    required this.onPickOutput,
  });

  final CalculatorController calculator;
  final VoidCallback onPickOutput;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeLabels = <AppThemePreference, String>{
      AppThemePreference.dark: l10n.themeDark,
      AppThemePreference.light: l10n.themeLight,
      AppThemePreference.system: l10n.themeSystem,
    };
    return _SettingsPanel(
      title: l10n.preferencesTitle,
      children: [
        _SettingBlock(
          title: l10n.appearance,
          description: l10n.appearanceDescription,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedControl<AppThemePreference>(
              key: const Key('settings-theme-control'),
              values: AppThemePreference.values,
              labels: [
                for (final preference in AppThemePreference.values)
                  themeLabels[preference]!,
              ],
              selected: calculator.theme,
              onChanged: calculator.setTheme,
            ),
          ),
        ),
        const _PanelDivider(),
        _SettingBlock(
          title: l10n.language,
          description: l10n.languageDescription,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              key: const Key('settings-language-control'),
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final language in AppLanguage.values)
                  _LanguageChip(
                    key: Key('settings-language-${language.storageValue}'),
                    label: l10n.languageName(language),
                    selected: calculator.language == language,
                    onTap: () => calculator.setLanguage(language),
                  ),
              ],
            ),
          ),
        ),
        const _PanelDivider(),
        _SettingBlock(
          title: l10n.outputCurrency,
          description: l10n.settingsOutputDescription,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('settings-output-currency'),
              onPressed: onPickOutput,
              icon: Text(
                calculator.outputCurrency.symbol,
                style: TextStyle(
                  color: calculator.outputCurrency.isCrypto
                      ? context.colors.warning
                      : context.colors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              label: Text(calculator.outputCurrency.code),
            ),
          ),
        ),
      ],
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.calculator,
    required this.markets,
    required this.busy,
    required this.onRefresh,
  });

  final CalculatorController calculator;
  final MarketsController markets;
  final bool busy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final localeName = l10n.localeName;
    final cryptoTimestamp =
        calculator.cryptoMarketStatus.updatedAt ?? calculator.ratesFetchedAt;

    return _SettingsPanel(
      title: l10n.ratesAndData,
      trailing: FilledButton.icon(
        key: const Key('settings-refresh-all'),
        onPressed: busy ? null : () => unawaited(onRefresh()),
        icon: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onAccent,
                ),
              )
            : const Icon(Icons.refresh_rounded, size: 16),
        label: Text(busy ? l10n.updating : l10n.refreshAll),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          textStyle: const TextStyle(fontSize: 12.5),
        ),
      ),
      children: [
        Text(
          l10n.settingsRatesDescription,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, height: 1.45),
        ),
        const SizedBox(height: 12),
        _SourceRow(
          label: l10n.fiatRates,
          source: 'ExchangeRate-API',
          status: calculator.fiatStatus,
          timestamp: calculator.fiatStatus.updatedAt,
          localeName: localeName,
        ),
        const SizedBox(height: 9),
        _SourceRow(
          label: l10n.cryptoPrices,
          source: 'CoinGecko',
          status: calculator.cryptoMarketStatus,
          timestamp: cryptoTimestamp,
          localeName: localeName,
        ),
        const SizedBox(height: 9),
        _SourceRow(
          label: l10n.stockPrices,
          source: 'Yahoo Finance',
          status: markets.equityStatus,
          timestamp: markets.equityStatus.updatedAt,
          localeName: localeName,
          detail: markets.equityError,
        ),
        const SizedBox(height: 9),
        _SourceRow(
          label: l10n.metalPrices,
          source: 'Gold API',
          status: markets.metalStatus,
          timestamp: markets.metalStatus.updatedAt,
          localeName: localeName,
          detail: markets.metalError,
        ),
        if (markets.errorMessage != null && markets.quotes.isEmpty) ...[
          const SizedBox(height: 10),
          NoticeBanner(
            icon: Icons.error_outline_rounded,
            tone: NoticeTone.danger,
            message: l10n.marketUnavailableTitle,
            detail: markets.errorMessage,
          ),
        ],
        if (markets.equityError != null && markets.equityQuotes.isEmpty) ...[
          const SizedBox(height: 10),
          NoticeBanner(
            icon: Icons.show_chart_rounded,
            tone: NoticeTone.warning,
            message: l10n.stocksUnavailable,
            detail: markets.equityError,
          ),
        ],
        if (markets.metalError != null && markets.metalQuotes.isEmpty) ...[
          const SizedBox(height: 10),
          NoticeBanner(
            icon: Icons.diamond_outlined,
            tone: NoticeTone.warning,
            message: l10n.metalUnavailable,
            detail: markets.metalError,
          ),
        ],
      ],
    );
  }
}

class _StoragePanel extends StatelessWidget {
  const _StoragePanel({required this.calculator});

  final CalculatorController calculator;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return _SettingsPanel(
      title: l10n.storage,
      children: [
        Text(
          l10n.storageDescription,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, height: 1.45),
        ),
        const SizedBox(height: 13),
        _FactLine(
          icon: Icons.star_outline_rounded,
          label: l10n.favoritesTitle,
          value: l10n.favoritesSaved(calculator.favoriteCurrencies.length),
        ),
        const SizedBox(height: 9),
        _FactLine(
          icon: Icons.history_rounded,
          label: l10n.historyTitle,
          value: l10n.historySaved(calculator.history.length),
        ),
      ],
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return _SettingsPanel(
      title: l10n.about,
      children: [
        Align(alignment: Alignment.centerLeft, child: BrandLogo(width: 184)),
        const SizedBox(height: 15),
        Text(
          l10n.aboutBody,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 14),
        _FactLine(
          icon: Icons.person_outline_rounded,
          label: l10n.aboutDeveloper,
          value: AppInfo.developer,
        ),
        const SizedBox(height: 9),
        _FactLine(
          icon: Icons.info_outline_rounded,
          label: l10n.appVersion,
          value: AppInfo.version,
        ),
        const SizedBox(height: 14),
        const _PanelDivider(),
        SectionLabel(l10n.dataSources),
        const SizedBox(height: 7),
        for (final source in AppInfo.dataSources) ...[
          _AttributionLink(label: source.$1, url: source.$2),
          const SizedBox(height: 5),
        ],
        const SizedBox(height: 6),
        _AttributionLink(label: l10n.projectLink, url: AppInfo.projectUrl),
        const SizedBox(height: 5),
        _AttributionLink(
          label: l10n.developerLink,
          url: AppInfo.developerUrl,
        ),
        const SizedBox(height: 14),
        const _PanelDivider(),
        Text(
          l10n.softwareCredits,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SoftChip(
              label: l10n.sourceAvailableLicense,
              icon: Icons.copyright_rounded,
              color: colors.textSecondary,
              background: colors.surfaceMuted,
            ),
            OutlinedButton.icon(
              key: const Key('about-third-party-licenses'),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: AppInfo.appName,
                applicationVersion: AppInfo.version,
                applicationLegalese: l10n.sourceAvailableLicense,
              ),
              icon: const Icon(Icons.article_outlined, size: 15),
              label: Text(l10n.thirdPartyLicenses),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          l10n.copyright,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, fontSize: 10.5),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.dataDescription,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, fontSize: 11, height: 1.45),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 13, 13, 12),
            child: Row(
              children: [
                Expanded(child: SectionLabel(title)),
                ?trailing,
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 14, 17, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, height: 1.45),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.accentSoft : colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? colors.accent.withValues(alpha: 0.45)
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 13, color: colors.accent),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colors.textPrimary : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.source,
    required this.status,
    required this.timestamp,
    required this.localeName,
    this.detail,
  });

  final String label;
  final String source;
  final RateOriginInfo status;
  final DateTime? timestamp;
  final String localeName;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final color = status.isLive
        ? colors.positive
        : status.isCached
        ? colors.warning
        : colors.danger;
    final state = status.isLive
        ? l10n.live
        : status.isCached
        ? l10n.cached
        : l10n.unavailable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusDot(color: color, size: 6),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SoftChip(
                label: state,
                color: color,
                background: status.isLive
                    ? colors.positiveSoft
                    : status.isCached
                    ? colors.warningSoft
                    : colors.dangerSoft,
                icon: status.isLive
                    ? Icons.sensors_rounded
                    : status.isCached
                    ? Icons.cloud_off_rounded
                    : Icons.remove_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textMuted, fontSize: 10.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timestamp == null
                    ? l10n.noRateSnapshot
                    : formatTimestamp(timestamp, localeName: localeName),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.textMuted, fontSize: 10.5),
              ),
            ],
          ),
          if (detail case final detail?) ...[
            const SizedBox(height: 5),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.warning, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 15, color: colors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      key: Key('settings-link-$url'),
      borderRadius: BorderRadius.circular(4),
      onTap: () => openExternalLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 12, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: context.colors.border),
    );
  }
}
