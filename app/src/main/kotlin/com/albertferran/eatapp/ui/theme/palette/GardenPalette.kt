package com.albertferran.eatapp.ui.theme.palette

import androidx.compose.ui.graphics.Color
import com.albertferran.eatapp.ui.theme.AccentTones
import com.albertferran.eatapp.ui.theme.BrandTones
import com.albertferran.eatapp.ui.theme.NeutralTones
import com.albertferran.eatapp.ui.theme.NeutralVariantTones
import com.albertferran.eatapp.ui.theme.PaletteTones

/**
 * Garden: a deep, natural green with an amber accent. The most sober of the
 * three — the accents are pulled towards earth and foliage hues rather than
 * spread evenly, so the list reads as a market rather than a dashboard.
 */
internal val GardenTones = PaletteTones(
    primary = BrandTones(
        t10 = Color(0xFF00210E),
        t20 = Color(0xFF00391C),
        t30 = Color(0xFF00522A),
        t40 = Color(0xFF226B3E),
        t80 = Color(0xFF8FD9A6),
        t90 = Color(0xFFABF3C1),
        t95 = Color(0xFFC7FFD8)
    ),
    secondary = BrandTones(
        t10 = Color(0xFF261A00),
        t20 = Color(0xFF402D00),
        t30 = Color(0xFF5C4200),
        t40 = Color(0xFF7A5900),
        t80 = Color(0xFFF3C03F),
        t90 = Color(0xFFFFDF95),
        t95 = Color(0xFFFFEFCE)
    ),
    tertiary = BrandTones(
        t10 = Color(0xFF001F26),
        t20 = Color(0xFF00363F),
        t30 = Color(0xFF1E4D56),
        t40 = Color(0xFF38656E),
        t80 = Color(0xFFA0CFDA),
        t90 = Color(0xFFBCEBF6),
        t95 = Color(0xFFDDF6FB)
    ),
    neutral = NeutralTones(
        t4 = Color(0xFF060D08),
        t6 = Color(0xFF0A120C),
        t10 = Color(0xFF111811),
        t12 = Color(0xFF151C16),
        t17 = Color(0xFF202721),
        t20 = Color(0xFF252C26),
        t22 = Color(0xFF29302A),
        t24 = Color(0xFF2E352F),
        t87 = Color(0xFFDCE4DC),
        t90 = Color(0xFFE4ECE3),
        t92 = Color(0xFFE9F1E8),
        t94 = Color(0xFFEFF6EE),
        t95 = Color(0xFFF2F9F0),
        t96 = Color(0xFFF4FBF2),
        t98 = Color(0xFFF9FEF7),
        t100 = Color(0xFFFFFFFF)
    ),
    neutralVariant = NeutralVariantTones(
        t30 = Color(0xFF3F4A40),
        t50 = Color(0xFF6F7B70),
        t60 = Color(0xFF899589),
        t80 = Color(0xFFC0CCC0),
        t90 = Color(0xFFDCE8DB)
    ),
    accents = listOf(
        // Green — shares the primary hue.
        AccentTones(Color(0xFF00210E), Color(0xFF00522A), Color(0xFFABF3C1)),
        // Amber
        AccentTones(Color(0xFF261A00), Color(0xFF5C4200), Color(0xFFFFDF95)),
        // Blue-green
        AccentTones(Color(0xFF001F26), Color(0xFF1E4D56), Color(0xFFBCEBF6)),
        // Terracotta
        AccentTones(Color(0xFF390B00), Color(0xFF7E2E10), Color(0xFFFFDBCE)),
        // Olive
        AccentTones(Color(0xFF1B1D00), Color(0xFF454B00), Color(0xFFD8E58C)),
        // Indigo
        AccentTones(Color(0xFF101B4E), Color(0xFF38427C), Color(0xFFDDE1FF)),
        // Plum
        AccentTones(Color(0xFF2C0F2E), Color(0xFF5C3A5E), Color(0xFFF8D8F6)),
        // Rust
        AccentTones(Color(0xFF3B0A0A), Color(0xFF7F2C2C), Color(0xFFFFDAD5))
    )
)
