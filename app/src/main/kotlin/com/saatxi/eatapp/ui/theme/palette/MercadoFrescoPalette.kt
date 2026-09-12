package com.saatxi.eatapp.ui.theme.palette

import androidx.compose.ui.graphics.Color
import com.saatxi.eatapp.ui.theme.AccentTones
import com.saatxi.eatapp.ui.theme.BrandTones
import com.saatxi.eatapp.ui.theme.NeutralTones
import com.saatxi.eatapp.ui.theme.NeutralVariantTones
import com.saatxi.eatapp.ui.theme.PaletteTones

/**
 * Mercado fresco ("fresh market"): the app's revamped default identity —
 * warm sand neutrals, a teal primary, a raspberry secondary used sparingly,
 * and a paprika/coral tertiary carrying the "visited" semantic that used to
 * ride on whatever the palette's tertiary happened to be.
 *
 * The tones below are hand-derived from the approved mockup's flat design
 * tokens (`.scratch/eatapp-revamp-mockups.html`) rather than generated from a
 * single HCT seed the way a Material color-scheme tool would: the mockup's
 * bg/surface/ink triad isn't a neutral ramp around one seed, so the light and
 * dark anchors below (t98/t10 for neutral, t40/t80 for each brand family) are
 * the mockup's literal hex values, with the intermediate stops interpolated
 * by hand to keep the ramp monotonic. `ColorSchemeContrastTest` still holds
 * the on-color contrast line the same way it does for every other palette.
 */
internal val MercadoFrescoTones = PaletteTones(
    // Teal — a1 / the button gradient's btn1 anchor. The mockup's flat
    // `#0ea895` reads fine as a small accent (button gradient, chip border)
    // but doesn't clear 4.5:1 for *white text on a filled tone*, which is
    // what M3's `onPrimary` demands of `primary` — so t40 here is `#0ea895`
    // darkened in place (same hue/saturation, scaled luminance) to
    // `#0b8475`, verified against `ColorSchemeContrastTest`. `#0ea895`
    // itself still appears as this app's brand teal wherever a small accent
    // over a light ground is enough (see `t80`, the dark-mode primary).
    primary = BrandTones(
        t10 = Color(0xFF04211D),
        t20 = Color(0xFF083F38),
        t30 = Color(0xFF0A5650),
        t40 = Color(0xFF0B8475),
        t80 = Color(0xFF7FE0D2),
        t90 = Color(0xFFBFF2EA),
        t95 = Color(0xFFDFF9F4)
    ),
    // Raspberry — a2, reserved for small accents (chip text/borders, thin
    // decorative details), not solid buttons. t40 is `#e5486b` darkened the
    // same way as primary's, for the same white-on-tone contrast reason.
    secondary = BrandTones(
        t10 = Color(0xFF2E0512),
        t20 = Color(0xFF4D0B22),
        t30 = Color(0xFF7A1836),
        t40 = Color(0xFFCF4161),
        t80 = Color(0xFFFF9CB3),
        t90 = Color(0xFFFFD9E2),
        t95 = Color(0xFFFFECF0)
    ),
    // Paprika/coral — the "good"/visited-status colour, deliberately a
    // different hue from the teal/raspberry accent pair. t40 is `#e0642a`
    // darkened the same way, again for onTertiary contrast.
    tertiary = BrandTones(
        t10 = Color(0xFF2B0800),
        t20 = Color(0xFF4A1400),
        t30 = Color(0xFF6E2308),
        t40 = Color(0xFFC05624),
        t80 = Color(0xFFFFB599),
        t90 = Color(0xFFFFDBCB),
        t95 = Color(0xFFFFEDE4)
    ),
    // Warm sand, tinted towards the mockup's bg/surface pair rather than left
    // grey — t94 is the light-mode `bg` (`#f4f1e6`), t98 is `surface`
    // (`#fffdf7`), t6 is the dark-mode `bg` (`#0f1512`).
    neutral = NeutralTones(
        t4 = Color(0xFF0A0D0B),
        t6 = Color(0xFF0F1512),
        t10 = Color(0xFF1A231F),
        t12 = Color(0xFF1D2621),
        t17 = Color(0xFF262F2A),
        t20 = Color(0xFF2C352F),
        t22 = Color(0xFF313A34),
        t24 = Color(0xFF353E38),
        t87 = Color(0xFFE6E2D2),
        t90 = Color(0xFFEDF0E3),
        t92 = Color(0xFFF0EEE0),
        t94 = Color(0xFFF4F1E6),
        t95 = Color(0xFFF6F4EA),
        t96 = Color(0xFFF8F6EE),
        t98 = Color(0xFFFFFDF7),
        t100 = Color(0xFFFFFFFF)
    ),
    // Outline family, tinted from the mockup's ink-soft/ink-faint hairline
    // colours rather than pure grey.
    neutralVariant = NeutralVariantTones(
        t30 = Color(0xFF3E4A43),
        t50 = Color(0xFF59685E),
        t60 = Color(0xFF788579),
        t80 = Color(0xFFB4C3B2),
        t90 = Color(0xFFD9DED2)
    ),
    accents = listOf(
        // Teal — shares the primary hue.
        AccentTones(Color(0xFF04211D), Color(0xFF0A5650), Color(0xFFBFF2EA)),
        // Raspberry
        AccentTones(Color(0xFF2E0512), Color(0xFF7A1836), Color(0xFFFFD9E2)),
        // Paprika/coral
        AccentTones(Color(0xFF2B0800), Color(0xFF6E2308), Color(0xFFFFDBCB)),
        // Marigold — the rating/highlight hue (`#f4b93c`).
        AccentTones(Color(0xFF271900), Color(0xFF6B4E00), Color(0xFFFFE1A6)),
        // Olive
        AccentTones(Color(0xFF1B1D00), Color(0xFF454B00), Color(0xFFD8E58C)),
        // Indigo
        AccentTones(Color(0xFF101B4E), Color(0xFF38427C), Color(0xFFDDE1FF)),
        // Plum
        AccentTones(Color(0xFF2C0F2E), Color(0xFF5C3A5E), Color(0xFFF8D8F6)),
        // Sage — pulled from the surface-2 tint rather than a distant hue, so
        // one cuisine chip reads as "at home" in the market palette.
        AccentTones(Color(0xFF141C0A), Color(0xFF35431F), Color(0xFFDCE8C8))
    )
)
