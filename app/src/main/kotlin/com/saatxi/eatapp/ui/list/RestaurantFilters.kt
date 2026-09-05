package com.saatxi.eatapp.ui.list

import com.saatxi.eatapp.data.local.RestaurantSort
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map

private const val SEARCH_DEBOUNCE_MS = 250L

/**
 * The five inputs `RestaurantDao.observeFiltered` is built from — shared by
 * [RestaurantListViewModel] and
 * [com.saatxi.eatapp.ui.favorites.FavoritesViewModel] (F-60) so the two
 * screens' search/sort/filter state can't quietly drift out of shape with
 * each other.
 */
internal data class RestaurantFilters(
    val query: String = "",
    val minRating: Int? = null,
    val cuisineType: String? = null,
    val visited: Boolean? = null,
    // Not a filter in the "narrows the list down" sense — it rides along here
    // because it is the fifth input the repository query is built from.
    val sort: RestaurantSort = RestaurantSort.NAME
)

/**
 * Debounces just the query field (skipping the debounce entirely when it's
 * blank — e.g. the field being cleared — so results reappear immediately),
 * while every other field reacts right away.
 */
@OptIn(FlowPreview::class)
internal fun Flow<RestaurantFilters>.debounced(): Flow<RestaurantFilters> = combine(
    map { it.query }.debounce { query -> if (query.isBlank()) 0L else SEARCH_DEBOUNCE_MS },
    map { it.minRating }.distinctUntilChanged(),
    map { it.cuisineType }.distinctUntilChanged(),
    map { it.visited }.distinctUntilChanged(),
    map { it.sort }.distinctUntilChanged(),
    ::RestaurantFilters
)
