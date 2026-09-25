import 'package:flutter/material.dart';

/// The tonal vocabulary a palette is built from.
///
/// Material 3 derives every colour role from a small set of tones per family,
/// so a palette declares tones and the tone-to-role mapping
/// (see `app_color_scheme.dart`) is written once for all of them. Adding a
/// fourth palette is therefore a matter of listing tones, not of re-deriving
/// which tone `onSecondaryContainer` is supposed to use.
///
/// Only the tones the roles actually consume are declared — there is no value
/// in carrying a full 0-100 ramp that nothing reads. This mirrors the Android
/// app's `Tones.kt` 1:1 so the two implementations stay recognisable.

/// Tones of a brand family (primary, secondary, tertiary).
@immutable
class BrandTones {
  const BrandTones({
    required this.t10,
    required this.t20,
    required this.t30,
    required this.t40,
    required this.t80,
    required this.t90,
    required this.t95,
  });

  final Color t10;
  final Color t20;
  final Color t30;
  final Color t40;
  final Color t80;
  final Color t90;
  final Color t95;
}

/// Tones of the neutral family, which the surface and background roles map to.
///
/// The steps are irregular because M3's surface container tiers are: light
/// mode reads 87-100, dark mode reads 4-24.
@immutable
class NeutralTones {
  const NeutralTones({
    required this.t4,
    required this.t6,
    required this.t10,
    required this.t12,
    required this.t17,
    required this.t20,
    required this.t22,
    required this.t24,
    required this.t87,
    required this.t90,
    required this.t92,
    required this.t94,
    required this.t95,
    required this.t96,
    required this.t98,
    required this.t100,
  });

  final Color t4;
  final Color t6;
  final Color t10;
  final Color t12;
  final Color t17;
  final Color t20;
  final Color t22;
  final Color t24;
  final Color t87;
  final Color t90;
  final Color t92;
  final Color t94;
  final Color t95;
  final Color t96;
  final Color t98;
  final Color t100;
}

/// Tones of the neutral-variant family: outlines and the tinted surface greys.
@immutable
class NeutralVariantTones {
  const NeutralVariantTones({
    required this.t30,
    required this.t50,
    required this.t60,
    required this.t80,
    required this.t90,
  });

  final Color t30;
  final Color t50;
  final Color t60;
  final Color t80;
  final Color t90;
}

/// One cuisine accent.
///
/// Only three tones are needed: a container and its on-colour, which swap
/// roles between light and dark.
@immutable
class AccentTones {
  const AccentTones({
    required this.t10,
    required this.t30,
    required this.t90,
  });

  final Color t10;
  final Color t30;
  final Color t90;
}

/// How many accents every palette must define. See `CuisineAccents`.
const int cuisineAccentCount = 8;

/// The full tonal definition of one palette.
///
/// The constructor stays `const` so each palette can be a top-level constant.
/// That rules out asserting `accents.length` here — `.length` isn't available
/// in a const expression — so the accent-count invariant is held by
/// [CuisineAccents] (which needs exactly this many) and by
/// `palette_tones_test.dart`, rather than by an assert in this constructor.
@immutable
class PaletteTones {
  const PaletteTones({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.neutralVariant,
    required this.accents,
    required this.name,
  });

  final BrandTones primary;
  final BrandTones secondary;
  final BrandTones tertiary;
  final NeutralTones neutral;
  final NeutralVariantTones neutralVariant;

  /// Exactly [cuisineAccentCount] entries, spread around the colour wheel.
  final List<AccentTones> accents;

  /// Human-readable, language-independent identifier for the palette.
  ///
  /// A brand name (like "Mercado Fresco") is not translated, so this stays a
  /// plain string rather than an ARB lookup — the same treatment `app_name`
  /// gets in the Android app.
  final String name;
}
