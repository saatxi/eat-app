import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A small line chart with a gradient fill under it, drawn by hand.
///
/// The project has no charting library, so the mockup's inline chart is
/// translated to `Canvas` calls instead — a port of the Android app's
/// `RatingTrendChart`. Used for a restaurant's own rating-over-time line on the
/// detail screen and, later, the statistics screen's charts.
class RatingTrendChart extends StatelessWidget {
  const RatingTrendChart({
    super.key,
    required this.values,
    required this.lineColor,
    this.maxValue = 5,
  });

  /// The points, oldest first. Fewer than two draws nothing — a trend needs a
  /// slope.
  final List<double> values;
  final Color lineColor;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RatingTrendPainter(
        values: values,
        lineColor: lineColor,
        maxValue: maxValue,
      ),
    );
  }
}

class _RatingTrendPainter extends CustomPainter {
  _RatingTrendPainter({
    required this.values,
    required this.lineColor,
    required this.maxValue,
  });

  final List<double> values;
  final Color lineColor;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    final double stepX = size.width / (values.length - 1);
    double yFor(double value) => size.height - (value / maxValue) * size.height;
    final List<Offset> offsets = <Offset>[
      for (int index = 0; index < values.length; index++)
        Offset(index * stepX, yFor(values[index])),
    ];

    final Path line = Path()
      ..moveTo(offsets.first.dx, offsets.first.dy);
    for (final Offset offset in offsets.skip(1)) {
      line.lineTo(offset.dx, offset.dy);
    }
    final Path fill = Path.from(line)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final Paint dot = Paint()..color = lineColor;
    for (final Offset offset in offsets) {
      canvas.drawCircle(offset, 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RatingTrendPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.maxValue != maxValue;
}
