import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/calculation_history.dart';
import '../models/calculation_row.dart';
import '../models/currency_catalog.dart';
import '../models/rate_status.dart';
import '../providers/calculator_controller.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../widgets/panel.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onGoToCalculator});

  final VoidCallback onGoToCalculator;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openEntry(CalculationHistoryEntry entry) async {
    final action = await showDialog<_HistoryAction>(
      context: context,
      builder: (_) => _HistoryDetailDialog(entry: entry),
    );
    if (!mounted || action == null) return;
    final controller = context.read<CalculatorController>();
    final l10n = context.l10n;
    switch (action) {
      case _HistoryAction.restore:
        controller.restoreHistory(entry);
        widget.onGoToCalculator();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.restoredToCalculator)));
        break;
      case _HistoryAction.delete:
        await controller.removeHistoryEntry(entry.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.entryDeleted)));
        break;
    }
  }

  Future<void> _clearHistory() async {
    final controller = context.read<CalculatorController>();
    final l10n = context.l10n;
    final count = controller.history.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearHistoryTitle),
        content: Text(l10n.clearHistoryBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-clear-history'),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clearHistoryConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.historyCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();
    final l10n = context.l10n;
    final colors = context.colors;
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 760
        ? 30.0
        : 16.0;
    final entries = controller.history;

    return SingleChildScrollView(
      key: const Key('history-page'),
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
                title: l10n.historyTitle,
                subtitle: l10n.historySubtitle,
                trailing: entries.isEmpty
                    ? null
                    : Wrap(
                        spacing: 6,
                        children: [
                          SoftChip(
                            label: l10n.historyEntries(entries.length),
                            color: colors.textSecondary,
                            background: colors.surfaceMuted,
                          ),
                          IconButton(
                            key: const Key('history-clear-button'),
                            tooltip: l10n.clearHistory,
                            onPressed: _clearHistory,
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              if (controller.persistenceError != null) ...[
                NoticeBanner(
                  icon: Icons.save_outlined,
                  tone: NoticeTone.warning,
                  message: localizePersistenceMessage(
                    l10n,
                    controller.persistenceError!,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (entries.isEmpty)
                EmptyStatePanel(
                  icon: Icons.history_rounded,
                  title: l10n.historyEmptyTitle,
                  body: l10n.historyEmptyBody,
                  action: FilledButton.icon(
                    onPressed: widget.onGoToCalculator,
                    icon: const Icon(Icons.calculate_outlined, size: 17),
                    label: Text(l10n.goToCalculator),
                  ),
                )
              else ...[
                AppPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var index = 0; index < entries.length; index++) ...[
                        if (index > 0) Divider(height: 1, color: colors.border),
                        _HistoryRow(
                          entry: entries[index],
                          localeName: l10n.localeName,
                          onTap: () => _openEntry(entries[index]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.historyRateSnapshotNote,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textMuted, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.localeName,
    required this.onTap,
  });

  final CalculationHistoryEntry entry;
  final String localeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final date = entry.createdAt.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final summary = _summaryText(entry);
    final rateState = _RateBadgeState.fromMeta(entry.rateMeta);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('history-entry-${entry.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      month,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontSize: 8,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatTimestamp(
                            entry.createdAt,
                            localeName: localeName,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted, fontSize: 11),
                        ),
                        SoftChip(
                          label: rateState.label(l10n),
                          color: rateState.color(colors),
                          background: rateState.background(colors),
                          icon: rateState.icon,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatAmount(
                      entry.result,
                      entry.outputCurrency,
                      localeName: localeName,
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.outputCurrency.code,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      letterSpacing: 0.5,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryText(CalculationHistoryEntry entry) {
    final parts = <String>[];
    for (final row in entry.rows) {
      final amount = row.amount.trim();
      parts.add(
        amount.isEmpty ? row.currency.code : '$amount ${row.currency.code}',
      );
      if (parts.length == 3 && entry.rows.length > 3) break;
    }
    final suffix = entry.rows.length > 3 ? '  +${entry.rows.length - 3}' : '';
    return '${parts.join('  +  ')}$suffix';
  }
}

enum _RateBadgeState {
  live,
  cached,
  unavailable;

  static _RateBadgeState fromMeta(HistoryRateMeta meta) {
    if (!meta.hasSnapshot) return _RateBadgeState.unavailable;
    if (meta.isAnyCached) return _RateBadgeState.cached;
    return _RateBadgeState.live;
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      _RateBadgeState.live => l10n.savedWithLiveRates,
      _RateBadgeState.cached => l10n.savedWithCachedRates,
      _RateBadgeState.unavailable => l10n.savedWithUnavailableRates,
    };
  }

  Color color(AppColors colors) {
    return switch (this) {
      _RateBadgeState.live => colors.positive,
      _RateBadgeState.cached => colors.warning,
      _RateBadgeState.unavailable => colors.textMuted,
    };
  }

  Color background(AppColors colors) {
    return switch (this) {
      _RateBadgeState.live => colors.positiveSoft,
      _RateBadgeState.cached => colors.warningSoft,
      _RateBadgeState.unavailable => colors.surfaceMuted,
    };
  }

  IconData get icon {
    return switch (this) {
      _RateBadgeState.live => Icons.sensors_rounded,
      _RateBadgeState.cached => Icons.cloud_off_rounded,
      _RateBadgeState.unavailable => Icons.remove_circle_outline_rounded,
    };
  }
}

enum _HistoryAction { restore, delete }

class _HistoryDetailDialog extends StatelessWidget {
  const _HistoryDetailDialog({required this.entry});

  final CalculationHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CalculatorController>();
    final l10n = context.l10n;
    final colors = context.colors;
    final localeName = l10n.localeName;
    final recalculated = controller.recalculateHistory(entry);
    final storedMeta = entry.rateMeta;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 10, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.calculationDetails,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatFullTimestamp(
                            entry.createdAt,
                            localeName: localeName,
                          ),
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
            Divider(height: 1, color: colors.border),
            Flexible(
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultBlock(
                      label: l10n.storedResult,
                      value: formatAmount(
                        entry.result,
                        entry.outputCurrency,
                        localeName: localeName,
                      ),
                      currencyCode: entry.outputCurrency.code,
                      note: l10n.storedResultNote(
                        formatFullTimestamp(
                          storedMeta.fetchedAt ?? entry.createdAt,
                          localeName: localeName,
                        ),
                      ),
                      highlighted: true,
                    ),
                    const SizedBox(height: 10),
                    _ResultBlock(
                      label: l10n.currentResult,
                      value: recalculated.isValid
                          ? formatAmount(
                              recalculated.total!,
                              entry.outputCurrency,
                              localeName: localeName,
                            )
                          : '—',
                      currencyCode: entry.outputCurrency.code,
                      note: recalculated.isValid
                          ? l10n.currentResultNote
                          : l10n.currentRatesUnavailable,
                      highlighted: false,
                      noteColor: recalculated.isValid
                          ? colors.textMuted
                          : colors.warning,
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(l10n.inputsLabel),
                    const SizedBox(height: 7),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < entry.rows.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Divider(height: 1, color: colors.border),
                            _StoredRow(
                              entry: entry,
                              row: entry.rows[index],
                              localeName: localeName,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(l10n.ratesTitle),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _RateStateBadge(
                          origin: storedMeta.fiatOrigin,
                          label: l10n.fiat,
                        ),
                        _RateStateBadge(
                          origin: storedMeta.cryptoOrigin,
                          label: l10n.crypto,
                        ),
                        if (storedMeta.fetchedAt != null)
                          SoftChip(
                            label: formatFullTimestamp(
                              storedMeta.fetchedAt,
                              localeName: localeName,
                            ),
                            color: colors.textMuted,
                          ),
                      ],
                    ),
                    if (entry.unitsPerUsd.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 5,
                        children: [
                          for (final row in entry.rows)
                            if (entry.unitsPerUsd[row.currency.code] != null)
                              Text(
                                _storedRateLine(
                                  entry,
                                  row.currency.code,
                                  localeName,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.textMuted,
                                      fontSize: 11,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      l10n.historyRateSnapshotNote,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.textMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  TextButton.icon(
                    key: const Key('history-delete-button'),
                    onPressed: () =>
                        Navigator.of(context).pop(_HistoryAction.delete),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: colors.danger,
                    ),
                    label: Text(
                      l10n.deleteEntry,
                      style: TextStyle(color: colors.danger),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('history-restore-button'),
                    onPressed: () =>
                        Navigator.of(context).pop(_HistoryAction.restore),
                    icon: const Icon(Icons.restore_rounded, size: 17),
                    label: Text(l10n.restoreToCalculator),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _storedRateLine(
    CalculationHistoryEntry entry,
    String code,
    String localeName,
  ) {
    final units = entry.unitsPerUsd[code];
    final outputUnits = entry.unitsPerUsd[entry.outputCurrency.code];
    if (units == null || outputUnits == null || outputUnits <= 0) {
      return '${code.toUpperCase()} → ${entry.outputCurrency.code}';
    }
    final rate = units / outputUnits;
    return '1 ${code.toUpperCase()} = '
        '${formatUnitRate(rate, localeName: localeName)} '
        '${entry.outputCurrency.code}';
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.label,
    required this.value,
    required this.currencyCode,
    required this.note,
    required this.highlighted,
    this.noteColor,
  });

  final String label;
  final String value;
  final String currencyCode;
  final String note;
  final bool highlighted;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
      decoration: BoxDecoration(
        color: highlighted ? colors.surfaceRaised : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: highlighted ? colors.borderStrong : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: highlighted
                      ? colors.textPrimary
                      : colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  currencyCode,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: colors.textMuted, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: noteColor ?? colors.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StoredRow extends StatelessWidget {
  const _StoredRow({
    required this.entry,
    required this.row,
    required this.localeName,
  });

  final CalculationHistoryEntry entry;
  final CalculationRow row;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final units = entry.unitsPerUsd[row.currency.code];
    final amount = double.tryParse(row.amount.trim().replaceAll(',', '.'));
    final usd = amount != null && units != null && units > 0
        ? amount / units
        : null;
    final usdCurrency = CurrencyCatalog.fiatCurrency('USD');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${row.amount} ${row.currency.code}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (usd != null)
            Text(
              '≈ ${formatAmount(usd, usdCurrency, localeName: localeName)} USD',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _RateStateBadge extends StatelessWidget {
  const _RateStateBadge({required this.origin, required this.label});

  final RateOrigin origin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final color = switch (origin) {
      RateOrigin.live => colors.positive,
      RateOrigin.cached => colors.warning,
      RateOrigin.unavailable => colors.textMuted,
    };
    final state = switch (origin) {
      RateOrigin.live => l10n.live,
      RateOrigin.cached => l10n.cached,
      RateOrigin.unavailable => l10n.unavailable,
    };
    return SoftChip(
      label: '$label · $state',
      color: color,
      background: origin == RateOrigin.live
          ? colors.positiveSoft
          : origin == RateOrigin.cached
          ? colors.warningSoft
          : colors.surfaceMuted,
    );
  }
}
