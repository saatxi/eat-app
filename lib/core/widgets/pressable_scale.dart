import 'package:flutter/material.dart';

/// Scales [child] down a touch while a pointer is held on it, then eases it
/// back on release — the "spring press" that makes a card or a button feel like
/// it reacted to the touch.
///
/// The press is observed with a [Listener], which does not join the gesture
/// arena, so the [InkWell] or button inside still receives the tap: this only
/// changes how the press *looks*. The return is a plain ease-out rather than a
/// bouncy spring, which is the redesign's "organic, no hard bounce" rule.
///
/// Honours the platform's "reduce motion" setting: when animations are disabled
/// the child is handed back untouched and never scales.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.enabled = true,
  });

  final Widget child;

  /// How far the child shrinks while held. Small on purpose — this is a hint,
  /// not a bounce.
  final double pressedScale;

  final Duration duration;

  /// When false the child is returned as-is, so a caller can opt out without
  /// changing the tree shape around it.
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.pressedScale,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() => _controller.forward();
  void _release() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.enabled || reduceMotion) {
      return widget.child;
    }
    return Listener(
      // Translucent rather than the default `deferToChild`: the press has to be
      // seen even over a child that does not itself hit-test (plain text, a
      // spacer), and the listener never consumes the event, so the button or
      // ink well inside still receives the tap.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
