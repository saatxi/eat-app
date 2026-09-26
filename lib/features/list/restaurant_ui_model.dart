import 'package:flutter/foundation.dart';

import '../../core/utils/address_formatter.dart';
import '../../core/widgets/presentation_bounds.dart';
import '../../data/db/app_database.dart';

// Re-exported so call sites that already import this model keep seeing the two
// bounds, while the widgets under `core/widgets` read them from their own home.
export '../../core/widgets/presentation_bounds.dart';

/// The `Hero` tag that pairs a list row's thumbnail with the detail screen's
/// header, so tapping a row flies the image across instead of swapping screens
/// outright.
///
/// One function rather than a literal in each file, because the two ends have to
/// agree exactly — a mismatch silently loses the transition rather than failing.
String restaurantHeroTag(String restaurantId) =>
    'restaurant-hero-$restaurantId';

/// What the screens draw, kept separate from the drift [Restaurant] row so the
/// presentation decisions — which rating a row shows, whether a place counts as
/// visited — are made once here instead of being repeated inside widgets.
///
/// Anything that needs a string resource (the cuisine label, the "3/5" rating
/// text) stays in the widgets: resolving those needs a `BuildContext`, which the
/// controller deliberately doesn't have. The cuisine is therefore carried as its
/// raw vocabulary key and resolved at draw time.
///
/// [rating], [visited] and [notes] come from the restaurant's latest [Visit]
/// (there is at most one, in this pass's single-visit-per-restaurant UI) rather
/// than from the restaurant row itself — see [RestaurantToUiModel.toUiModel].
///
/// Value equality matters here rather than being boilerplate: the controller
/// compares the whole list it is about to publish with the one already on
/// screen and skips the rebuild when the two are equal, which is what stops
/// a tag write from repainting every row.
@immutable
class RestaurantUiModel {
  const RestaurantUiModel({
    required this.id,
    required this.name,
    required this.cuisineKey,
    this.streetAddress,
    this.city,
    this.region,
    this.country,
    this.rating = 0,
    this.priceRange = 0,
    this.visited = false,
    this.website,
    this.instagram,
    this.isFavorite = false,
    this.photoPath,
    this.notes,
    this.tagsLabel = '',
  });

  final String id;
  final String name;

  /// The stored `cuisineType` key, never a display label; unknown keys are kept
  /// verbatim rather than degraded, so a newer data file still reads correctly
  /// in an older build.
  final String cuisineKey;

  /// Street line only — null when absent or blank. See [formattedAddress].
  final String? streetAddress;
  final String? city;
  final String? region;
  final String? country;

  /// 0-5; 0 means unrated, which reads the same as "no visit yet".
  final int rating;

  /// 0-6, 0 meaning "not set" — turned into its display text at draw time.
  final int priceRange;

  /// False marks a place the user still wants to try, not one they have been to.
  final bool visited;

  /// Validated on import; null when absent or not safe to open.
  final String? website;

  /// Bare handle, no leading `@`.
  final String? instagram;

  final bool isFavorite;

  /// Absolute path to a locally-stored copy; null draws the cuisine badge
  /// instead. Only ever set on the screens that asked for it — the list query
  /// does not load photos.
  final String? photoPath;

  /// Free-text, user-written note from the latest visit. Null when blank, so
  /// the detail screen can just skip the card.
  final String? notes;

  /// Comma-and-space-joined tag names, e.g. `"Terraza, Para grupos"`; empty
  /// when there are none.
  ///
  /// A `List<String>` field here would make every instance unequal to the next
  /// one built from the same data (list identity), and the controller's
  /// "did anything change?" check would then never be able to skip a rebuild.
  /// [tags] splits it back apart for the widgets that need the parts; tag names
  /// are validated (`normalizeTagName`) to never contain a comma, so the split
  /// is unambiguous.
  final String tagsLabel;

  /// True when there is at least one link worth drawing a section for.
  bool get hasLinks => website != null || instagram != null;

  /// Every non-blank address component joined together, or null when there is
  /// nothing to join.
  String? get formattedAddress => formatAddress(
    streetAddress: streetAddress,
    city: city,
    region: region,
    country: country,
  );

  /// The tag names [tagsLabel] was built from.
  List<String> get tags =>
      tagsLabel.isEmpty ? const <String>[] : tagsLabel.split(', ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantUiModel &&
          other.id == id &&
          other.name == name &&
          other.cuisineKey == cuisineKey &&
          other.streetAddress == streetAddress &&
          other.city == city &&
          other.region == region &&
          other.country == country &&
          other.rating == rating &&
          other.priceRange == priceRange &&
          other.visited == visited &&
          other.website == website &&
          other.instagram == instagram &&
          other.isFavorite == isFavorite &&
          other.photoPath == photoPath &&
          other.notes == notes &&
          other.tagsLabel == tagsLabel;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    cuisineKey,
    streetAddress,
    city,
    region,
    country,
    rating,
    priceRange,
    visited,
    website,
    instagram,
    isFavorite,
    photoPath,
    notes,
    tagsLabel,
  );

  @override
  String toString() =>
      'RestaurantUiModel($id, $name, cuisine: $cuisineKey, rating: $rating, '
      'visited: $visited, favorite: $isFavorite)';
}

/// Builds the drawable shape out of a database row plus whatever the caller
/// already has to hand: which restaurants are favourites, their tags, their
/// latest visit and (on the screens that load them) a photo.
extension RestaurantToUiModel on Restaurant {
  RestaurantUiModel toUiModel({
    bool isFavorite = false,
    List<String> tags = const <String>[],
    Visit? latestVisit,
    String? photoPath,
  }) => RestaurantUiModel(
    id: id,
    name: name,
    cuisineKey: cuisineType,
    // A row whose address component is present but blank would otherwise draw
    // an empty location line; treat it the same as a missing one.
    streetAddress: _nonBlank(streetAddress),
    city: _nonBlank(city),
    region: _nonBlank(region),
    country: _nonBlank(country),
    rating: latestVisit?.rating ?? 0,
    // The reader already rejects out-of-range values, but clamping keeps a
    // hand-built row from producing a band outside the picker's scale.
    priceRange: priceRange.clamp(0, maxPriceRange),
    visited: latestVisit != null,
    website: website,
    instagram: instagram,
    isFavorite: isFavorite,
    photoPath: photoPath,
    notes: _nonBlank(latestVisit?.notes),
    tagsLabel: tags.join(', '),
  );

  static String? _nonBlank(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
