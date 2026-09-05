package com.saatxi.eatapp.data.local

/** One row of `RestaurantDao.observeCuisineCounts()` — how many restaurants hold a given cuisine key. */
data class CuisineCount(val cuisineType: String, val count: Int)

/** One row of `RestaurantDao.observePriceRangeCounts()` — how many restaurants hold a given price range (0-4). */
data class PriceRangeCount(val priceRange: Int, val count: Int)
