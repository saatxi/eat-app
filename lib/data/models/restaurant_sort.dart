/// The orders the restaurant list can be shown in.
///
/// [rating] is highest-first and falls back to the name order within a rating,
/// so both orders are stable: the same data always comes back in the same
/// sequence, whichever one is picked.
enum RestaurantSort {
  name,
  rating;

  /// The same orders once more, in the sequence the picker offers them.
  static const List<RestaurantSort> selectable = <RestaurantSort>[
    RestaurantSort.name,
    RestaurantSort.rating,
  ];
}
