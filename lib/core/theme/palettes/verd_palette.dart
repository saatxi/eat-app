import 'package:flutter/material.dart';

import '../tokens/palette_tones.dart';

/// Verd ("green"): the app's single identity — deep-forest primary, a citrus
/// (olive-lime) secondary, a berry tertiary, over a leaf-tinted neutral ramp.
///
/// The app used to ship three selectable palettes; it now ships this one. The
/// ramps keep the same hand-derived shape the old palettes used: the light and
/// dark anchors (t98/t10 for neutral, t40/t80 for each brand family) are the
/// approved mockup's literal hex values, with the intermediate stops
/// interpolated by hand so each ramp stays monotonic. The on-colour contrast
/// line is held by `color_contrast_test.dart`.
///
/// The forest primary is deliberately dark enough that white text clears AA
/// when it fills a button, while the dark-mode primary (t80) stays light enough
/// for its t20 on-colour. Forest and citrus carry the interface; berry and the
/// accent ramp carry the colour the list rows lean on, so the app reads
/// "fresh" rather than "eco".
const PaletteTones verdTones = PaletteTones(
  name: 'Verd',
  // Forest — the primary. t40 `#1F6E43` clears 4.5:1 for white text on a
  // filled button; t80 `#A5D8B0` is the dark-mode primary.
  primary: BrandTones(
    t10: Color(0xFF042316),
    t20: Color(0xFF062A16),
    t30: Color(0xFF174B2F),
    t40: Color(0xFF1F6E43),
    t80: Color(0xFFA5D8B0),
    t90: Color(0xFFC9EED2),
    t95: Color(0xFFDFF3E4),
  ),
  // Citrus (olive-lime) — the secondary. t40 is darkened from the mockup's
  // citrus `#E3F09B` family until white text clears AA; t80 is the bright
  // dark-mode secondary.
  secondary: BrandTones(
    t10: Color(0xFF1E2400),
    t20: Color(0xFF2F3800),
    t30: Color(0xFF46530A),
    t40: Color(0xFF5F6D00),
    t80: Color(0xFFD7E63C),
    t90: Color(0xFFE3F09B),
    t95: Color(0xFFEFF7C7),
  ),
  // Berry — the tertiary, carrying the warm, appetising counterpoint.
  tertiary: BrandTones(
    t10: Color(0xFF3E0020),
    t20: Color(0xFF5C0A33),
    t30: Color(0xFF7A1444),
    t40: Color(0xFFA52A5E),
    t80: Color(0xFFFFB0C8),
    t90: Color(0xFFFFD6E2),
    t95: Color(0xFFFFE8EF),
  ),
  // Leaf-tinted neutrals: t98 is the light surface (`#FBFDF7`), t6 the
  // dark-mode surface (`#0F1510`).
  neutral: NeutralTones(
    t4: Color(0xFF0B110C),
    t6: Color(0xFF0F1510),
    t10: Color(0xFF151A14),
    t12: Color(0xFF191F19),
    t17: Color(0xFF1F261F),
    t20: Color(0xFF242C24),
    t22: Color(0xFF282F28),
    t24: Color(0xFF2C342C),
    t87: Color(0xFFE2E9DC),
    t90: Color(0xFFE8EFE2),
    t92: Color(0xFFECF1E7),
    t94: Color(0xFFF0F4EB),
    t95: Color(0xFFF2F6EE),
    t96: Color(0xFFF5F8F2),
    t98: Color(0xFFFBFDF7),
    t100: Color(0xFFFFFFFF),
  ),
  // Outline family, tinted towards the leaf neutrals rather than left grey.
  neutralVariant: NeutralVariantTones(
    t30: Color(0xFF3F4A3C),
    t50: Color(0xFF717D6E),
    t60: Color(0xFF8B9887),
    t80: Color(0xFFC8D3C2),
    t90: Color(0xFFE2EADF),
  ),
  accents: <AccentTones>[
    // Fern — shares the primary hue.
    AccentTones(t10: Color(0xFF062A16), t30: Color(0xFF1E4A2E), t90: Color(0xFFC9EED2)),
    // Lime
    AccentTones(t10: Color(0xFF1E2400), t30: Color(0xFF46530A), t90: Color(0xFFE3F09B)),
    // Citrus
    AccentTones(t10: Color(0xFF3A2A00), t30: Color(0xFF6B4E00), t90: Color(0xFFFFE8AE)),
    // Berry — shares the tertiary hue.
    AccentTones(t10: Color(0xFF3E0020), t30: Color(0xFF6B1440), t90: Color(0xFFFFD6E2)),
    // Plum
    AccentTones(t10: Color(0xFF2A1245), t30: Color(0xFF3E2466), t90: Color(0xFFE7DCFB)),
    // Teal — a cool counterpoint to the forest green.
    AccentTones(t10: Color(0xFF00382F), t30: Color(0xFF0F5044), t90: Color(0xFFB7EBE1)),
    // Honey
    AccentTones(t10: Color(0xFF3A2400), t30: Color(0xFF5E3E0A), t90: Color(0xFFFFE0B0)),
    // Clay
    AccentTones(t10: Color(0xFF45180A), t30: Color(0xFF7A2E18), t90: Color(0xFFFFD9CB)),
  ],
);
