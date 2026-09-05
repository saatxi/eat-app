package com.saatxi.eatapp.ui.common

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * A pulsing block standing in for text/an image while a screen's real content
 * is still loading (F-67) — shape-matching skeletons instead of one centred
 * spinner, so the list/detail screens read as faster even at the same actual
 * load time. No animation library needed: a plain [rememberInfiniteTransition]
 * fading a tinted box in and out.
 */
@Composable
fun Modifier.shimmerPlaceholder(shape: Shape = RoundedCornerShape(4.dp)): Modifier {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val alpha by transition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 700, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "shimmer-alpha"
    )
    return this
        .clip(shape)
        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = alpha * 0.11f))
}

/** Same tinted-circle badge shape every cuisine badge uses, just pulsing instead of drawing an icon. */
@Composable
fun Modifier.shimmerCircle(): Modifier = shimmerPlaceholder(CircleShape)
