package com.albertferran.eatapp.ui.theme.palette

import androidx.compose.ui.graphics.Color
import com.albertferran.eatapp.ui.theme.AccentTones
import com.albertferran.eatapp.ui.theme.BrandTones
import com.albertferran.eatapp.ui.theme.NeutralTones
import com.albertferran.eatapp.ui.theme.NeutralVariantTones
import com.albertferran.eatapp.ui.theme.PaletteTones

/**
 * Indigo: a cool indigo with a warm coral accent. The coolest of the three,
 * with near-grey neutrals — the accents carry all of the colour, which is what
 * makes a long list read as varied rather than tinted.
 */
internal val IndigoTones = PaletteTones(
    primary = BrandTones(
        t10 = Color(0xFF00105C),
        t20 = Color(0xFF182878),
        t30 = Color(0xFF313E90),
        t40 = Color(0xFF4A57A9),
        t80 = Color(0xFFB9C3FF),
        t90 = Color(0xFFDEE0FF),
        t95 = Color(0xFFF0EFFF)
    ),
    secondary = BrandTones(
        t10 = Color(0xFF410004),
        t20 = Color(0xFF601A18),
        t30 = Color(0xFF7E2D2C),
        t40 = Color(0xFF9C4341),
        t80 = Color(0xFFFFB3AE),
        t90 = Color(0xFFFFDAD6),
        t95 = Color(0xFFFFEDEA)
    ),
    tertiary = BrandTones(
        t10 = Color(0xFF092016),
        t20 = Color(0xFF1F352A),
        t30 = Color(0xFF354B40),
        t40 = Color(0xFF4C6357),
        t80 = Color(0xFFB2CCBD),
        t90 = Color(0xFFCEE9D8),
        t95 = Color(0xFFDCF7E6)
    ),
    neutral = NeutralTones(
        t4 = Color(0xFF08090E),
        t6 = Color(0xFF0D0E13),
        t10 = Color(0xFF121318),
        t12 = Color(0xFF16171C),
        t17 = Color(0xFF202126),
        t20 = Color(0xFF26272C),
        t22 = Color(0xFF2A2B30),
        t24 = Color(0xFF2E2F35),
        t87 = Color(0xFFDCDCE3),
        t90 = Color(0xFFE4E4EB),
        t92 = Color(0xFFE9E9F0),
        t94 = Color(0xFFEFEFF6),
        t95 = Color(0xFFF2F1F9),
        t96 = Color(0xFFF5F4FB),
        t98 = Color(0xFFFBF8FF),
        t100 = Color(0xFFFFFFFF)
    ),
    neutralVariant = NeutralVariantTones(
        t30 = Color(0xFF45464F),
        t50 = Color(0xFF767680),
        t60 = Color(0xFF90909A),
        t80 = Color(0xFFC6C6D0),
        t90 = Color(0xFFE2E1EC)
    ),
    accents = listOf(
        // Indigo — shares the primary hue.
        AccentTones(Color(0xFF00105C), Color(0xFF313E90), Color(0xFFDEE0FF)),
        // Coral
        AccentTones(Color(0xFF410004), Color(0xFF7E2D2C), Color(0xFFFFDAD6)),
        // Sage
        AccentTones(Color(0xFF092016), Color(0xFF354B40), Color(0xFFCEE9D8)),
        // Cyan
        AccentTones(Color(0xFF001F25), Color(0xFF004E5C), Color(0xFFB4EBF8)),
        // Violet
        AccentTones(Color(0xFF240A45), Color(0xFF513A7A), Color(0xFFE9DDFF)),
        // Amber
        AccentTones(Color(0xFF271900), Color(0xFF6B4E00), Color(0xFFFFDEA6)),
        // Pink
        AccentTones(Color(0xFF3E0021), Color(0xFF8A2A5B), Color(0xFFFFD8E9)),
        // Blue
        AccentTones(Color(0xFF001B3D), Color(0xFF1F4B7A), Color(0xFFD3E4FF))
    )
)
