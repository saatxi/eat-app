import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tokens/cuisine_accents.dart';
import 'cuisine_visuals.dart';

/// A restaurant's circular thumbnail: its photo when it has one, otherwise the
/// cuisine-derived badge that stands in for it.
///
/// Shared by the list row and the roulette result card so a photo that fails to
/// load (a file removed outside the app, say) falls back to the badge in both
/// rather than leaving a hole.
class RestaurantThumbnail extends StatelessWidget {
  const RestaurantThumbnail({
    super.key,
    required this.cuisineKey,
    this.photoPath,
    this.size = 52,
    this.iconSize = 24,
    this.semanticLabel,
  });

  final String cuisineKey;

  /// Absolute path to a locally-stored copy, or null to draw the badge.
  final String? photoPath;

  final double size;
  final double iconSize;

  /// Only read by a screen reader when the surrounding widget does not already
  /// collapse the row into one description.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final String? path = photoPath;
    if (path == null) {
      return _CuisineBadge(
        cuisineKey: cuisineKey,
        size: size,
        iconSize: iconSize,
      );
    }
    return ClipOval(
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
  });

  final String cuisineKey;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final CuisineTint tint = cuisineTint(context, cuisineKey);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.container,
        // A ring in the cuisine's own accent; `onContainer` stands in for it,
        // since a CuisineTint only carries the container/on-container pair.
        border: Border.all(color: tint.onContainer, width: 1.5),
      ),
      child: Icon(cuisineIcon(cuisineKey), size: iconSize, color: tint.onContainer),
    );
  }
}
