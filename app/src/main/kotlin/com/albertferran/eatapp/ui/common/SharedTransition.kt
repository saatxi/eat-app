@file:OptIn(ExperimentalSharedTransitionApi::class)

package com.albertferran.eatapp.ui.common

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.BoundsTransform
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier

/**
 * Plumbing for the list -> detail shared-element transition.
 *
 * Compose needs two scopes to match an element across destinations: the one that
 * owns the shared layout, and the one that animates the destination. Both are
 * provided once by the NavHost and read back here rather than threaded through
 * every screen signature — the screens only ever ask for the modifier.
 *
 * When either scope is missing — anything composed outside the NavHost — the
 * modifier is a no-op, so the screens stay composable on their own.
 */
val LocalSharedTransitionScope = staticCompositionLocalOf<SharedTransitionScope?> { null }

/** The [AnimatedVisibilityScope] of the nav destination currently being composed. */
val LocalNavAnimatedVisibilityScope = staticCompositionLocalOf<AnimatedVisibilityScope?> { null }

/**
 * How long the whole list <-> detail transition takes. The destinations cross-fade
 * over the same span as the badge travels, so the two read as one movement.
 */
const val SCREEN_TRANSITION_DURATION_MS = 320

private val badgeBoundsTransform = BoundsTransform { _, _ ->
    tween(durationMillis = SCREEN_TRANSITION_DURATION_MS, easing = FastOutSlowInEasing)
}

/**
 * Marks the cuisine icon of [restaurantId] as the element that carries the motion
 * between the list row and the detail top app bar.
 *
 * `sharedBounds` rather than `sharedElement`: the two are deliberately not drawn
 * the same — a filled disc in the list, a bare icon on the tinted bar — so the
 * bounds animate while the contents cross-fade.
 */
@Composable
fun Modifier.cuisineBadgeTransition(restaurantId: Long): Modifier {
    val sharedTransitionScope = LocalSharedTransitionScope.current
    val animatedVisibilityScope = LocalNavAnimatedVisibilityScope.current
    if (sharedTransitionScope == null || animatedVisibilityScope == null) return this

    return with(sharedTransitionScope) {
        this@cuisineBadgeTransition.sharedBounds(
            sharedContentState = rememberSharedContentState(key = "cuisine-badge-$restaurantId"),
            animatedVisibilityScope = animatedVisibilityScope,
            boundsTransform = badgeBoundsTransform
        )
    }
}
