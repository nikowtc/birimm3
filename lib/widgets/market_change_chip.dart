import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatting.dart';

/// Small signed percentage label shared by market cards and charts.
class MarketChangeChip extends StatelessWidget {
  const MarketChangeChip({
    super.key,
    required this.percent,
    required this.localeName,
  });

  final double? percent;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = percent;
    if (value == null || !value.isFinite) {
      return const SizedBox.shrink();
    }
    final positive = value >= 0;
    final color = positive ? colors.positive : colors.danger;
    final background = positive ? colors.positiveSoft : colors.dangerSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              formatPercent(value, localeName: localeName),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, letterSpacing: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}
