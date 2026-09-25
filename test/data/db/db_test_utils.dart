import 'package:eatapp/core/utils/search_normalizer.dart';
import 'package:eatapp/data/db/app_database.dart';

/// A fresh in-memory database, one per test.
AppDatabase createTestDatabase() => AppDatabase.memory();

/// A restaurant whose `searchText` is derived through the same helpers the
/// repository will use, so the search tests exercise the real folding.
Restaurant restaurant({
  required String id,
  required String name,
  String cuisineType = 'italian',
  String? streetAddress,
  int priceRange = 0,
  String? website,
  String? instagram,
  String? city,
  String? region,
  String? country,
}) => Restaurant(
  id: id,
  name: name,
  cuisineType: cuisineType,
  streetAddress: streetAddress,
  priceRange: priceRange,
  website: website,
  instagram: instagram,
  city: city,
  region: region,
  country: country,
  searchText: buildSearchText(
    name: name,
    cuisineType: cuisineType,
    streetAddress: streetAddress,
    city: city,
    region: region,
    country: country,
  ),
);

Visit visit({
  required String id,
  required String restaurantId,
  required int visitDate,
  required int rating,
  String? notes,
  int priceRange = 0,
}) => Visit(
  id: id,
  restaurantId: restaurantId,
  visitDate: visitDate,
  rating: rating,
  notes: notes,
  priceRange: priceRange,
);

Tag tag({required String id, required String name}) => Tag(id: id, name: name);

Photo photo({
  required String id,
  required String path,
  String? restaurantId,
  String? visitId,
  int position = 0,
}) => Photo(
  id: id,
  restaurantId: restaurantId,
  visitId: visitId,
  path: path,
  position: position,
);

/// Runs the list query and returns just the ids, which is what most of the
/// filter assertions care about. [query] goes through the same folding and
/// escaping the repository applies before it reaches the DAO.
Future<List<String>> filteredIds(
  AppDatabase db, {
  String? query,
  int? minRating,
  String? cuisineType,
  bool sortByRating = false,
  bool? visited,
  String? city,
  String? region,
  String? country,
  int? priceRange,
}) async {
  final String? folded = query == null
      ? null
      : escapeLikeWildcards(normalizeForSearch(query));
  final List<Restaurant> rows = await db.restaurantDao
      .observeFiltered(
        query: folded,
        minRating: minRating,
        cuisineType: cuisineType,
        sortByRating: sortByRating,
        visited: visited,
        city: city,
        region: region,
        country: country,
        priceRange: priceRange,
      )
      .first;
  return <String>[for (final Restaurant row in rows) row.id];
}
