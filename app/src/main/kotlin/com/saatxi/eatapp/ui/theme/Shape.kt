package com.saatxi.eatapp.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

// Rounded further than M3's defaults, per the revamp mockup's ~16-24dp card
// corners: `medium` (the shape most Card/Surface call sites pick up
// implicitly) moves from 16dp to 20dp and `large` from 24dp to 28dp, with
// `extraSmall`/`small` nudged to match rather than left at the old, sharper
// baseline next to them.
val Shapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(36.dp)
)
