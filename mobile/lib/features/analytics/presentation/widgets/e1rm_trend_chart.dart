import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/analytics/presentation/analytics_formatters.dart';
/// Compact sparkline for the progress exercise list.
class E1rmSparkline extends StatelessWidget {
  const E1rmSparkline({super.key, required this.values, this.trend});

  final List<double> values;
  /// API trend (`up` / `down` / `flat`) — matches the delta badge on the card.
  final String? trend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 22,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, trend: trend),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, this.trend});

  final List<double> values;
  final String? trend;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs();
    final safeSpan = span < 0.0001 ? 1.0 : span;

    final Color color;
    switch (trend) {
      case 'up':
        color = AppColors.primary.withValues(alpha: 0.9);
      case 'down':
        color = AppColors.textMuted.withValues(alpha: 0.75);
      case 'flat':
        color = AppColors.textSecondary.withValues(alpha: 0.85);
      default:
        final up = values.last >= values.first;
        color = up
            ? AppColors.primary.withValues(alpha: 0.9)
            : AppColors.textMuted.withValues(alpha: 0.75);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final t = (values[i] - minV) / safeSpan;
      final y = size.height - (t * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.trend != trend) return true;
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

/// Full-width e1RM line chart for exercise detail (history oldest → newest).
class E1rmTrendChartCard extends StatelessWidget {
  const E1rmTrendChartCard({
    super.key,
    required this.history,
    required this.trendSummary,
    required this.absoluteBestE1rmKg,
    required this.units,
  });

  final List<ExerciseHistoryEntry> history;
  final String trendSummary;
  final double absoluteBestE1rmKg;
  final BodyUnitSystem units;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final sessionCount = history.length;
    final subtitle = sessionCount == 1
        ? '1 session logged'
        : '$sessionCount sessions · oldest to newest';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('e1RM over time', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 148,
              width: double.infinity,
              child: CustomPaint(
                painter: _E1rmTrendChartPainter(
                  history: history,
                  trendSummary: trendSummary,
                  absoluteBestE1rmKg: absoluteBestE1rmKg,
                  units: units,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _E1rmTrendChartPainter extends CustomPainter {
  _E1rmTrendChartPainter({
    required this.history,
    required this.trendSummary,
    required this.absoluteBestE1rmKg,
    required this.units,
  });

  final List<ExerciseHistoryEntry> history;
  final String trendSummary;
  final double absoluteBestE1rmKg;
  final BodyUnitSystem units;

  static const _leftPad = 44.0;
  static const _rightPad = 8.0;
  static const _topPad = 8.0;
  static const _bottomPad = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final values = history.map((e) => e.bestE1rmKg).toList();
    if (values.isEmpty) return;

    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 0.0001) {
      minV -= 5;
      maxV += 5;
    } else {
      final pad = (maxV - minV) * 0.08;
      minV -= pad;
      maxV += pad;
    }

    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    final chartLeft = _leftPad;
    final chartTop = _topPad;

    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      height: 1.1,
    );

    for (var i = 0; i <= 2; i++) {
      final t = i / 2;
      final y = chartTop + chartH * (1 - t);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartLeft + chartW, y), gridPaint);
      final label = formatE1rmKg(minV + (maxV - minV) * t, units)
          .replaceAll(' kg', '')
          .replaceAll(' lb', '');
      _drawText(canvas, label, Offset(0, y - 6), labelStyle, width: _leftPad - 4, align: TextAlign.right);
    }

    final lineColor = trendColor(trendSummary);
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset pointAt(int index) {
      final x = values.length == 1
          ? chartLeft + chartW / 2
          : chartLeft + (index / (values.length - 1)) * chartW;
      final norm = (values[index] - minV) / (maxV - minV);
      final y = chartTop + chartH * (1 - norm);
      return Offset(x, y);
    }

    if (values.length >= 2) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final p = pointAt(i);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    for (var i = 0; i < values.length; i++) {
      final entry = history[i];
      final p = pointAt(i);
      final isPr = entry.prs.isNotEmpty;
      final isBest = (values[i] - absoluteBestE1rmKg).abs() < 0.01;

      if (isBest) {
        canvas.drawCircle(
          p,
          7,
          Paint()
            ..color = AppColors.success.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
      }

      final fill = isPr ? AppColors.primary : (isBest ? AppColors.success : lineColor);
      canvas.drawCircle(p, isPr || isBest ? 5 : 3.5, Paint()..color = fill);

      if (isPr) {
        canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = AppColors.textPrimary.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);
    var dx = offset.dx;
    if (align == TextAlign.center) {
      dx -= painter.width / 2;
    } else if (align == TextAlign.right) {
      dx -= painter.width;
    }
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _E1rmTrendChartPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.trendSummary != trendSummary ||
        oldDelegate.absoluteBestE1rmKg != absoluteBestE1rmKg;
  }
}
