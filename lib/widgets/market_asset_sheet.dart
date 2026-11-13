import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/currency_catalog.dart';
import '../models/market_data.dart';
import '../providers/calculator_controller.dart';
import '../providers/markets_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/market_pricing.dart';
import 'market_change_chip.dart';
import 'panel.dart';
import 'price_chart.dart';

/// Detail and chart sheet for one CoinGecko asset.
class MarketAssetSheet extends StatefulWidget {
  const MarketAssetSheet({
    super.key,
    required this.quote,
    required this.onAddToCalculator,
    required this.onSetOutput,
  });

  final MarketQuote quote;
  final VoidCallback onAddToCalculator;
  final VoidCallback onSetOutput;

  @override
  State<MarketAssetSheet> createState() => _MarketAssetSheetState();
}

class _MarketAssetSheetState extends State<MarketAssetSheet> {
  PriceHistoryRange _range = PriceHistoryRange.day;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool forceRefresh = false}) async {
    await context.read<MarketsController>().loadHistory(
      widget.quote.currency,
      _range,
      forceRefresh: forceRefresh,
    );
  }

  void _selectRange(PriceHistoryRange range) {
    if (range == _range) return;
    setState(() => _range = range);
    unawaited(_load());
  }

  void _addToCalculator() {
    Navigator.of(context).pop();
    widget.onAddToCalculator();
  }

  void _setOutput() {
    Navigator.of(context).pop();
    widget.onSetOutput();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final markets = context.watch<MarketsController>();
    final calculator = context.watch<CalculatorController>();
    final quote = widget.quote;
    final priceView = marketPriceView(calculator);
    final price = priceView.priceFor(quote.usdPrice);
    final favorite = calculator.isCurrencyFavorite(quote.code);
    final historyState = markets.historyState(quote.currency, _range);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 760,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AssetBadge(quote: quote),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote.currency.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${quote.code} · ${quote.currency.symbol}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('favorite-market-sheet-${quote.code}'),
                      tooltip: favorite
                          ? l10n.removeFromFavorites
                          : l10n.addToFavorites,
                      onPressed: () {
                        unawaited(
                          calculator.toggleCurrencyFavorite(quote.currency),
                        );
                      },
                      icon: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: favorite ? colors.warning : colors.textMuted,
                      ),
                    ),
                    IconButton(
                      key: const Key('close-market-sheet'),
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatAmount(
                        price,
                        priceView.currency,
                        localeName: localeName,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.8,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    SoftChip(
                      label: priceView.currency.code,
                      color: colors.textSecondary,
                      background: colors.surfaceRaised,
                    ),
                    MarketChangeChip(
                      percent: quote.change24hPercent,
                      localeName: localeName,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  priceView.isUsdFallback
                      ? l10n.marketPricesInUsd
                      : l10n.marketPricesInOutput,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.border),
                  ),
                  child: Wrap(
                    spacing: 30,
                    runSpacing: 12,
                    children: [
                      FactPair(
                        label: l10n.marketCap,
                        value: _compactUsd(quote.marketCapUsd, localeName),
                      ),
                      FactPair(
                        label: l10n.volume24h,
                        value: _compactUsd(quote.volume24hUsd, localeName),
                      ),
                      FactPair(
                        label: l10n.change24h,
                        value: quote.change24hPercent == null
                            ? '—'
                            : formatPercent(
                                quote.change24hPercent!,
                                localeName: localeName,
                              ),
                        valueColor: _changeColor(quote, context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: SectionLabel(l10n.chartRange)),
                    MarketChangeChip(
                      percent: historyState.history?.periodChangePercent,
                      localeName: localeName,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _RangeTab(
                      key: const Key('chart-range-24h'),
                      label: l10n.chart24h,
                      selected: _range == PriceHistoryRange.day,
                      onTap: () => _selectRange(PriceHistoryRange.day),
                    ),
                    _RangeTab(
                      key: const Key('chart-range-7d'),
                      label: l10n.chart7d,
                      selected: _range == PriceHistoryRange.week,
                      onTap: () => _selectRange(PriceHistoryRange.week),
                    ),
                    _RangeTab(
                      key: const Key('chart-range-30d'),
                      label: l10n.chart30d,
                      selected: _range == PriceHistoryRange.month,
                      onTap: () => _selectRange(PriceHistoryRange.month),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ChartBody(
                  quote: quote,
                  state: historyState,
                  localeName: localeName,
                  onRetry: () => unawaited(_load(forceRefresh: true)),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.selectOutputOrRow,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key('add-to-calculator-${quote.code}'),
                        onPressed: _addToCalculator,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: Text(l10n.addToCalculator),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: Key('set-as-output-${quote.code}'),
                        onPressed: _setOutput,
                        icon: const Icon(Icons.arrow_outward_rounded, size: 17),
                        label: Text(l10n.setAsOutput),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compactUsd(double? value, String localeName) {
    if (value == null || !value.isFinite) return '—';
    return '${formatCompact(value, localeName: localeName)} USD';
  }

  Color _changeColor(MarketQuote quote, BuildContext context) {
    final percent = quote.change24hPercent;
    if (percent == null || percent == 0) return context.colors.textSecondary;
    return percent > 0 ? context.colors.positive : context.colors.danger;
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.quote,
    required this.state,
    required this.localeName,
    required this.onRetry,
  });

  final MarketQuote quote;
  final MarketHistoryState state;
  final String localeName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final history = state.history;

    if (history == null) {
      return _ChartFrame(
        child: SizedBox(
          height: 220,
          child: Center(
            child: state.isLoading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.chartLoading,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        size: 26,
                        color: colors.textMuted,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        state.errorMessage == null
                            ? l10n.chartUnavailable
                            : l10n.chartError,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: state.errorMessage == null
                              ? colors.textSecondary
                              : colors.danger,
                        ),
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          state.errorMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 7),
                      TextButton.icon(
                        key: const Key('chart-retry-button'),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: Text(l10n.chartRetry),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    final usd = CurrencyCatalog.fiatCurrency('USD');
    return _ChartFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chartTitle(quote.currency.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'USD',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.textMuted, letterSpacing: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 4),
          PriceChart(history: history),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 7,
            children: [
              FactPair(
                label: l10n.high,
                value: history.highPrice == null
                    ? '—'
                    : formatAmount(
                        history.highPrice!,
                        usd,
                        localeName: localeName,
                      ),
              ),
              FactPair(
                label: l10n.low,
                value: history.lowPrice == null
                    ? '—'
                    : formatAmount(
                        history.lowPrice!,
                        usd,
                        localeName: localeName,
                      ),
              ),
              FactPair(
                label: l10n.periodChange,
                value: history.periodChangePercent == null
                    ? '—'
                    : formatPercent(
                        history.periodChangePercent!,
                        localeName: localeName,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chartUsdNote,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.textMuted, fontSize: 11),
          ),
          if (state.status.isCached) ...[
            const SizedBox(height: 7),
            NoticeBanner(
              icon: Icons.cloud_off_rounded,
              tone: NoticeTone.warning,
              message: l10n.chartCachedNote,
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 7),
            NoticeBanner(
              icon: Icons.error_outline_rounded,
              tone: NoticeTone.danger,
              message: l10n.chartError,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartFrame extends StatelessWidget {
  const _ChartFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
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
      color: selected ? colors.accentSoft : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? colors.accent.withValues(alpha: 0.4)
                  : colors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? colors.accent : colors.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetBadge extends StatelessWidget {
  const _AssetBadge({required this.quote});

  final MarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final symbol = quote.currency.symbol;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        symbol,
        maxLines: 1,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: symbol.length > 2 ? 10 : 16,
        ),
      ),
    );
  }
}

/// Opens the market sheet and returns once it closes.
Future<void> showMarketAssetSheet(
  BuildContext context, {
  required MarketQuote quote,
  required VoidCallback onAddToCalculator,
  required VoidCallback onSetOutput,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (_) => MarketAssetSheet(
      quote: quote,
      onAddToCalculator: onAddToCalculator,
      onSetOutput: onSetOutput,
    ),
  );
}
