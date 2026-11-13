import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../logic/asset_search.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';

Future<Currency?> showCurrencyPicker(
  BuildContext context, {
  required List<Currency> currencies,
  required Currency selected,
  required String title,
  List<String> favoriteCodes = const [],
  Future<bool> Function(Currency currency)? onFavoriteToggle,
}) {
  return showDialog<Currency>(
    context: context,
    builder: (context) => CurrencyPickerDialog(
      currencies: currencies,
      selected: selected,
      title: title,
      favoriteCodes: favoriteCodes,
      onFavoriteToggle: onFavoriteToggle,
    ),
  );
}

class CurrencyPickerDialog extends StatefulWidget {
  const CurrencyPickerDialog({
    super.key,
    required this.currencies,
    required this.selected,
    required this.title,
    this.favoriteCodes = const [],
    this.onFavoriteToggle,
  });

  final List<Currency> currencies;
  final Currency selected;
  final String title;
  final List<String> favoriteCodes;
  final Future<bool> Function(Currency currency)? onFavoriteToggle;

  @override
  State<CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<CurrencyPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _favoriteCodes = {
    for (final code in widget.favoriteCodes) code.toUpperCase(),
  };
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(Currency currency) async {
    final callback = widget.onFavoriteToggle;
    if (callback == null) return;
    final isFavorite = await callback(currency);
    if (!mounted) return;
    setState(() {
      final code = currency.code.toUpperCase();
      if (isFavorite) {
        _favoriteCodes.add(code);
      } else {
        _favoriteCodes.remove(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final width = math.min(480.0, size.width - 32);
    final height = math.min(
      620.0,
      math.max(260.0, size.height - keyboardInset - 48),
    );

    final searchable = _favoritesOnly
        ? widget.currencies
              .where(
                (currency) =>
                    _favoriteCodes.contains(currency.code.toUpperCase()),
              )
              .toList(growable: false)
        : widget.currencies;
    final matches = searchCurrencies(
      searchable,
      _query,
      languageCode: l10n.locale.languageCode,
      favoriteCodes: _favoriteCodes,
    );
    final groups = <CurrencyKind, List<Currency>>{};
    for (final currency in matches) {
      groups.putIfAbsent(currency.kind, () => []).add(currency);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.searchByHint,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('currency-search-field'),
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.searchCurrenciesHint,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.clearSearch,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      ),
                    ),
                  ),
                  if (widget.onFavoriteToggle != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      key: const Key('favorites-filter-button'),
                      tooltip: _favoritesOnly
                          ? l10n.favoritesTitle
                          : l10n.addToFavorites,
                      isSelected: _favoritesOnly,
                      onPressed: () =>
                          setState(() => _favoritesOnly = !_favoritesOnly),
                      icon: Icon(
                        _favoritesOnly
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _favoritesOnly
                            ? colors.accentSoft
                            : null,
                        foregroundColor: _favoritesOnly
                            ? colors.warning
                            : colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Expanded(
              child: matches.isEmpty
                  ? _EmptySearch(query: _query, favoritesOnly: _favoritesOnly)
                  : ListView(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      children: [
                        for (final kind in _groupOrder)
                          if (groups[kind]?.isNotEmpty ?? false) ...[
                            _GroupLabel(_groupLabel(l10n, kind)),
                            for (final currency in groups[kind]!)
                              _CurrencyRow(
                                currency: currency,
                                selected: currency == widget.selected,
                                favorite: _favoriteCodes.contains(
                                  currency.code,
                                ),
                                showFavorite:
                                    widget.onFavoriteToggle != null,
                                kindLabel: _kindLabel(l10n, currency),
                                onFavorite: () => _toggleFavorite(currency),
                                onTap: () =>
                                    Navigator.of(context).pop(currency),
                              ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<CurrencyKind> _groupOrder = [
    CurrencyKind.fiat,
    CurrencyKind.crypto,
    CurrencyKind.stock,
    CurrencyKind.marketIndex,
    CurrencyKind.metal,
  ];

  String _groupLabel(AppLocalizations l10n, CurrencyKind kind) {
    return switch (kind) {
      CurrencyKind.fiat => l10n.fiatCurrencies,
      CurrencyKind.crypto => l10n.cryptoAssets,
      CurrencyKind.stock => l10n.stockAssets,
      CurrencyKind.marketIndex => l10n.indexAssets,
      CurrencyKind.metal => l10n.metalAssets,
    };
  }

  String _kindLabel(AppLocalizations l10n, Currency currency) {
    return switch (currency.kind) {
      CurrencyKind.fiat => l10n.fiat,
      CurrencyKind.crypto => l10n.crypto,
      CurrencyKind.stock => l10n.stocks,
      CurrencyKind.marketIndex => l10n.indices,
      CurrencyKind.metal => l10n.metals,
    };
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: context.colors.textMuted, letterSpacing: 1.2),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.currency,
    required this.selected,
    required this.favorite,
    required this.showFavorite,
    required this.kindLabel,
    required this.onFavorite,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final bool favorite;
  final bool showFavorite;
  final String kindLabel;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          key: Key('currency-option-${currency.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (currency.kind) {
                      CurrencyKind.crypto => colors.warningSoft,
                      CurrencyKind.metal => colors.warningSoft,
                      CurrencyKind.stock => colors.accentSoft,
                      CurrencyKind.marketIndex => colors.accentSoft,
                      CurrencyKind.fiat => colors.surfaceRaised,
                    },
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currency.symbol,
                    maxLines: 1,
                    style: TextStyle(
                      color: switch (currency.kind) {
                        CurrencyKind.crypto ||
                        CurrencyKind.metal => colors.warning,
                        CurrencyKind.stock ||
                        CurrencyKind.marketIndex => colors.accent,
                        CurrencyKind.fiat => colors.textPrimary,
                      },
                      fontSize: currency.symbol.length > 2 ? 9 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              currency.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            kindLabel.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: switch (currency.kind) {
                                    CurrencyKind.crypto ||
                                    CurrencyKind.metal => colors.warning,
                                    CurrencyKind.stock ||
                                    CurrencyKind.marketIndex => colors.accent,
                                    CurrencyKind.fiat => colors.textMuted,
                                  },
                                  fontSize: 8.5,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.localizedName(l10n.locale.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (showFavorite)
                  IconButton(
                    key: Key('favorite-currency-${currency.code}'),
                    tooltip: favorite
                        ? l10n.removeFromFavorites
                        : l10n.addToFavorites,
                    visualDensity: VisualDensity.compact,
                    onPressed: onFavorite,
                    icon: Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 19,
                      color: favorite ? colors.warning : colors.textMuted,
                    ),
                  ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 19,
                    color: colors.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query, required this.favoritesOnly});

  final String query;
  final bool favoritesOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: colors.textMuted, size: 30),
            const SizedBox(height: 10),
            Text(
              favoritesOnly && query.trim().isEmpty
                  ? l10n.noFavoriteCurrencies
                  : l10n.noCurrencyMatches(query),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            if (query.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.tryAnotherSearch,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
