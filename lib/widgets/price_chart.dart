import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/market_data.dart';
import '../theme/app_theme.dart';

/// Dependency-free line/area price chart for cached or live history points.
///
/// The chart deliberately draws only data supplied by [PriceHistory]. It never
/// synthesizes points for empty or failed responses.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.history});

  final PriceHistory history;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: CustomPaint(
          painter: _PriceChartPainter(
            history: history,
            lineColor: colors.accent,
            fillColor: colors.accent,
            gridColor: colors.border,
            surfaceColor: colors.surface,
            mutedColor: colors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  _PriceChartPainter({
    required this.history,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.surfaceColor,
    required this.mutedColor,
  });

  final PriceHistory history;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color surfaceColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final points = history.points;
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final chart = Rect.fromLTRB(4, 10, size.width - 6, size.height - 8);
    if (chart.width <= 0 || chart.height <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (var line = 0; line <= 4; line++) {
      final y = chart.top + chart.height * line / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    var minimum = points.first.usdPrice;
    var maximum = points.first.usdPrice;
    var firstTime = points.first.time.millisecondsSinceEpoch;
    var lastTime = firstTime;
    for (final point in points.skip(1)) {
      minimum = math.min(minimum, point.usdPrice);
      maximum = math.max(maximum, point.usdPrice);
      final time = point.time.millisecondsSinceEpoch;
      firstTime = math.min(firstTime, time);
      lastTime = math.max(lastTime, time);
    }

    var range = maximum - minimum;
    if (range <= 0) {
      range = maximum.abs() * 0.02;
      if (range <= 0) range = 1;
    }
    final padding = range * 0.08;
    final bottomValue = minimum - padding;
    final topValue = maximum + padding;
    final valueSpan = topValue - bottomValue;

    Offset offsetFor(int index, PricePoint point) {
      double fractionX;
      if (lastTime == firstTime) {
        fractionX = points.length == 1 ? 0.5 : index / (points.length - 1);
      } else {
        fractionX =
            (point.time.millisecondsSinceEpoch - firstTime) /
            (lastTime - firstTime);
      }
      final fractionY = ((point.usdPrice - bottomValue) / valueSpan).clamp(
        0.0,
        1.0,
      );
      return Offset(
        chart.left + chart.width * fractionX.clamp(0.0, 1.0),
        chart.bottom - chart.height * fractionY,
      );
    }

    final linePath = Path();
    for (var index = 0; index < points.length; index++) {
      final offset = offsetFor(index, points[index]);
      if (index == 0) {
        linePath.moveTo(offset.dx, offset.dy);
      } else {
        linePath.lineTo(offset.dx, offset.dy);
      }
    }

    final areaPath = Path.from(linePath)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    final areaPaint = Paint()..color = fillColor.withValues(alpha: 0.07);
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final lastOffset = offsetFor(points.length - 1, points.last);
    canvas.drawCircle(lastOffset, 4.5, Paint()..color = surfaceColor);
    canvas.drawCircle(lastOffset, 3, Paint()..color = lineColor);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: _shortPrice(maximum),
        style: TextStyle(
          color: mutedColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(chart.left + 2, chart.top));
    final lowPainter = TextPainter(
      text: TextSpan(
        text: _shortPrice(minimum),
        style: TextStyle(
          color: mutedColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lowPainter.paint(
      canvas,
      Offset(chart.left + 2, chart.bottom - lowPainter.height - 2),
    );
  }

  String _shortPrice(double value) {
    final absolute = value.abs();
    if (absolute >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (absolute >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    }
    if (absolute >= 1) return value.toStringAsFixed(2);
    if (absolute >= 0.01) return value.toStringAsFixed(4);
    return value.toStringAsPrecision(4);
  }

  @override
  bool shouldRepaint(_PriceChartPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.mutedColor != mutedColor;
  }
}
