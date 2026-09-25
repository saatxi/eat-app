import 'package:flutter/foundation.dart';

import '../list/restaurant_ui_model.dart';

/// One visit card in the detail screen's timeline.
@immutable
class VisitUiModel {
  const VisitUiModel({
    required this.id,
    required this.visitDate,
    required this.rating,
    this.notes,
    this.priceRange = 0,
    this.photoPaths = const <String>[],
  });

  final String id;

  /// Epoch millis; formatted at draw time so the controller stays context-free.
  final int visitDate;
  final int rating;

  /// Null when blank, so the card can just skip the note.
  final String? notes;

  /// 0-6, 0 meaning "not set".
  final int priceRange;

  final List<String> photoPaths;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitUiModel &&
          other.id == id &&
          other.visitDate == visitDate &&
          other.rating == rating &&
          other.notes == notes &&
          other.priceRange == priceRange &&
          listEquals(other.photoPaths, photoPaths);

  @override
  int get hashCode => Object.hash(
    id,
    visitDate,
    rating,
    notes,
    priceRange,
    Object.hashAll(photoPaths),
  );
}

/// One point of a restaurant's own rating-over-time trend.
@immutable
class RatingPoint {
  const RatingPoint({required this.visitDate, required this.rating});

  final int visitDate;
  final int rating;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatingPoint &&
          other.visitDate == visitDate &&
          other.rating == rating;

  @override
  int get hashCode => Object.hash(visitDate, rating);
}

/// Below this many visits, a trend line has nothing to show a slope with.
const int minVisitsForTrend = 2;

/// Everything the detail screen draws.
///
/// [DetailLoading] is distinct from [DetailNotFound] because the initial state
/// would otherwise flash "restaurant not found" for a frame on every open — the
/// same reason the list carries an `isInitialLoad` flag.
sealed class DetailState {
  const DetailState();
}

class DetailLoading extends DetailState {
  const DetailLoading();

  @override
  bool operator ==(Object other) => other is DetailLoading;

  @override
  int get hashCode => 0;
}

class DetailNotFound extends DetailState {
  const DetailNotFound();

  @override
  bool operator ==(Object other) => other is DetailNotFound;

  @override
  int get hashCode => 1;
}

class DetailLoaded extends DetailState {
  const DetailLoaded({
    required this.restaurant,
    required this.visits,
    this.ratingTrend = const <RatingPoint>[],
  });

  final RestaurantUiModel restaurant;

  /// Newest first, as the query returns them.
  final List<VisitUiModel> visits;

  /// This restaurant's own visits, oldest first, for the small chart above the
  /// timeline — empty unless there are at least [minVisitsForTrend] visits.
  final List<RatingPoint> ratingTrend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailLoaded &&
          other.restaurant == restaurant &&
          listEquals(other.visits, visits) &&
          listEquals(other.ratingTrend, ratingTrend);

  @override
  int get hashCode => Object.hash(
    restaurant,
    Object.hashAll(visits),
    Object.hashAll(ratingTrend),
  );
}
