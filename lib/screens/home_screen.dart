import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/currency.dart';
import '../providers/calculator_controller.dart';
import '../providers/markets_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/panel.dart';
import 'calculator_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'markets_screen.dart';
import 'settings_screen.dart';

/// The app shell: a compact rail on desktop and bottom navigation on phones.
///
/// Every destination owns an explicit [ScrollController]. No screen relies on
/// the shared [PrimaryScrollController], which previously made Flutter's
/// automatic desktop scrollbar attach to several scroll positions at once.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _ready = false;

  late final CalculatorController _calculator;
  late final MarketsController _markets;

  @override
  void initState() {
    super.initState();
    _calculator = context.read<CalculatorController>();
    _markets = context.read<MarketsController>();
    _markets.addListener(_syncMarketData);
    _calculator.refreshMarketData = _markets.refresh;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
    try {
      await Future.wait([
        _calculator.initialize(),
        _markets.initialize(),
      ], eagerError: false);
      _syncMarketData();
    } finally {
      final elapsed = DateTime.now().difference(started);
      const minimumSplash = Duration(milliseconds: 350);
      if (elapsed < minimumSplash) {
        await Future<void>.delayed(minimumSplash - elapsed);
      }
      if (mounted) {
        setState(() => _ready = true);
        unawaited(_calculator.refreshRatesIfStale());
        unawaited(_markets.refreshIfStale());
      }
    }
  }

  void _syncMarketData() {
    _calculator.syncMarketData(
      _markets.combinedSnapshot,
      status: _markets.combinedStatus,
      error: _markets.combinedError,
    );
  }

  @override
  void dispose() {
    _markets.removeListener(_syncMarketData);
    _calculator.refreshMarketData = null;
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  void _addCurrency(Currency currency) {
    _calculator.addRow(currency: currency, amount: '1');
    setState(() => _index = 0);
    _showMessage(context.l10n.addedCurrencyToCalculator(currency.code));
  }

  void _setOutputCurrency(Currency currency) {
    _calculator.setOutputCurrency(currency);
    setState(() => _index = 0);
    _showMessage(context.l10n.outputCurrencyChanged(currency.code));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(color: colors.background),
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: !_ready
                ? const _SplashScreen(key: ValueKey('splash'))
                : LayoutBuilder(
                    key: const ValueKey('home'),
                    builder: (context, constraints) {
                      final desktop = constraints.maxWidth >= 960;
                      if (desktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DesktopRail(
                              index: _index,
                              destinations: _destinations(context),
                              onSelected: _select,
                            ),
                            Expanded(child: _pageStack()),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          const _MobileBrandBar(),
                          Expanded(child: _pageStack()),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _ready && !isDesktop
          ? _MobileNavigation(
              index: _index,
              destinations: _destinations(context),
              onSelected: _select,
            )
          : null,
    );
  }

  Widget _pageStack() {
    return IndexedStack(
      key: const Key('page-stack'),
      index: _index,
      children: [
        const CalculatorScreen(),
        MarketsScreen(
          onAddCurrency: _addCurrency,
          onSetOutput: _setOutputCurrency,
        ),
        FavoritesScreen(
          onAddCurrency: _addCurrency,
          onSetOutput: _setOutputCurrency,
          onBrowseMarkets: () => _select(1),
        ),
        HistoryScreen(onGoToCalculator: () => _select(0)),
        const SettingsScreen(),
      ],
    );
  }

  List<_Destination> _destinations(BuildContext context) {
    final l10n = context.l10n;
    return [
      _Destination(
        key: const Key('nav-calculator'),
        icon: Icons.calculate_outlined,
        selectedIcon: Icons.calculate_rounded,
        label: l10n.navCalculator,
      ),
      _Destination(
        key: const Key('nav-markets'),
        icon: Icons.candlestick_chart_outlined,
        selectedIcon: Icons.candlestick_chart_rounded,
        label: l10n.navMarkets,
      ),
      _Destination(
        key: const Key('nav-favorites'),
        icon: Icons.star_border_rounded,
        selectedIcon: Icons.star_rounded,
        label: l10n.navFavorites,
      ),
      _Destination(
        key: const Key('nav-history'),
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_rounded,
        label: l10n.navHistory,
      ),
      _Destination(
        key: const Key('nav-settings'),
        icon: Icons.tune_rounded,
        selectedIcon: Icons.tune_rounded,
        label: l10n.navSettings,
      ),
    ];
  }
}

class _Destination {
  const _Destination({
    required this.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Key key;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.index,
    required this.destinations,
    required this.onSelected,
  });

  final int index;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final controller = context.watch<CalculatorController>();

    return Container(
      key: const Key('desktop-rail'),
      width: 232,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BrandLogo(width: 146),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SectionLabel(l10n.appName),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: _RailItem(
                        key: destinations[i].key,
                        destination: destinations[i],
                        selected: i == index,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DataStateLine(
                  hasRates: controller.hasRates,
                  cached: controller.isUsingCachedRates,
                  showLabel: true,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.versionLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.7,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.textPrimary : colors.textSecondary;
    return Material(
      color: selected ? colors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? colors.accent.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 18,
                color: selected ? colors.accent : colors.textMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBrandBar extends StatelessWidget {
  const _MobileBrandBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = context.watch<CalculatorController>();
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          const BrandLogo(width: 78),
          const Spacer(),
          _DataStateLine(
            hasRates: controller.hasRates,
            cached: controller.isUsingCachedRates,
            showLabel: true,
          ),
        ],
      ),
    );
  }
}

class _DataStateLine extends StatelessWidget {
  const _DataStateLine({
    required this.hasRates,
    required this.cached,
    required this.showLabel,
  });

  final bool hasRates;
  final bool cached;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final (color, label) = !hasRates
        ? (colors.danger, l10n.unavailable)
        : cached
        ? (colors.warning, l10n.cached)
        : (colors.positive, l10n.live);

    return Tooltip(
      message: '$label · ${l10n.ratesTitle}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: color, size: 6),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.index,
    required this.destinations,
    required this.onSelected,
  });

  final int index;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const Key('mobile-navigation'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _MobileNavItem(
                    key: destinations[i].key,
                    destination: destinations[i],
                    selected: i == index,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 25,
                decoration: BoxDecoration(
                  color: selected ? colors.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 18,
                  color: selected ? colors.accent : colors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? colors.textPrimary : colors.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(width: 220),
          const SizedBox(height: 22),
          Text(
            context.l10n.appTagline,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.textMuted, letterSpacing: 0.2),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: colors.accent,
                backgroundColor: colors.surfaceRaised,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
