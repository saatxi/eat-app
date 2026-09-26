import 'package:flutter/material.dart';

/// Counts from zero up to [value] when it first appears, and from the old value
/// to the new one when [value] changes — the "growing count-up" the statistics
/// tiles use, so a number arriving reads as an amount rather than a static
/// label.
///
/// The run is short and one-shot, so it always settles and never leaves a
/// repeating frame source behind (which is what would hang `pumpAndSettle`). It
/// honours the platform's "reduce motion" setting by jumping straight to the
/// final value, and it renders with tabular figures so the digits do not jitter
/// as the number climbs.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
    this.format,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  /// Renders the in-flight number; defaults to its plain decimal form.
  final String Function(int value)? format;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late Animation<double> _animation = _tweenFrom(0);

  Animation<double> _tweenFrom(double begin) => Tween<double>(
        begin: begin,
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // Resume from wherever the last run stopped, so a value that changes
      // mid-count keeps climbing instead of snapping back to zero.
      _animation = _tweenFrom(_animation.value);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final String Function(int) format = widget.format ?? (int v) => '$v';
    final TextStyle? style = widget.style?.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    if (reduceMotion) {
      return Text(format(widget.value), style: style);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) =>
          Text(format(_animation.value.round()), style: style),
    );
  }
}
