/// One row of `RestaurantDao.observeCuisineCounts()` — how many restaurants hold
/// a given cuisine key.
class CuisineCount {
  const CuisineCount({required this.cuisineType, required this.count});

  final String cuisineType;
  final int count;
}

/// One row of `RestaurantDao.observePriceRangeCounts()` — how many restaurants
/// hold a given price range (0-6).
class PriceRangeCount {
  const PriceRangeCount({required this.priceRange, required this.count});

  final int priceRange;
  final int count;
}

/// One row of `TagDao.observeTagCounts()` — how many restaurants carry a given
/// tag.
class TagCount {
  const TagCount({required this.name, required this.count});

  final String name;
  final int count;
}

/// One visit's date and rating, projected for the global rating-trend chart —
/// see `VisitDao.observeAllVisitDateRatings()`.
class VisitDateRating {
  const VisitDateRating({required this.visitDate, required this.rating});

  /// Epoch millis.
  final int visitDate;
  final int rating;
}

/// One restaurant/tag-name pair, projected for
/// `TagDao.observeAllRestaurantTagLinks()` — the caller groups them by
/// restaurant id.
class RestaurantTagName {
  const RestaurantTagName({required this.restaurantId, required this.name});

  final String restaurantId;
  final String name;
}
