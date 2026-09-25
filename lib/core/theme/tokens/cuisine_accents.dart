import 'package:flutter/material.dart';

import 'palette_tones.dart';

/// A container colour and the colour that is legible on top of it.
@immutable
class CuisineTint {
  const CuisineTint({required this.container, required this.onContainer});

  final Color container;
  final Color onContainer;
}

/// The accent set of the active palette, published alongside the `ColorScheme`
/// because it is theme data Material's scheme has no room for.
///
/// Cuisines used to be spread over the three container roles, which meant 24
/// cuisines cycling through the same three colours — the list read as striped
/// rather than varied. Eight accents is enough that a screenful of rows rarely
/// repeats, while still being a hand-checked set rather than a hash of the key.
///
/// Implemented as a [ThemeExtension] so it travels with `ThemeData` and is
/// reachable from any widget through [CuisineAccents.of], rather than through
/// a bespoke `InheritedWidget`.
@immutable
class CuisineAccents extends ThemeExtension<CuisineAccents> {
  const CuisineAccents(this.slots)
      : assert(
          slots.length == cuisineAccentCount,
          'expected $cuisineAccentCount accents, got ${slots.length}',
        );

  /// Light mode: a light container with a dark on-colour.
  factory CuisineAccents.light(PaletteTones tones) => CuisineAccents(
        <CuisineTint>[
          for (final AccentTones accent in tones.accents)
            CuisineTint(container: accent.t90, onContainer: accent.t10),
        ],
      );

  /// Dark mode inverts the pair, keeping the two in step with the container
  /// roles of the scheme so a cuisine badge next to a `primaryContainer` chip
  /// doesn't look like it came from a different design.
  factory CuisineAccents.dark(PaletteTones tones) => CuisineAccents(
        <CuisineTint>[
          for (final AccentTones accent in tones.accents)
            CuisineTint(container: accent.t30, onContainer: accent.t90),
        ],
      );

  final List<CuisineTint> slots;

  /// Reads the accents of the active theme. Throws during development if the
  /// theme was not built by `AppTheme`, since every cuisine-aware widget
  /// depends on this being present.
  static CuisineAccents of(BuildContext context) {
    final CuisineAccents? accents = Theme.of(context).extension<CuisineAccents>();
    assert(accents != null, 'No CuisineAccents in the active theme — build it with AppTheme.');
    return accents!;
  }

  /// Wraps, so any index is valid and the caller never has to bounds-check.
  CuisineTint operator [](int index) => slots[index % slots.length];

  @override
  CuisineAccents copyWith({List<CuisineTint>? slots}) =>
      CuisineAccents(slots ?? this.slots);

  @override
  CuisineAccents lerp(covariant CuisineAccents? other, double t) {
    if (other == null) {
      return this;
    }
    return CuisineAccents(<CuisineTint>[
      for (int i = 0; i < slots.length; i++)
        CuisineTint(
          container: Color.lerp(slots[i].container, other.slots[i].container, t)!,
          onContainer: Color.lerp(slots[i].onContainer, other.slots[i].onContainer, t)!,
        ),
    ]);
  }
}
