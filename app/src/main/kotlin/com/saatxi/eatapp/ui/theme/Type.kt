package com.saatxi.eatapp.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.saatxi.eatapp.R

/**
 * Newsreader, a literary serif with an italic cut, bundled as static weights
 * at `res/font/newsreader_*.ttf` (SIL OFL, see
 * `app/licenses/OFL-Newsreader.txt`). It is not a variable font — unlike
 * Outfit before it, Google only ships static instances of Newsreader's
 * upright and italic axes through the CSS API this project pulled from — so
 * one `Font` entry per weight/style pair is bundled instead of one file with
 * `FontVariation` settings.
 *
 * Carries display, headline and title: the mockup's large, slightly literary
 * restaurant names and screen titles. Regular weight for the biggest display
 * sizes reads as editorial rather than shouty; italic is reserved for the
 * places a screen wants a quieter, secondary accent (not wired into the
 * scale below, but available as `NewsreaderItalic` for a call site that
 * wants it).
 */
private val Newsreader = FontFamily(
    Font(R.font.newsreader_regular, weight = FontWeight.Normal),
    Font(R.font.newsreader_medium, weight = FontWeight.Medium),
    Font(R.font.newsreader_semibold, weight = FontWeight.SemiBold),
    Font(R.font.newsreader_bold, weight = FontWeight.Bold),
    Font(R.font.newsreader_italic, weight = FontWeight.Normal, style = FontStyle.Italic),
    Font(R.font.newsreader_semibold_italic, weight = FontWeight.SemiBold, style = FontStyle.Italic)
)

/** For call sites that want the mockup's italic serif accent explicitly. */
val NewsreaderItalic = Newsreader

/**
 * Manrope, a rounded geometric sans, bundled as static weights at
 * `res/font/manrope_*.ttf` (SIL OFL, see `app/licenses/OFL-Manrope.txt`).
 * Replaces both the old bundled Outfit face and the plain system-font
 * fallback body text used to have — body and label text now gets the same
 * bundled, hinted-for-this-brand face as the display styles, closing the gap
 * the previous `Type.kt` deliberately left (the doc comment on the old
 * `Typography` explained why body stayed on the system font; the revamp's
 * mockup calls for the whole UI, not just headings, to read as one typeface
 * family).
 */
private val Manrope = FontFamily(
    Font(R.font.manrope_regular, weight = FontWeight.Normal),
    Font(R.font.manrope_medium, weight = FontWeight.Medium),
    Font(R.font.manrope_semibold, weight = FontWeight.SemiBold),
    Font(R.font.manrope_bold, weight = FontWeight.Bold),
    Font(R.font.manrope_extrabold, weight = FontWeight.ExtraBold)
)

/**
 * The whole M3 scale is spelled out, as it was before: display/headline/title
 * on the serif (Newsreader), body/label on the sans (Manrope) — the same
 * split rationale as the previous Outfit/system-font pairing, just with both
 * halves now bundled brand faces instead of one bundled and one system.
 */
val Typography = Typography(
    displayLarge = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.Normal,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = (-0.25).sp
    ),
    displayMedium = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.Normal,
        fontSize = 45.sp,
        lineHeight = 52.sp,
        letterSpacing = 0.sp
    ),
    displaySmall = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.Normal,
        fontSize = 36.sp,
        lineHeight = 44.sp,
        letterSpacing = 0.sp
    ),
    headlineLarge = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.SemiBold,
        fontSize = 32.sp,
        lineHeight = 40.sp,
        letterSpacing = 0.sp
    ),
    headlineMedium = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.SemiBold,
        fontSize = 28.sp,
        lineHeight = 36.sp,
        letterSpacing = 0.sp
    ),
    headlineSmall = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp,
        lineHeight = 32.sp,
        letterSpacing = 0.sp
    ),
    titleLarge = TextStyle(
        fontFamily = Newsreader,
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp
    ),
    titleMedium = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.SemiBold,
        fontSize = 18.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp
    ),
    titleSmall = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp
    ),
    bodySmall = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.4.sp
    ),
    labelLarge = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    labelMedium = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    ),
    labelSmall = TextStyle(
        fontFamily = Manrope,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
)
