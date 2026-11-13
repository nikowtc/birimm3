import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/currency.dart';
import '../models/currency_catalog.dart';
import '../models/market_data.dart';
import '../providers/calculator_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/market_pricing.dart';
import '../widgets/market_asset_sheet.dart';
import '../widgets/market_change_chip.dart';
import '../widgets/panel.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.onAddCurrency,
    required this.onSetOutput,
    required this.onBrowseMarkets,
  });

  final ValueChanged<Currency> onAddCurrency;
  final ValueChanged<Currency> onSetOutput;
  final VoidCallback onBrowseMarkets;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openCurrency(Currency currency) async {
    final controller = context.read<CalculatorController>();
    final quote = controller.quoteFor(currency.code);
    if (quote != null) {
      await showMarketAssetSheet(
        context,
        quote: quote,
        onAddToCalculator: () => widget.onAddCurrency(currency),
        onSetOutput: () => widget.onSetOutput(currency),
      );
      return;
    }

    final action = await showDialog<_FavoriteAction>(
      context: context,
      builder: (_) => _CurrencyDetailDialog(currency: currency),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FavoriteAction.add:
        widget.onAddCurrency(currency);
        break;
      case _FavoriteAction.setOutput:
        widget.onSetOutput(currency);
        break;
      case _FavoriteAction.remove:
        await controller.toggleCurrencyFavorite(currency);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();
    final l10n = context.l10n;
    final colors = context.colors;
    final localeName = l10n.localeName;
    final favorites = controller.favoriteCurrencies;
    final crypto = favorites.where((item) => item.isCrypto).toList();
    final fiat = favorites.where((item) => item.isFiat).toList();
    final priceView = marketPriceView(controller);
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 760
        ? 30.0
        : 16.0;

    return SingleChildScrollView(
      key: const Key('favorites-page'),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        24,
        horizontalPadding,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                eyebrow: l10n.appName,
                title: l10n.favoritesTitle,
                subtitle: l10n.favoritesSubtitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (favorites.isNotEmpty)
                      SoftChip(
                        label: l10n.favoriteCount(favorites.length),
                        color: colors.warning,
                        background: colors.warningSoft,
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: l10n.refreshAll,
                      onPressed: controller.isLoadingRates
                          ? null
                          : controller.refreshAllData,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (favorites.isEmpty)
                EmptyStatePanel(
                  icon: Icons.star_border_rounded,
                  title: l10n.noFavoritesTitle,
                  body: l10n.noFavoritesBody,
                  action: OutlinedButton.icon(
                    onPressed: widget.onBrowseMarkets,
                    icon: const Icon(
                      Icons.candlestick_chart_outlined,
                      size: 17,
                    ),
                    label: Text(l10n.browseMarkets),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SoftChip(
                      label: controller.isUsingCachedRates
                          ? l10n.cached
                          : l10n.live,
                      color: controller.isUsingCachedRates
                          ? colors.warning
                          : colors.positive,
                      background: controller.isUsingCachedRates
                          ? colors.warningSoft
                          : colors.positiveSoft,
                      icon: controller.isUsingCachedRates
                          ? Icons.cloud_off_rounded
                          : Icons.sensors_rounded,
                    ),
                    if (controller.ratesFetchedAt != null)
                      Text(
                        '${l10n.updated} ${formatTimestamp(controller.ratesFetchedAt, localeName: localeName)}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.textMuted, fontSize: 11),
                      ),
                    Text(
                      '· ${l10n.marketPricesInOutput}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (crypto.isNotEmpty) ...[
                  _FavoriteGroup(
                    title: l10n.cryptoAssets,
                    icon: Icons.toll_rounded,
                    children: [
                      for (final currency in crypto)
                        _CryptoFavoriteRow(
                          currency: currency,
                          quote: controller.quoteFor(currency.code),
                          priceView: priceView,
                          localeName: localeName,
                          onTap: () => _openCurrency(currency),
                          onAdd: () => widget.onAddCurrency(currency),
                          onRemove: () =>
                              controller.toggleCurrencyFavorite(currency),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                if (fiat.isNotEmpty)
                  _FavoriteGroup(
                    title: l10n.fiatCurrencies,
                    icon: Icons.language_rounded,
                    children: [
                      for (final currency in fiat)
                        _FiatFavoriteRow(
                          currency: currency,
                          outputCurrency: controller.outputCurrency,
                          rate: controller.conversionRate(
                            currency.code,
                            controller.outputCurrency.code,
                          ),
                          localeName: localeName,
                          onTap: () => _openCurrency(currency),
                          onAdd: () => widget.onAddCurrency(currency),
                          onRemove: () =>
                              controller.toggleCurrencyFavorite(currency),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        l10n.favoritePricesNote,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.textMuted, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteGroup extends StatelessWidget {
  const _FavoriteGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Row(
              children: [
                Icon(icon, size: 14, color: colors.textMuted),
                const SizedBox(width: 7),
                SectionLabel(title),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.border),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _CryptoFavoriteRow extends StatelessWidget {
  const _CryptoFavoriteRow({
    required this.currency,
    required this.quote,
    required this.priceView,
    required this.localeName,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  final Currency currency;
  final MarketQuote? quote;
  final MarketPriceView priceView;
  final String localeName;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final usdPrice = quote?.usdPrice;
    final change = quote?.change24hPercent;
    final price = usdPrice == null ? null : priceView.priceFor(usdPrice);

    return _FavoriteRowShell(
      code: currency.code,
      symbol: currency.symbol,
      name: currency.name,
      isCrypto: true,
      onTap: onTap,
      onAdd: onAdd,
      onRemove: onRemove,
      priceLine: price == null
          ? null
          : formatAmount(price, priceView.currency, localeName: localeName),
      codeLabel: price == null ? null : priceView.currency.code,
      secondary: price == null
          ? Text(
              l10n.noMarketQuote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.warning, fontSize: 11),
            )
          : MarketChangeChip(percent: change, localeName: localeName),
    );
  }
}

class _FiatFavoriteRow extends StatelessWidget {
  const _FiatFavoriteRow({
    required this.currency,
    required this.outputCurrency,
    required this.rate,
    required this.localeName,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  final Currency currency;
  final Currency outputCurrency;
  final double? rate;
  final String localeName;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return _FavoriteRowShell(
      code: currency.code,
      symbol: currency.symbol,
      name: currency.name,
      isCrypto: false,
      onTap: onTap,
      onAdd: onAdd,
      onRemove: onRemove,
      priceLine: rate == null
          ? null
          : formatUnitRate(rate!, localeName: localeName),
      codeLabel: rate == null ? null : '${outputCurrency.code} · ${l10n.rate}',
      secondary: Text(
        rate == null
            ? l10n.noRate
            : '1 ${currency.code} = '
                  '${formatUnitRate(rate!, localeName: localeName)} '
                  '${outputCurrency.code}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: rate == null ? colors.warning : colors.textMuted,
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _FavoriteRowShell extends StatelessWidget {
  const _FavoriteRowShell({
    required this.code,
    required this.symbol,
    required this.name,
    required this.isCrypto,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
    required this.priceLine,
    required this.codeLabel,
    required this.secondary,
  });

  final String code;
  final String symbol;
  final String name;
  final bool isCrypto;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String? priceLine;
  final String? codeLabel;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('favorite-row-$code'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  symbol,
                  maxLines: 1,
                  style: TextStyle(
                    color: isCrypto ? colors.warning : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: symbol.length > 2 ? 9 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          code,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.textMuted,
                                letterSpacing: 0.5,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    secondary,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (priceLine != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priceLine!,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (codeLabel != null)
                      Text(
                        codeLabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textMuted,
                          letterSpacing: 0.35,
                          fontSize: 8,
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 2),
              IconButton(
                key: Key('favorite-add-$code'),
                tooltip: l10n.addToCalculator,
                onPressed: onAdd,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ),
              IconButton(
                key: Key('remove-favorite-$code'),
                tooltip: l10n.removeFromFavorites,
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.star_rounded, size: 18, color: colors.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FavoriteAction { add, setOutput, remove }

class _CurrencyDetailDialog extends StatelessWidget {
  const _CurrencyDetailDialog({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CalculatorController>();
    final l10n = context.l10n;
    final colors = context.colors;
    final localeName = l10n.localeName;
    final output = controller.outputCurrency;
    final direct = controller.conversionRate(currency.code, output.code);
    final inverse = controller.conversionRate(output.code, currency.code);
    final quote = controller.quoteFor(currency.code);
    final isFavorite = controller.isCurrencyFavorite(currency.code);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              currency.symbol,
              style: TextStyle(
                color: currency.isCrypto ? colors.warning : colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: currency.symbol.length > 2 ? 9 : 14,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${currency.code} · '
                  '${currency.isCrypto ? l10n.crypto : l10n.fiat}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SingleChildScrollView(
        primary: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (direct != null) ...[
                    Text(
                      '1 ${currency.code} = '
                      '${formatUnitRate(direct, localeName: localeName)} '
                      '${output.code}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (inverse != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '1 ${output.code} = '
                        '${formatUnitRate(inverse, localeName: localeName)} '
                        '${currency.code}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      l10n.noRate,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.warning),
                    ),
                  if (quote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.price}: '
                      '${formatAmount(quote.usdPrice, CurrencyCatalog.fiatCurrency('USD'), localeName: localeName)} USD',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_FavoriteAction.add),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(l10n.addToCalculator),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(_FavoriteAction.setOutput),
              icon: const Icon(Icons.arrow_outward_rounded, size: 17),
              label: Text(l10n.setAsOutput),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(_FavoriteAction.remove),
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                size: 17,
                color: colors.warning,
              ),
              label: Text(
                isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
