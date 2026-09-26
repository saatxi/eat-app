import 'package:flutter/material.dart';

/// Fades and slides [child] in, held back by [index], so a freshly built list
/// fills in as a cascade rather than all at once.
///
/// The whole cascade shares one animation window rather than a timer per row:
/// each row owns an [AnimationController] that starts on the first frame and an
/// [Interval] that keeps it still until its slot comes round. Nothing has to be
/// scheduled, cancelled when a row scrolls out of the tree and back, or waited
/// on by `pumpAndSettle`, which is what keeps this cheap and test-friendly.
///
/// The movement is deliberately small and short — this is a hint that the list
/// arrived, not a transition the user has to sit through.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = 12,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
  });

  /// The row's position in the list; it decides how late the row's slot begins.
  final int index;

  final Widget child;

  /// How far, in logical pixels, the row starts below its resting place.
  final double offset;

  final Duration duration;
  final Curve curve;

  /// How many slots the cascade is spread over.
  ///
  /// A long list must not turn into a queue that takes seconds to finish, so
  /// every row past the last slot shares it and the tail arrives together.
  static const int _slots = 8;

  /// How much of [duration] each slot takes.
  static const double _slotFraction = 0.08;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    // Clamped above so the interval always leaves a non-zero window to run in,
    // whatever index this row was handed.
    curve: Interval(_begin.clamp(0, 0.9), 1, curve: widget.curve),
  );

  double get _begin =>
      widget.index.clamp(0, StaggeredEntrance._slots) *
      StaggeredEntrance._slotFraction;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      // Built once and handed back unchanged on every tick, so the row itself
      // never rebuilds as the animation runs — only the two wrappers below it.
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double progress = _progress.value;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
