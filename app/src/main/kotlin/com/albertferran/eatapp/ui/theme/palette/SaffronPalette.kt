package com.albertferran.eatapp.ui.theme.palette

import androidx.compose.ui.graphics.Color
import com.albertferran.eatapp.ui.theme.AccentTones
import com.albertferran.eatapp.ui.theme.BrandTones
import com.albertferran.eatapp.ui.theme.NeutralTones
import com.albertferran.eatapp.ui.theme.NeutralVariantTones
import com.albertferran.eatapp.ui.theme.PaletteTones

/**
 * Saffron: a saturated, appetising orange with a teal counterweight and a plum
 * accent. The default palette, and the one carrying the app's identity — the
 * neutrals are tinted to the orange hue rather than left grey.
 */
internal val SaffronTones = PaletteTones(
    primary = BrandTones(
        t10 = Color(0xFF3A0B00),
        t20 = Color(0xFF5D1900),
        t30 = Color(0xFF862E0C),
        t40 = Color(0xFFB4471B),
        t80 = Color(0xFFFFB59B),
        t90 = Color(0xFFFFDBCF),
        t95 = Color(0xFFFFEDE7)
    ),
    secondary = BrandTones(
        t10 = Color(0xFF002022),
        t20 = Color(0xFF003739),
        t30 = Color(0xFF004F52),
        t40 = Color(0xFF00696D),
        t80 = Color(0xFF4DDADF),
        t90 = Color(0xFFA8F0F3),
        t95 = Color(0xFFD2F8FA)
    ),
    tertiary = BrandTones(
        t10 = Color(0xFF2E0B33),
        t20 = Color(0xFF46204A),
        t30 = Color(0xFF603663),
        t40 = Color(0xFF7A4E7E),
        t80 = Color(0xFFEBB5EE),
        t90 = Color(0xFFFFD7FB),
        t95 = Color(0xFFFFEBFB)
    ),
    neutral = NeutralTones(
        t4 = Color(0xFF0F0B09),
        t6 = Color(0xFF140F0D),
        t10 = Color(0xFF1F1613),
        t12 = Color(0xFF241A17),
        t17 = Color(0xFF302521),
        t20 = Color(0xFF372B27),
        t22 = Color(0xFF3C2F2B),
        t24 = Color(0xFF413430),
        t87 = Color(0xFFE5DBD6),
        t90 = Color(0xFFEDE3DE),
        t92 = Color(0xFFF2E8E3),
        t94 = Color(0xFFF8EEE9),
        t95 = Color(0xFFFAF1EC),
        t96 = Color(0xFFFCF4EF),
        t98 = Color(0xFFFFF8F6),
        t100 = Color(0xFFFFFFFF)
    ),
    neutralVariant = NeutralVariantTones(
        t30 = Color(0xFF53433C),
        t50 = Color(0xFF85736A),
        t60 = Color(0xFFA08D83),
        t80 = Color(0xFFD8C7BE),
        t90 = Color(0xFFF5E3DA)
    ),
    accents = listOf(
        // Orange — shares the primary hue, so the first cuisine reads as "brand".
        AccentTones(Color(0xFF3A0B00), Color(0xFF862E0C), Color(0xFFFFDBCF)),
        // Teal
        AccentTones(Color(0xFF002022), Color(0xFF004F52), Color(0xFFA8F0F3)),
        // Plum
        AccentTones(Color(0xFF2E0B33), Color(0xFF603663), Color(0xFFFFD7FB)),
        // Amber
        AccentTones(Color(0xFF271900), Color(0xFF6B4E00), Color(0xFFFFDEA6)),
        // Blue
        AccentTones(Color(0xFF001B3D), Color(0xFF1F4B7A), Color(0xFFD3E4FF)),
        // Raspberry
        AccentTones(Color(0xFF3F0018), Color(0xFF8C1D45), Color(0xFFFFD9E2)),
        // Green
        AccentTones(Color(0xFF002110), Color(0xFF005230), Color(0xFF9BF2C0)),
        // Indigo
        AccentTones(Color(0xFF150F5C), Color(0xFF3B3591), Color(0xFFE2DFFF))
    )
)
