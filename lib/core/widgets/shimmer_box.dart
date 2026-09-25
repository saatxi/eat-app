import 'package:flutter/material.dart';

import '../theme/tokens/app_radius.dart';

/// A pulsing block standing in for text or an image while a screen's real
/// content is still loading — shape-matching skeletons instead of one centred
/// spinner, so the list and detail screens read as faster even at the same
/// actual load time.
///
/// No animation package needed: a single controller fading a tinted box in and
/// out, the Flutter equivalent of the Android app's
/// `ui/common/Shimmer.kt`.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;

  /// Defaults to the small radius; pass [AppRadius.pill] for a circle.
  final BorderRadius? borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.3,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (BuildContext context, Widget? child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: _opacity.value * 0.11),
          borderRadius: widget.borderRadius ?? AppRadius.extraSmallAll,
        ),
      ),
    );
  }
}
