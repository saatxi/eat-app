import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tokens/cuisine_accents.dart';
import 'cuisine_visuals.dart';

/// A restaurant's thumbnail: its photo when it has one, otherwise the
/// cuisine-derived badge that stands in for it.
///
/// Shared by the journal card, the detail header and the roulette result, so a
/// photo that fails to load (a file removed outside the app, say) falls back to
/// the badge everywhere rather than leaving a hole. The shape is a soft rounded
/// square by default — the warm/humanist direction — with a circle still
/// available by passing a full-radius [borderRadius].
class RestaurantThumbnail extends StatelessWidget {
  const RestaurantThumbnail({
    super.key,
    required this.cuisineKey,
    this.photoPath,
    this.size = 64,
    this.iconSize = 28,
    this.borderRadius,
    this.semanticLabel,
  });

  final String cuisineKey;

  /// Absolute path to a locally-stored copy, or null to draw the badge.
  final String? photoPath;

  final double size;
  final double iconSize;

  /// The corner shape. Defaults to a soft rounded square; pass a full radius
  /// (`BorderRadius.circular(size / 2)`) for a circle.
  final BorderRadius? borderRadius;

  /// Only read by a screen reader when the surrounding widget does not already
  /// collapse the row into one description.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final String? path = photoPath;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(size * 0.28);
    if (path == null) {
      return _CuisineBadge(
        cuisineKey: cuisineKey,
        size: size,
        iconSize: iconSize,
        borderRadius: radius,
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            _CuisineBadge(
              cuisineKey: cuisineKey,
              size: size,
              iconSize: iconSize,
              borderRadius: radius,
            ),
      ),
    );
  }
}

class _CuisineBadge extends StatelessWidget {
  const _CuisineBadge({
    required this.cuisineKey,
    required this.size,
    required this.iconSize,
    required this.borderRadius,
  });

  final String cuisineKey;
  final double size;
  final double iconSize;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final CuisineTint tint = cuisineTint(context, cuisineKey);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.container,
        borderRadius: borderRadius,
      ),
      child: Icon(cuisineIcon(cuisineKey), size: iconSize, color: tint.onContainer),
    );
  }
}
