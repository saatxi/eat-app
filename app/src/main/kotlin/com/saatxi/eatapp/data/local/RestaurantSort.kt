package com.saatxi.eatapp.data.local

/**
 * The orders the restaurant list can be shown in.
 *
 * [RATING] is highest-first and falls back to the name order within a rating,
 * so both orders are stable: the same data always comes back in the same
 * sequence, whichever one is picked.
 */
enum class RestaurantSort {
    NAME,
    RATING
}
