import 'package:flutter/widgets.dart';

/// The corner-radius scale.
///
/// Rounded further than Material's defaults, per the mockup's ~16-24dp card
/// corners: the "medium" radius (what most cards and surfaces pick up) is
/// 20dp rather than 16dp, and "large" is 28dp. Port of the Android app's
/// `Shape.kt`, kept as named tokens so call sites stop guessing at a literal.
abstract final class AppRadius {
  /// 8 — small controls, chips' inner shapes.
  static const double extraSmall = 8;

  /// 12 — text fields and smaller surfaces.
  static const double small = 12;

  /// 20 — the default card/surface radius.
  static const double medium = 20;

  /// 28 — large feature surfaces (a hero card, a bottom sheet).
  static const double large = 28;

  /// 36 — the largest rounding the scale offers.
  static const double extraLarge = 36;

  static const BorderRadius extraSmallAll = BorderRadius.all(Radius.circular(extraSmall));
  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius extraLargeAll = BorderRadius.all(Radius.circular(extraLarge));

  /// Fully rounded, for pills (price, status, tags).
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}
