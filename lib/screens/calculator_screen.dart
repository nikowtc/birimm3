import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/asset_search.dart';
import '../logic/row_calculator.dart';
import '../models/calculation_row.dart';
import '../models/currency.dart';
import '../models/currency_catalog.dart';
import '../models/quick_conversion.dart';
import '../providers/calculator_controller.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../widgets/currency_picker_dialog.dart';
import '../widgets/panel.dart';
import '../widgets/rate_status_strip.dart';

/// The calculator-first surface: independently editable rows, one USD
/// reference, and one explicit output currency.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _saving = false;
  bool? _advancedOverride;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickRowCurrency(CalculationRow row) async {
    final controller = context.read<CalculatorController>();
    final selected = await showCurrencyPicker(
      context,
      currencies: controller.currencies,
      selected: row.currency,
      title: context.l10n.selectCurrency,
      favoriteCodes: [
        for (final currency in controller.favoriteCurrencies) currency.code,
      ],
      onFavoriteToggle: controller.toggleCurrencyFavorite,
    );
    if (!mounted || selected == null) return;
    controller.setRowCurrency(row.id, selected);
  }

  Future<void> _pickOutputCurrency() async {
    final controller = context.read<CalculatorController>();
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

  void _addRow() {
    final controller = context.read<CalculatorController>();
    controller.addRow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _clearRows() async {
    final controller = context.read<CalculatorController>();
    final l10n = context.l10n;
    final hasInput = controller.rows.any((row) => row.hasInput);
    if (hasInput) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.clearRowsTitle),
          content: Text(l10n.clearRowsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirm-clear-rows'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.clearRows),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    controller.resetRows();
  }

  Future<void> _saveToHistory() async {
    final controller = context.read<CalculatorController>();
    final l10n = context.l10n;
    if (!controller.canSaveCalculation || _saving) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.nothingToSave)));
      return;
    }
    setState(() => _saving = true);
    final saved = await controller.saveCurrentCalculationToHistory();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? l10n.calculationSaved : l10n.calculationSaveFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CalculatorController>();
    final l10n = context.l10n;
    final result = controller.calculation;
    final currencies = controller.rows
        .map((row) => row.currency.code)
        .toSet()
        .length;
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 760
        ? 30.0
        : 16.0;

    final inputPanel = _InputPanel(
      controller: controller,
      result: result,
      onPickCurrency: _pickRowCurrency,
      onAddRow: _addRow,
      onClearRows: _clearRows,
    );
    final resultPanel = _ResultPanel(
      controller: controller,
      result: result,
      saving: _saving,
      onPickOutput: _pickOutputCurrency,
      onSave: _saveToHistory,
    );
    final advancedOpen =
        _advancedOverride ?? MediaQuery.sizeOf(context).width >= 940;

    return SingleChildScrollView(
      key: const Key('calculator-page'),
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
                title: l10n.calculatorTitle,
                subtitle: l10n.calculatorSubtitle,
                trailing: SoftChip(
                  label: l10n.rowsSummary(controller.rows.length, currencies),
                  icon: Icons.stacked_line_chart_rounded,
                ),
              ),
              const SizedBox(height: 18),
              _QuickConversionPanel(controller: controller),
              const SizedBox(height: 14),
              const RateStatusStrip(),
              const SizedBox(height: 18),
              _AdvancedHeader(
                open: advancedOpen,
                onToggle: () {
                  setState(() => _advancedOverride = !advancedOpen);
                },
              ),
              if (advancedOpen) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 940) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: inputPanel),
                          const SizedBox(width: 20),
                          SizedBox(width: 360, child: resultPanel),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        inputPanel,
                        const SizedBox(height: 16),
                        resultPanel,
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l10n.conversionNote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedHeader extends StatelessWidget {
  const _AdvancedHeader({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final icon = AnimatedRotation(
          turns: open ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: const Icon(Icons.expand_more_rounded, size: 18),
        );
        return AppPanel(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.table_rows_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.advancedCalculator,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.advancedCalculatorSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (compact)
                IconButton(
                  key: const Key('advanced-calculator-toggle'),
                  tooltip: open
                      ? l10n.collapseAdvanced
                      : l10n.expandAdvanced,
                  onPressed: onToggle,
                  icon: icon,
                )
              else
                OutlinedButton.icon(
                  key: const Key('advanced-calculator-toggle'),
                  onPressed: onToggle,
                  icon: icon,
                  label: Text(
                    open ? l10n.collapseAdvanced : l10n.expandAdvanced,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickConversionPanel extends StatefulWidget {
  const _QuickConversionPanel({required this.controller});

  final CalculatorController controller;

  @override
  State<_QuickConversionPanel> createState() => _QuickConversionPanelState();
}

class _QuickConversionPanelState extends State<_QuickConversionPanel> {
  late final TextEditingController _amountController;
  final TextEditingController _phraseController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _phraseFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.controller.quickAmount,
    );
  }

  @override
  void didUpdateWidget(_QuickConversionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final expected = widget.controller.quickAmount;
    if (_amountController.text != expected && !_amountFocus.hasFocus) {
      _amountController.text = expected;
      _amountController.selection = TextSelection.collapsed(
        offset: expected.length,
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phraseController.dispose();
    _amountFocus.dispose();
    _phraseFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAsset({required bool from}) async {
    final controller = widget.controller;
    final selected = await showCurrencyPicker(
      context,
      currencies: controller.currencies,
      selected: from ? controller.quickFrom : controller.quickTo,
      title: from ? context.l10n.quickFrom : context.l10n.quickTo,
      favoriteCodes: [
        for (final currency in controller.favoriteCurrencies) currency.code,
      ],
      onFavoriteToggle: controller.toggleCurrencyFavorite,
    );
    if (!mounted || selected == null) return;
    if (from) {
      controller.setQuickFrom(selected);
    } else {
      controller.setQuickTo(selected);
    }
  }

  Future<void> _applyPhrase() async {
    final phrase = _phraseController.text.trim();
    if (phrase.isEmpty) return;
    final applied = await widget.controller.applyConversionPhrase(phrase);
    if (!mounted) return;
    if (applied) {
      _phraseController.clear();
      _phraseFocus.unfocus();
      _showMessage(context.l10n.quickPhraseApplied);
    } else {
      _showMessage(context.l10n.quickPhraseFailed);
    }
  }

  Future<void> _togglePair() async {
    await widget.controller.toggleQuickPairSaved();
  }

  Future<void> _clearRecent() async {
    await widget.controller.clearQuickRecent();
    if (!mounted) return;
    _showMessage(context.l10n.quickRecentCleared);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final controller = widget.controller;
    final from = controller.quickFrom;
    final to = controller.quickTo;
    final result = controller.quickResult;
    final rate = controller.quickRate;
    final amountValid =
        parseLocalizedAmount(controller.quickAmount) != null;
    final rateMissing = rate == null;

    return AppPanel(
      color: colors.surfaceRaised,
      borderColor: colors.borderStrong,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.quickConversion,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.quickConversionSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('quick-save-pair'),
                tooltip: controller.quickPairIsSaved
                    ? l10n.quickUnfavoritePair
                    : l10n.quickFavoritePair,
                onPressed: _togglePair,
                icon: Icon(
                  controller.quickPairIsSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: controller.quickPairIsSaved
                      ? colors.accent
                      : colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.text_fields_rounded,
                size: 14,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.quickPhraseLabel.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  letterSpacing: 1.1,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final field = TextField(
                key: const Key('quick-phrase-field'),
                controller: _phraseController,
                focusNode: _phraseFocus,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => unawaited(_applyPhrase()),
                decoration: InputDecoration(
                  hintText: l10n.quickPhraseHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.bolt_rounded, size: 18),
                ),
              );
              final apply = FilledButton.tonalIcon(
                key: const Key('quick-phrase-apply'),
                onPressed: _applyPhrase,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(l10n.quickPhraseApply),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                ),
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: 7),
                    Align(alignment: Alignment.centerRight, child: apply),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 8),
                  apply,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final amount = _QuickAmountCard(
                controller: _amountController,
                focusNode: _amountFocus,
                onChanged: controller.setQuickAmount,
                onSubmitted: () => unawaited(
                  controller.rememberQuickConversion(),
                ),
                label: l10n.amountHint,
              );
              final fromButton = _QuickAssetButton(
                key: const Key('quick-from-button'),
                label: l10n.quickFrom,
                currency: from,
                onTap: () => _pickAsset(from: true),
              );
              final swap = _QuickSwapButton(
                tooltip: l10n.swapCurrencies,
                onTap: controller.swapQuickPair,
              );
              final toButton = _QuickAssetButton(
                key: const Key('quick-to-button'),
                label: l10n.quickTo,
                currency: to,
                onTap: () => _pickAsset(from: false),
              );
              if (constraints.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    amount,
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(child: fromButton),
                        const SizedBox(width: 6),
                        swap,
                        const SizedBox(width: 6),
                        Expanded(child: toButton),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: amount),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: fromButton),
                  const SizedBox(width: 7),
                  swap,
                  const SizedBox(width: 7),
                  Expanded(flex: 3, child: toButton),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 14),
          SectionLabel(l10n.quickResult),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            child: result == null
                ? Text(
                    rateMissing
                        ? l10n.errorNoRate(to.code)
                        : l10n.quickEnterAmount,
                    key: ValueKey('quick-empty-${rateMissing ? to.code : 'amount'}'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: rateMissing ? colors.danger : colors.textMuted,
                    ),
                  )
                : FittedBox(
                    key: const ValueKey('quick-result'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatAmount(result, to, localeName: localeName),
                          key: const Key('quick-result-value'),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -1.2,
                                height: 1.05,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            to.code,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (result != null && rate != null && rate.isFinite && rate > 0) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text(
                  l10n.quickRate(
                    from.code,
                    formatUnitRate(rate, localeName: localeName),
                    to.code,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  l10n.quickInverseRate(
                    to.code,
                    formatUnitRate(1 / rate, localeName: localeName),
                    from.code,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          if (!amountValid && controller.quickAmount.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.invalidAmount,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.danger),
            ),
          ],
          if (controller.quickSavedPairs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: colors.border),
            const SizedBox(height: 12),
            SectionLabel(l10n.quickSavedPairs),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final pair in controller.quickSavedPairs)
                  _QuickPairChip(
                    key: Key('quick-pair-${pair.key}'),
                    label: '${pair.fromCode} → ${pair.toCode}',
                    onTap: () => controller.applyQuickPair(pair),
                    onRemove: () => controller.removeQuickPair(pair),
                    removeTooltip: l10n.quickUnfavoritePair,
                  ),
              ],
            ),
          ],
          if (controller.quickRecent.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SectionLabel(l10n.quickRecent)),
                TextButton.icon(
                  key: const Key('quick-clear-recent'),
                  onPressed: _clearRecent,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                  label: Text(l10n.clearRecent),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    textStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var index = 0; index < controller.quickRecent.length; index++)
                  _QuickPairChip(
                    key: Key('quick-recent-$index'),
                    label: _recordLabel(controller.quickRecent[index]),
                    onTap: () =>
                        controller.applyQuickRecord(controller.quickRecent[index]),
                  ),
              ],
            ),
          ] else if (controller.quickSavedPairs.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.quickNoRecent,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _recordLabel(QuickConversionRecord record) {
    return '${record.amount} ${record.fromCode} → ${record.toCode}';
  }
}

class _QuickAmountCard extends StatelessWidget {
  const _QuickAmountCard({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.label,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              letterSpacing: 1,
              fontSize: 9,
            ),
          ),
          TextField(
            key: const Key('quick-amount-field'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: colors.textMuted),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAssetButton extends StatelessWidget {
  const _QuickAssetButton({
    super.key,
    required this.label,
    required this.currency,
    required this.onTap,
  });

  final String label;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  letterSpacing: 1,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currency.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                currency.localizedName(l10n.locale.languageCode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSwapButton extends StatelessWidget {
  const _QuickSwapButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.accentSoft,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('quick-swap-button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 20,
              color: colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPairChip extends StatelessWidget {
  const _QuickPairChip({
    super.key,
    required this.label,
    required this.onTap,
    this.onRemove,
    this.removeTooltip,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.fromLTRB(10, 6, onRemove == null ? 10 : 4, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 2),
                Tooltip(
                  message: removeTooltip ?? '',
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.controller,
    required this.result,
    required this.onPickCurrency,
    required this.onAddRow,
    required this.onClearRows,
  });

  final CalculatorController controller;
  final RowCalculationResult result;
  final ValueChanged<CalculationRow> onPickCurrency;
  final VoidCallback onAddRow;
  final VoidCallback onClearRows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                Expanded(child: SectionLabel(l10n.inputsLabel)),
                TextButton.icon(
                  key: const Key('clear-rows-button'),
                  onPressed: onClearRows,
                  icon: const Icon(Icons.backspace_outlined, size: 15),
                  label: Text(l10n.clearRows),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          for (var index = 0; index < controller.rows.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.border),
            _EditableRow(
              index: index,
              row: controller.rows[index],
              result: result,
              canRemove: controller.rows.length > 1,
              onAmountChanged: (value) =>
                  controller.updateRowAmount(controller.rows[index].id, value),
              onPickCurrency: () => onPickCurrency(controller.rows[index]),
              onRemove: () => controller.removeRow(controller.rows[index].id),
              outputCurrency: controller.outputCurrency,
              rate: controller.conversionRate(
                controller.rows[index].currency.code,
                controller.outputCurrency.code,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('add-row-button'),
                onPressed: onAddRow,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(l10n.addRow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.index,
    required this.row,
    required this.result,
    required this.canRemove,
    required this.onAmountChanged,
    required this.onPickCurrency,
    required this.onRemove,
    required this.outputCurrency,
    required this.rate,
  });

  final int index;
  final CalculationRow row;
  final RowCalculationResult result;
  final bool canRemove;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onPickCurrency;
  final VoidCallback onRemove;
  final Currency outputCurrency;
  final double? rate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final rowError = result.errorForRow(row.id);
    RowBreakdown? breakdown;
    for (final item in result.rows) {
      if (item.row.id == row.id) {
        breakdown = item;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final indexLabel = SizedBox(
            width: 30,
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                letterSpacing: 0.7,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
          final amountField = _AmountField(
            key: Key('row-amount-${row.id}'),
            row: row,
            hasError: rowError != null,
            onChanged: onAmountChanged,
          );
          final currencyButton = _CurrencyButton(
            key: Key('row-currency-${row.id}'),
            currency: row.currency,
            onTap: onPickCurrency,
          );
          final removeButton = IconButton(
            tooltip: l10n.removeRow,
            onPressed: canRemove ? onRemove : null,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 17,
              color: canRemove ? colors.textMuted : colors.border,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    indexLabel,
                    const SizedBox(width: 6),
                    Expanded(child: amountField),
                    const SizedBox(width: 10),
                    currencyButton,
                    const SizedBox(width: 2),
                    removeButton,
                  ],
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    indexLabel,
                    const SizedBox(width: 4),
                    Expanded(child: amountField),
                    const SizedBox(width: 4),
                    removeButton,
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [const SizedBox(width: 34), currencyButton]),
              ],
              if (row.amount.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: rowError != null
                      ? Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 13,
                              color: colors.danger,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                rowErrorText(l10n, rowError),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.danger),
                              ),
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (rate != null)
                              Text(
                                l10n.rowRateLabel(
                                  row.currency.code,
                                  formatUnitRate(rate!, localeName: localeName),
                                  outputCurrency.code,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.textMuted,
                                      fontSize: 11,
                                    ),
                              ),
                            if (breakdown?.outputValue != null)
                              Text(
                                l10n.rowEquivalent(
                                  formatAmount(
                                    breakdown!.outputValue!,
                                    outputCurrency,
                                    localeName: localeName,
                                  ),
                                  outputCurrency.code,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                          ],
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    super.key,
    required this.row,
    required this.hasError,
    required this.onChanged,
  });

  final CalculationRow row;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.row.amount);
  }

  @override
  void didUpdateWidget(_AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row.amount != _controller.text &&
        !(oldWidget.row.amount == widget.row.amount)) {
      _controller.text = widget.row.amount;
      _controller.selection = TextSelection.collapsed(
        offset: widget.row.amount.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      key: const Key('row-amount-field'),
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textInputAction: TextInputAction.done,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: widget.hasError ? colors.danger : colors.textPrimary,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        hintText: context.l10n.amountHint,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({
    super.key,
    required this.currency,
    required this.onTap,
  });

  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency.symbol,
                style: TextStyle(
                  color: currency.isCrypto ? colors.warning : colors.textMuted,
                  fontSize: currency.symbol.length > 2 ? 10 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                currency.code,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: colors.textPrimary, letterSpacing: 0.35),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.unfold_more_rounded,
                size: 15,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.controller,
    required this.result,
    required this.saving,
    required this.onPickOutput,
    required this.onSave,
  });

  final CalculatorController controller;
  final RowCalculationResult result;
  final bool saving;
  final VoidCallback onPickOutput;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final output = controller.outputCurrency;
    final hasRowError = result.hasRowErrors;
    final globalError = result.error;
    final valid = result.isValid;
    final showValue = valid && result.total != null;
    final errorText = globalError != null
        ? rowErrorText(l10n, globalError)
        : hasRowError
        ? l10n.resultInvalid
        : result.isEmpty
        ? l10n.resultEmpty
        : null;

    return AppPanel(
      color: colors.surfaceRaised,
      borderColor: colors.borderStrong,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(l10n.result)),
              _OutputCurrencyButton(currency: output, onTap: onPickOutput),
            ],
          ),
          const SizedBox(height: 22),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  showValue
                      ? formatAmount(
                          result.total!,
                          output,
                          localeName: localeName,
                        )
                      : '—',
                  key: const Key('result-value'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: valid ? colors.textPrimary : colors.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.4,
                    height: 1.05,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    output.code,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          if (errorText != null)
            Text(
              errorText,
              key: const Key('result-status'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasRowError || globalError != null
                    ? colors.danger
                    : colors.textMuted,
                height: 1.4,
              ),
            )
          else
            Text(
              '≈ ${formatAmount(result.totalUsd ?? 0, CurrencyCatalog.fiatCurrency('USD'), localeName: localeName)} USD',
              key: const Key('result-usd'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: 18),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SoftChip(
                label: controller.ratesFetchedAt == null
                    ? l10n.noRateSnapshot
                    : formatTimestamp(
                        controller.ratesFetchedAt,
                        localeName: localeName,
                      ),
                icon: controller.isUsingCachedRates
                    ? Icons.cloud_off_rounded
                    : Icons.sensors_rounded,
                color: controller.isUsingCachedRates
                    ? colors.warning
                    : colors.positive,
                background: controller.isUsingCachedRates
                    ? colors.warningSoft
                    : colors.positiveSoft,
              ),
              SoftChip(label: l10n.usdReferenceNote, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('save-history-button'),
            onPressed: controller.canSaveCalculation && !saving ? onSave : null,
            icon: saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history_rounded, size: 17),
            label: Text(l10n.saveToHistory),
          ),
          if (controller.canSaveCalculation) ...[
            const SizedBox(height: 7),
            Text(
              l10n.historyRateSnapshotNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutputCurrencyButton extends StatelessWidget {
  const _OutputCurrencyButton({required this.currency, required this.onTap});

  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const Key('output-currency-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency.code,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.textPrimary, letterSpacing: 0.4),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.unfold_more_rounded,
                size: 14,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
