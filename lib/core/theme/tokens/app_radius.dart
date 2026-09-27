import 'package:flutter/widgets.dart';

/// The corner-radius scale.
///
/// Generously rounded for the soft, organic direction: chip-sized controls
/// round at 14, most cards and surfaces at the "medium" 20, and the large
/// feature surfaces (a hero card, a bottom sheet, a dialog) at 28. Kept as
/// named tokens so call sites stop guessing at a literal.
abstract final class AppRadius {
  /// 10 — the smallest rounding: inner shapes, tight tiles.
  static const double extraSmall = 10;

  /// 14 — text fields, chips' inner shapes, small controls.
  static const double small = 14;

  /// 20 — the default card/surface radius.
  static const double medium = 20;

  /// 28 — large feature surfaces (a hero card, a bottom sheet, a dialog).
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
