package com.saatxi.eatapp.ui.list

import com.saatxi.eatapp.data.local.RestaurantSort
import com.saatxi.eatapp.data.repository.RestaurantRepository
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
    val sort: RestaurantSort = RestaurantSort.NAME,
    val city: String? = null,
    val region: String? = null,
    val country: String? = null,
    val priceRange: Int? = null
)

/**
 * Debounces just the query field (skipping the debounce entirely when it's
 * blank — e.g. the field being cleared — so results reappear immediately),
 * while every other field reacts right away.
 *
 * Split into two combine() stages, each within kotlinx.coroutines' typed
 * 5-flow overload, rather than the untyped vararg one: the original five
 * fields build [primary] as before, then city/region/country are merged in
 * on top of it.
 */
@OptIn(FlowPreview::class)
internal fun Flow<RestaurantFilters>.debounced(): Flow<RestaurantFilters> {
    val primary = combine(
        map { it.query }.debounce { query -> if (query.isBlank()) 0L else SEARCH_DEBOUNCE_MS },
        map { it.minRating }.distinctUntilChanged(),
        map { it.cuisineType }.distinctUntilChanged(),
        map { it.visited }.distinctUntilChanged(),
        map { it.sort }.distinctUntilChanged(),
        ::RestaurantFilters
    )
    return combine(
        primary,
        map { it.city }.distinctUntilChanged(),
        map { it.region }.distinctUntilChanged(),
        map { it.country }.distinctUntilChanged(),
        map { it.priceRange }.distinctUntilChanged()
    ) { base, city, region, country, priceRange ->
        base.copy(city = city, region = region, country = country, priceRange = priceRange)
    }
}

/**
 * The values available to pick per filter dimension — shared by
 * [RestaurantListViewModel] and [com.saatxi.eatapp.ui.favorites.FavoritesViewModel] for the same
 * reason [RestaurantFilters] is: it also keeps each screen's outer `uiState` combine() within
 * kotlinx.coroutines' typed 5-flow overload (adding city/region/country there directly would push
 * it to 6 flows), by first combining these four into one.
 */
internal data class AvailableFilterValues(
    val cuisines: List<String> = emptyList(),
    val cities: List<String> = emptyList(),
    val regions: List<String> = emptyList(),
    val countries: List<String> = emptyList()
)

internal fun RestaurantRepository.observeAvailableFilterValues(): Flow<AvailableFilterValues> = combine(
    observeCuisineTypes(),
    observeCities(),
    observeRegions(),
    observeCountries(),
    ::AvailableFilterValues
)
