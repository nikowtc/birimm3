import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/currency.dart';
import '../models/currency_catalog.dart';
import '../models/market_data.dart';
import '../models/rate_status.dart';
import '../providers/calculator_controller.dart';
import '../providers/markets_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/market_pricing.dart';
import '../widgets/currency_picker_dialog.dart';
import '../widgets/market_asset_sheet.dart';
import '../widgets/market_change_chip.dart';
import '../widgets/panel.dart';

enum _MarketTab { crypto, fiat }

enum _CryptoFilter { all, popular, top100, gainers, losers, favorites }

enum _MarketSort { marketCap, price, change, name }

/// Crypto + fiat market overview with paged CoinGecko data and persisted cache.
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({
    super.key,
    required this.onAddCurrency,
    required this.onSetOutput,
  });

  final ValueChanged<Currency> onAddCurrency;
  final ValueChanged<Currency> onSetOutput;

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fiatSearchController = TextEditingController();

  _MarketTab _tab = _MarketTab.crypto;
  _CryptoFilter _filter = _CryptoFilter.all;
  _MarketSort _sort = _MarketSort.marketCap;
  bool _ascending = false;
  String _query = '';
  String _fiatQuery = '';
  String? _referenceCode;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _fiatSearchController.dispose();
    super.dispose();
  }

  void _clearCryptoSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _clearFiatSearch() {
    _fiatSearchController.clear();
    setState(() => _fiatQuery = '');
  }

  void _selectSort(_MarketSort sort) {
    setState(() {
      _sort = sort;
      _ascending = sort == _MarketSort.name;
    });
  }

  Future<void> _openAsset(MarketQuote quote) async {
    await showMarketAssetSheet(
      context,
      quote: quote,
      onAddToCalculator: () => widget.onAddCurrency(quote.currency),
      onSetOutput: () => widget.onSetOutput(quote.currency),
    );
  }

  Future<void> _pickReference(List<Currency> fiatCurrencies) async {
    final controller = context.read<CalculatorController>();
    final selected = await showCurrencyPicker(
      context,
      currencies: fiatCurrencies,
      selected: _resolvedReference(controller),
      title: context.l10n.selectReference,
      favoriteCodes: [
        for (final currency in controller.favoriteCurrencies) currency.code,
      ],
      onFavoriteToggle: controller.toggleCurrencyFavorite,
    );
    if (!mounted || selected == null) return;
    setState(() => _referenceCode = selected.code);
  }

  Currency _resolvedReference(CalculatorController controller) {
    final units = controller.rateBundle?.fiatUnitsPerUsd ?? const {};
    final candidates = <String?>[
      _referenceCode,
      if (controller.outputCurrency.isFiat) controller.outputCurrency.code,
      'USD',
    ];
    for (final code in candidates) {
      if (code != null && units.containsKey(code)) {
        return controller.currencyByCode(code) ??
            CurrencyCatalog.fiatCurrency(code);
      }
    }
    if (units.isNotEmpty) {
      final code = units.keys.first;
      return controller.currencyByCode(code) ??
          CurrencyCatalog.fiatCurrency(code);
    }
    return CurrencyCatalog.fiatCurrency('USD');
  }

  @override
  Widget build(BuildContext context) {
    final markets = context.watch<MarketsController>();
    final calculator = context.watch<CalculatorController>();
    final l10n = context.l10n;
    final colors = context.colors;
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 760
        ? 30.0
        : 16.0;
    final refreshing = _tab == _MarketTab.crypto
        ? markets.isLoading
        : calculator.isLoadingRates;

    return SingleChildScrollView(
      key: const Key('markets-page'),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        24,
        horizontalPadding,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                eyebrow: l10n.appName,
                title: l10n.marketsTitle,
                subtitle: l10n.marketsSubtitle,
                trailing: IconButton(
                  key: const Key('market-refresh-button'),
                  tooltip: l10n.refreshAll,
                  onPressed: refreshing ? null : calculator.refreshAllData,
                  icon: refreshing
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
              const SizedBox(height: 18),
              Row(
                children: [
                  SegmentedControl<_MarketTab>(
                    values: const [_MarketTab.crypto, _MarketTab.fiat],
                    labels: [l10n.cryptoMarkets, l10n.fiatMarkets],
                    icons: const [Icons.toll_rounded, Icons.language_rounded],
                    selected: _tab,
                    onChanged: (value) => setState(() => _tab = value),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (_tab == _MarketTab.crypto)
                _buildCrypto(context, markets, calculator)
              else
                _buildFiat(context, calculator),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrypto(
    BuildContext context,
    MarketsController markets,
    CalculatorController calculator,
  ) {
    final l10n = context.l10n;
    final colors = context.colors;
    final localeName = l10n.localeName;
    final priceView = marketPriceView(calculator);
    final quotes = markets.quotes;
    final normalized = _query.trim().toLowerCase();

    final ranked = <(int, MarketQuote)>[
      for (var index = 0; index < quotes.length; index++)
        (index + 1, quotes[index]),
    ];
    final filtered = ranked
        .where((entry) {
          final (rank, quote) = entry;
          if (_filter == _CryptoFilter.popular && rank > 25) return false;
          if (_filter == _CryptoFilter.top100 && rank > 100) return false;
          if (_filter == _CryptoFilter.gainers &&
              (quote.change24hPercent == null ||
                  quote.change24hPercent! <= 0)) {
            return false;
          }
          if (_filter == _CryptoFilter.losers &&
              (quote.change24hPercent == null ||
                  quote.change24hPercent! >= 0)) {
            return false;
          }
          if (_filter == _CryptoFilter.favorites &&
              !calculator.isCurrencyFavorite(quote.code)) {
            return false;
          }
          if (normalized.isEmpty) return true;
          return quote.code.toLowerCase().contains(normalized) ||
              quote.currency.name.toLowerCase().contains(normalized) ||
              quote.currency.symbol.toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      final quoteA = a.$2;
      final quoteB = b.$2;
      final result = switch (_sort) {
        _MarketSort.marketCap => _compareNullable(
          quoteA.marketCapUsd,
          quoteB.marketCapUsd,
        ),
        _MarketSort.price => quoteA.usdPrice.compareTo(quoteB.usdPrice),
        _MarketSort.change => _compareNullable(
          quoteA.change24hPercent,
          quoteB.change24hPercent,
        ),
        _MarketSort.name => quoteA.currency.name.toLowerCase().compareTo(
          quoteB.currency.name.toLowerCase(),
        ),
      };
      return _ascending ? result : -result;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          padding: const EdgeInsets.all(11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                key: const Key('market-search-field'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  hintText: l10n.searchAssetsHint,
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          onPressed: _clearCryptoSearch,
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                ),
              );
              final controls = Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FilterButton(
                    key: const Key('market-filter-all'),
                    label: l10n.filterAll,
                    selected: _filter == _CryptoFilter.all,
                    onTap: () => setState(() => _filter = _CryptoFilter.all),
                  ),
                  _FilterButton(
                    key: const Key('market-filter-popular'),
                    label: l10n.filterPopular,
                    selected: _filter == _CryptoFilter.popular,
                    onTap: () =>
                        setState(() => _filter = _CryptoFilter.popular),
                  ),
                  _FilterButton(
                    key: const Key('market-filter-top100'),
                    label: l10n.filterTop100,
                    selected: _filter == _CryptoFilter.top100,
                    onTap: () => setState(() => _filter = _CryptoFilter.top100),
                  ),
                  _FilterButton(
                    key: const Key('market-filter-gainers'),
                    label: l10n.filterGainers,
                    selected: _filter == _CryptoFilter.gainers,
                    onTap: () =>
                        setState(() => _filter = _CryptoFilter.gainers),
                  ),
                  _FilterButton(
                    key: const Key('market-filter-losers'),
                    label: l10n.filterLosers,
                    selected: _filter == _CryptoFilter.losers,
                    onTap: () => setState(() => _filter = _CryptoFilter.losers),
                  ),
                  _FilterButton(
                    key: const Key('market-filter-favorites'),
                    label: l10n.filterFavorites,
                    icon: Icons.star_rounded,
                    selected: _filter == _CryptoFilter.favorites,
                    onTap: () =>
                        setState(() => _filter = _CryptoFilter.favorites),
                  ),
                  _SortMenu(
                    sort: _sort,
                    ascending: _ascending,
                    onSort: _selectSort,
                    onDirection: () => setState(() => _ascending = !_ascending),
                  ),
                ],
              );
              if (constraints.maxWidth < 1060) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 9), controls],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.78,
                    ),
                    child: controls,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 9,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SoftChip(
              label: l10n.assetsLoaded(markets.loadedQuoteCount),
              color: colors.textSecondary,
              background: colors.surfaceMuted,
            ),
            SoftChip(
              label: _originLabel(context, markets.status),
              color: _originColor(colors, markets.status),
              background: _originBackground(colors, markets.status),
              icon: markets.status.isCached
                  ? Icons.cloud_off_rounded
                  : Icons.sensors_rounded,
            ),
            if (markets.fetchedAt != null)
              Text(
                '${l10n.updated} ${formatTimestamp(markets.fetchedAt, localeName: localeName)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.textMuted, fontSize: 11),
              ),
            Text(
              '· ${priceView.isUsdFallback ? l10n.marketPricesInUsd : l10n.marketPricesInOutput}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
        if (normalized.isNotEmpty && markets.hasMore) ...[
          const SizedBox(height: 8),
          NoticeBanner(
            icon: Icons.search_rounded,
            message: l10n.searchLoadedOnly(markets.loadedQuoteCount),
          ),
        ],
        if (markets.isUsingCachedData && markets.fetchedAt != null) ...[
          const SizedBox(height: 9),
          NoticeBanner(
            icon: Icons.cloud_off_rounded,
            tone: NoticeTone.warning,
            message: l10n.marketCachedNote(
              formatTimestamp(markets.fetchedAt, localeName: localeName),
            ),
          ),
        ],
        if (markets.errorMessage != null && quotes.isNotEmpty) ...[
          const SizedBox(height: 9),
          NoticeBanner(
            icon: Icons.error_outline_rounded,
            tone: NoticeTone.danger,
            message: l10n.marketRefreshError,
            detail: markets.errorMessage,
          ),
        ],
        if (priceView.isUsdFallback) ...[
          const SizedBox(height: 9),
          NoticeBanner(
            icon: Icons.currency_exchange_rounded,
            tone: NoticeTone.warning,
            message: l10n.marketPricesInUsd,
          ),
        ],
        const SizedBox(height: 12),
        if (quotes.isEmpty)
          _CryptoEmpty(
            isLoading: markets.isLoading,
            errorMessage: markets.errorMessage,
            onRetry: markets.refresh,
          )
        else if (filtered.isEmpty)
          EmptyStatePanel(
            icon: _filter == _CryptoFilter.favorites
                ? Icons.star_border_rounded
                : Icons.search_off_rounded,
            title: _filter == _CryptoFilter.favorites && normalized.isEmpty
                ? l10n.noFavoriteAssets
                : l10n.noMarketMatches,
            body: l10n.filterNoResults,
            action: _filter == _CryptoFilter.all
                ? null
                : TextButton(
                    onPressed: () =>
                        setState(() => _filter = _CryptoFilter.all),
                    child: Text(l10n.filterAll),
                  ),
          )
        else
          AppPanel(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 690;
                return Column(
                  children: [
                    if (wide) ...[
                      _CryptoTableHeader(l10n: l10n),
                      Divider(height: 1, color: colors.border),
                    ],
                    for (var index = 0; index < filtered.length; index++) ...[
                      if (index > 0) Divider(height: 1, color: colors.border),
                      _CryptoRow(
                        rank: filtered[index].$1,
                        quote: filtered[index].$2,
                        priceView: priceView,
                        localeName: localeName,
                        favorite: calculator.isCurrencyFavorite(
                          filtered[index].$2.code,
                        ),
                        wide: wide,
                        onTap: () => _openAsset(filtered[index].$2),
                        onToggleFavorite: () {
                          unawaited(
                            calculator.toggleCurrencyFavorite(
                              filtered[index].$2.currency,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        if (quotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (markets.hasMore)
                OutlinedButton.icon(
                  key: const Key('market-load-more'),
                  onPressed: markets.isLoadingMore
                      ? null
                      : () => unawaited(markets.loadMore()),
                  icon: markets.isLoadingMore
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded, size: 17),
                  label: Text(
                    markets.isLoadingMore ? l10n.loadingMore : l10n.loadMore,
                  ),
                ),
              const Spacer(),
              Text(
                l10n.marketsDataBy,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontSize: 9,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            l10n.marketDataDisclaimer,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.textMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildFiat(BuildContext context, CalculatorController controller) {
    final l10n = context.l10n;
    final colors = context.colors;
    final localeName = l10n.localeName;
    final units = controller.rateBundle?.fiatUnitsPerUsd ?? const {};
    final reference = _resolvedReference(controller);
    final referenceRate = units[reference.code];

    final currencies = <Currency>[
      for (final code in units.keys)
        controller.currencyByCode(code) ?? CurrencyCatalog.fiatCurrency(code),
    ];
    currencies.sort((a, b) {
      const priority = ['USD', 'EUR', 'GBP', 'TRY', 'JPY', 'CHF'];
      final indexA = priority.indexOf(a.code);
      final indexB = priority.indexOf(b.code);
      final rankA = indexA < 0 ? priority.length : indexA;
      final rankB = indexB < 0 ? priority.length : indexB;
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.code.compareTo(b.code);
    });

    final normalized = _fiatQuery.trim().toLowerCase();
    final filtered = currencies
        .where((currency) {
          if (normalized.isEmpty) return true;
          return currency.code.toLowerCase().contains(normalized) ||
              currency.name.toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    if (units.isEmpty || referenceRate == null || referenceRate <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyStatePanel(
            icon: Icons.language_rounded,
            title: l10n.noFiatRates,
            body: l10n.ratesUnavailable,
            action: OutlinedButton.icon(
              onPressed: controller.refreshAllData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(l10n.retry),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          padding: const EdgeInsets.all(11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                key: const Key('fiat-search-field'),
                controller: _fiatSearchController,
                onChanged: (value) => setState(() => _fiatQuery = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  hintText: l10n.searchFiatHint,
                  isDense: true,
                  suffixIcon: _fiatQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          onPressed: _clearFiatSearch,
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                ),
              );
              final referencePicker = OutlinedButton.icon(
                key: const Key('fiat-reference-button'),
                onPressed: () => _pickReference(currencies),
                icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                label: Text('${l10n.referenceCurrency}: ${reference.code}'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: referencePicker,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  referencePicker,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 9,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SoftChip(
              label: l10n.currenciesLoaded(currencies.length),
              color: colors.textSecondary,
              background: colors.surfaceMuted,
            ),
            SoftChip(
              label: _originLabel(context, controller.fiatStatus),
              color: _originColor(colors, controller.fiatStatus),
              background: _originBackground(colors, controller.fiatStatus),
              icon: controller.fiatStatus.isCached
                  ? Icons.cloud_off_rounded
                  : Icons.sensors_rounded,
            ),
            Text(
              '· ${l10n.fiatMarketStatus}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 9),
        NoticeBanner(
          icon: Icons.info_outline_rounded,
          message: l10n.fiatReferenceNote(reference.code),
          detail: l10n.fiatRateListNote,
        ),
        if (controller.fiatStatus.isCached) ...[
          const SizedBox(height: 9),
          NoticeBanner(
            icon: Icons.cloud_off_rounded,
            tone: NoticeTone.warning,
            message: controller.fiatStatus.updatedAt == null
                ? l10n.marketsTitle
                : l10n.marketCachedNote(
                    formatTimestamp(
                      controller.fiatStatus.updatedAt,
                      localeName: localeName,
                    ),
                  ),
          ),
        ],
        const SizedBox(height: 12),
        AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < filtered.length; index++) ...[
                if (index > 0) Divider(height: 1, color: colors.border),
                _FiatRow(
                  currency: filtered[index],
                  reference: reference,
                  valuePerReference:
                      (units[filtered[index].code] ?? 0) / referenceRate,
                  localeName: localeName,
                  favorite: controller.isCurrencyFavorite(filtered[index].code),
                  onAdd: () => widget.onAddCurrency(filtered[index]),
                  onToggleFavorite: () {
                    unawaited(
                      controller.toggleCurrencyFavorite(filtered[index]),
                    );
                  },
                ),
              ],
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    l10n.noCurrencyMatches(_fiatQuery),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Text(
          l10n.marketDataDisclaimer,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  String _originLabel(BuildContext context, RateOriginInfo status) {
    final l10n = context.l10n;
    return status.isLive
        ? l10n.live
        : status.isCached
        ? l10n.cached
        : l10n.unavailable;
  }

  Color _originColor(AppColors colors, RateOriginInfo status) {
    return status.isLive
        ? colors.positive
        : status.isCached
        ? colors.warning
        : colors.danger;
  }

  Color _originBackground(AppColors colors, RateOriginInfo status) {
    return status.isLive
        ? colors.positiveSoft
        : status.isCached
        ? colors.warningSoft
        : colors.dangerSoft;
  }

  static int _compareNullable(double? a, double? b) {
    final left = a ?? double.negativeInfinity;
    final right = b ?? double.negativeInfinity;
    return left.compareTo(right);
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? colors.accent.withValues(alpha: 0.35)
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected ? colors.warning : colors.textMuted,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colors.textPrimary : colors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onDirection,
  });

  final _MarketSort sort;
  final bool ascending;
  final ValueChanged<_MarketSort> onSort;
  final VoidCallback onDirection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final label = switch (sort) {
      _MarketSort.marketCap => l10n.sortMarketCap,
      _MarketSort.price => l10n.sortPrice,
      _MarketSort.change => l10n.sortChange,
      _MarketSort.name => l10n.sortName,
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<_MarketSort>(
            key: const Key('market-sort-button'),
            tooltip: l10n.sortBy,
            onSelected: onSort,
            itemBuilder: (context) => [
              for (final value in _MarketSort.values)
                CheckedPopupMenuItem<_MarketSort>(
                  value: value,
                  checked: sort == value,
                  child: Text(switch (value) {
                    _MarketSort.marketCap => l10n.sortMarketCap,
                    _MarketSort.price => l10n.sortPrice,
                    _MarketSort.change => l10n.sortChange,
                    _MarketSort.name => l10n.sortName,
                  }),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 5, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 14,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 19, color: colors.border),
          IconButton(
            key: const Key('market-sort-direction'),
            tooltip: ascending ? l10n.ascending : l10n.descending,
            onPressed: onDirection,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CryptoTableHeader extends StatelessWidget {
  const _CryptoTableHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colors.textMuted, fontSize: 9, letterSpacing: 0.8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 9, 8, 9),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('#', style: style)),
          const SizedBox(width: 43),
          Expanded(child: Text(l10n.cryptoAssets.toUpperCase(), style: style)),
          SizedBox(
            width: 138,
            child: Text(
              l10n.price.toUpperCase(),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              l10n.change24h.toUpperCase(),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          SizedBox(
            width: 112,
            child: Text(
              l10n.marketCap.toUpperCase(),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _CryptoRow extends StatelessWidget {
  const _CryptoRow({
    required this.rank,
    required this.quote,
    required this.priceView,
    required this.localeName,
    required this.favorite,
    required this.wide,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final int rank;
  final MarketQuote quote;
  final MarketPriceView priceView;
  final String localeName;
  final bool favorite;
  final bool wide;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final price = priceView.priceFor(quote.usdPrice);
    final symbol = quote.currency.symbol;

    final asset = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            symbol,
            maxLines: 1,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: symbol.length > 2 ? 8 : 12,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                quote.currency.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                quote.code,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final priceBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatAmount(price, priceView.currency, localeName: localeName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          priceView.currency.code,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textMuted,
            fontSize: 8,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('market-asset-${quote.code}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 9, 6, 9),
          child: wide
              ? Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$rank',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textMuted,
                          fontSize: 9,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(child: asset),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 138,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: priceBlock,
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: MarketChangeChip(
                          percent: quote.change24hPercent,
                          localeName: localeName,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      child: Text(
                        quote.marketCapUsd == null
                            ? '—'
                            : formatCompact(
                                quote.marketCapUsd!,
                                localeName: localeName,
                              ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      child: IconButton(
                        key: Key('favorite-market-${quote.code}'),
                        tooltip: favorite
                            ? l10n.removeFromFavorites
                            : l10n.addToFavorites,
                        onPressed: onToggleFavorite,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 17,
                          color: favorite ? colors.warning : colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$rank',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textMuted,
                          fontSize: 8,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(child: asset),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        priceBlock,
                        const SizedBox(height: 2),
                        MarketChangeChip(
                          percent: quote.change24hPercent,
                          localeName: localeName,
                        ),
                      ],
                    ),
                    IconButton(
                      key: Key('favorite-market-${quote.code}'),
                      tooltip: favorite
                          ? l10n.removeFromFavorites
                          : l10n.addToFavorites,
                      onPressed: onToggleFavorite,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 17,
                        color: favorite ? colors.warning : colors.textMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FiatRow extends StatelessWidget {
  const _FiatRow({
    required this.currency,
    required this.reference,
    required this.valuePerReference,
    required this.localeName,
    required this.favorite,
    required this.onAdd,
    required this.onToggleFavorite,
  });

  final Currency currency;
  final Currency reference;
  final double valuePerReference;
  final String localeName;
  final bool favorite;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final inverse = valuePerReference > 0 ? 1 / valuePerReference : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 9, 6, 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              currency.symbol,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: currency.symbol.length > 2 ? 8 : 12,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  currency.code,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.referenceEquivalent(
                  formatUnitRate(valuePerReference, localeName: localeName),
                  reference.code,
                  currency.code,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (inverse != null)
                Text(
                  l10n.inverseEquivalent(
                    formatUnitRate(inverse, localeName: localeName),
                    currency.code,
                    reference.code,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 2),
          IconButton(
            key: Key('fiat-add-${currency.code}'),
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
            key: Key('fiat-star-${currency.code}'),
            tooltip: favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
            onPressed: onToggleFavorite,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              favorite ? Icons.star_rounded : Icons.star_border_rounded,
              size: 17,
              color: favorite ? colors.warning : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CryptoEmpty extends StatelessWidget {
  const _CryptoEmpty({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    if (isLoading) {
      return AppPanel(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.loading,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      );
    }
    return EmptyStatePanel(
      icon: Icons.candlestick_chart_outlined,
      title: errorMessage == null
          ? l10n.marketEmpty
          : l10n.marketUnavailableTitle,
      body: errorMessage == null
          ? l10n.marketDataDisclaimer
          : '${l10n.marketUnavailableBody}\n\n$errorMessage',
      action: OutlinedButton.icon(
        key: const Key('market-retry-button'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 17),
        label: Text(l10n.retry),
      ),
    );
  }
}
