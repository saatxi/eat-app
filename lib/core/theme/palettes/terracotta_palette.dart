import 'package:flutter/material.dart';

import '../tokens/palette_tones.dart';

/// Terracota: the app's single identity — a warm clay primary, an olive
/// secondary, a muted berry tertiary, over a cream neutral ramp.
///
/// The direction is "càlid i humanista": cream paper surfaces, terracotta
/// accents and soft, earthy counterpoints, so the app reads like a personal
/// notebook rather than a database. The ramps keep the hand-derived shape the
/// previous palette used: the light and dark anchors (t98/t6 for neutral,
/// t40/t80 for each brand family) are the approved mockup's literal hex
/// values, with the intermediate stops interpolated by hand so each ramp stays
/// monotonic. The on-colour contrast line is held by `color_contrast_test.dart`.
///
/// The terracotta primary is deliberately deep enough that white text clears AA
/// when it fills a button, while the dark-mode primary (t80) stays light enough
/// for its t20 on-colour. Clay and olive carry the interface; berry and the
/// accent ramp carry the colour the list cards lean on, so the app reads
/// "homely" rather than "rustic".
const PaletteTones terracottaTones = PaletteTones(
  name: 'Terracota',
  // Clay — the primary. t40 `#B05530` clears 4.5:1 for white text on a filled
  // button; t80 `#FFB59B` is the dark-mode primary.
  primary: BrandTones(
    t10: Color(0xFF3B0F00),
    t20: Color(0xFF5A1B08),
    t30: Color(0xFF7A2A12),
    t40: Color(0xFFB05530),
    t80: Color(0xFFFFB59B),
    t90: Color(0xFFFFDBCC),
    t95: Color(0xFFFFEDE5),
  ),
  // Olive — the secondary. t40 `#5F6D34` clears AA for white text; t80 is the
  // bright dark-mode secondary.
  secondary: BrandTones(
    t10: Color(0xFF1C2400),
    t20: Color(0xFF2C3800),
    t30: Color(0xFF44521A),
    t40: Color(0xFF5F6D34),
    t80: Color(0xFFC6D18A),
    t90: Color(0xFFE3EBAF),
    t95: Color(0xFFEFF4CB),
  ),
  // Berry — the tertiary, carrying the warm, appetising counterpoint.
  tertiary: BrandTones(
    t10: Color(0xFF3E0A22),
    t20: Color(0xFF5C0A33),
    t30: Color(0xFF7A1444),
    t40: Color(0xFF9A4A62),
    t80: Color(0xFFF2B8C6),
    t90: Color(0xFFFFD9E2),
    t95: Color(0xFFFFECF0),
  ),
  // Cream neutrals: t98 is the light surface (`#FDF8F2`), t6 the dark-mode
  // surface (`#1A1310`).
  neutral: NeutralTones(
    t4: Color(0xFF120E0A),
    t6: Color(0xFF1A1310),
    t10: Color(0xFF201814),
    t12: Color(0xFF241C17),
    t17: Color(0xFF2C231D),
    t20: Color(0xFF352A23),
    t22: Color(0xFF3A2F28),
    t24: Color(0xFF3F342C),
    t87: Color(0xFFE8DFD3),
    t90: Color(0xFFEDE5DA),
    t92: Color(0xFFF1EAE0),
    t94: Color(0xFFF5EFE6),
    t95: Color(0xFFF7F2EA),
    t96: Color(0xFFF9F4ED),
    t98: Color(0xFFFDF8F2),
    t100: Color(0xFFFFFFFF),
  ),
  // Outline family, tinted towards the cream neutrals rather than left grey.
  neutralVariant: NeutralVariantTones(
    t30: Color(0xFF4E453C),
    t50: Color(0xFF857A6E),
    t60: Color(0xFF9E9385),
    t80: Color(0xFFCFC3B5),
    t90: Color(0xFFE7DED2),
  ),
  accents: <AccentTones>[
    // Clay — shares the primary hue.
    AccentTones(t10: Color(0xFF3B0F00), t30: Color(0xFF7A2A12), t90: Color(0xFFFFDBCC)),
    // Olive — shares the secondary hue.
    AccentTones(t10: Color(0xFF1C2400), t30: Color(0xFF44521A), t90: Color(0xFFE3EBAF)),
    // Honey
    AccentTones(t10: Color(0xFF3A2400), t30: Color(0xFF6B4A00), t90: Color(0xFFFFE3B0)),
    // Berry — shares the tertiary hue.
    AccentTones(t10: Color(0xFF3E0A22), t30: Color(0xFF6B1440), t90: Color(0xFFFFD9E2)),
    // Plum
    AccentTones(t10: Color(0xFF2A1245), t30: Color(0xFF3E2466), t90: Color(0xFFE7DCFB)),
    // Teal — a cool counterpoint to the warm clay.
    AccentTones(t10: Color(0xFF00382F), t30: Color(0xFF0F5044), t90: Color(0xFFB7EBE1)),
    // Rust
    AccentTones(t10: Color(0xFF4A0F1E), t30: Color(0xFF7A2434), t90: Color(0xFFFFD8DC)),
    // Sage — a soft herbal green.
    AccentTones(t10: Color(0xFF1A2E1E), t30: Color(0xFF2E4A32), t90: Color(0xFFC9E6CB)),
  ],
);
