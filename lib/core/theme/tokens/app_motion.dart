import 'package:flutter/animation.dart';

/// The motion vocabulary.
///
/// The warm/humanist direction asks for gentle, organic movement rather than
/// hard snaps or bounces: a soft decelerate for anything entering, a soft
/// accelerate for anything leaving, and one slower spring-like curve for the
/// few moments that are meant to feel deliberate (the roulette reveal).
///
/// Centralised so every screen animates at the same pace instead of each one
/// picking its own `Duration` literal, the same way [AppSpacing] centralises
/// gaps.
abstract final class AppMotion {
  /// 120ms — the tightest feedback: a press settling back.
  static const Duration quick = Duration(milliseconds: 120);

  /// 200ms — a fold, a chip selection, a small size change.
  static const Duration short = Duration(milliseconds: 200);

  /// 280ms — the default for a content swap or a card entering.
  static const Duration medium = Duration(milliseconds: 280);

  /// 420ms — the one theatrical reveal (the roulette pick).
  static const Duration long = Duration(milliseconds: 420);

  /// Enters ease out, so a thing arriving settles rather than stops dead.
  static const Curve entering = Curves.easeOutCubic;

  /// Leaves ease in, so a thing on its way out does not linger.
  static const Curve leaving = Curves.easeInCubic;

  /// A gentle overshoot-free settle, for the press scale.
  static const Curve settle = Curves.easeOut;

  /// The reveal's softer, slightly springy curve.
  static const Curve reveal = Curves.easeOutBack;
}
