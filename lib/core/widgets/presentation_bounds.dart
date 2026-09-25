/// The bounds the restaurant data is drawn on.
///
/// Kept in one place so the widgets that render a star rating or a price band
/// and the model that clamps the values cannot disagree about where the scale
/// ends. Ported from the Android app's `RatingAndPriceRow`/`PriceRangePicker`
/// top-level constants, which played the same role.
library;

/// Stars the rating scale is drawn on.
const int maxRating = 5;

/// Widest price band the source data can hold. 0 is not the cheapest band, it
/// is "not set", and the picker starts at 1 — see `priceRangeLabel`.
const int maxPriceRange = 6;
