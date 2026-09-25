import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// A single 4pt-based ramp every screen draws its gaps and padding from,
/// instead of the handful of literal `EdgeInsets` values the Compose code had
/// scattered around. The editorial direction asks for generous white space, so
/// screen-level gaps sit at the larger end of the ramp.
abstract final class AppSpacing {
  /// 2 — hairlines and icon/text nudges.
  static const double xxs = 2;

  /// 4 — the tightest intentional gap.
  static const double xs = 4;

  /// 8 — inside a compact row.
  static const double sm = 8;

  /// 12 — between related controls.
  static const double md = 12;

  /// 16 — the default gap between blocks.
  static const double lg = 16;

  /// 24 — between sections, and the screen's horizontal gutter.
  static const double xl = 24;

  /// 32 — between major regions of a screen.
  static const double xxl = 32;

  /// 48 — the breathing room around a hero/cover.
  static const double xxxl = 48;

  /// The horizontal gutter every screen's content sits inside.
  static const EdgeInsets screenGutter = EdgeInsets.symmetric(horizontal: xl);

  /// Standard padding inside a card or a content block.
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Generous vertical rhythm between a screen's sections.
  static const EdgeInsets sectionGap = EdgeInsets.only(bottom: xl);

  /// A uniform inset, useful for tiles.
  static const EdgeInsets tilePadding = EdgeInsets.all(md);
}
