import '../db/app_database.dart';
import '../db/daos/restaurant_dao.dart';
import '../db/daos/visit_dao.dart';
import '../share/restaurant_share_models.dart';

/// Builds the exportable shape of the restaurants on this device.
///
/// Both the shared/exported file (`share_service.dart`) and the automatic
/// `backup.json` snapshot ([WriteEffects.afterWrite]) are built from this one
/// class, so the two can't drift apart in what they consider a restaurant's
/// data.
class RestaurantExporter {
  RestaurantExporter(this._database, {this.favoriteIds});

  final AppDatabase _database;

  /// The ids the user has marked favourite, or null when nothing holds a
  /// preference store — the case in every unit test. A callback rather than
  /// a set, because favourites change while this object lives and are not a
  /// restaurant column at all: reading it at export time keeps the file and
  /// the automatic snapshot from ever carrying a stale flag.
  final Set<String> Function()? favoriteIds;

  late final RestaurantDao _restaurants = _database.restaurantDao;
  late final VisitDao _visits = _database.visitDao;

  /// The exportable shape of every restaurant (or just [restaurantIds]),
  /// carrying each one's visits when [includeVisits] is set and its
  /// favourite flag always ([favoriteIds]).
  ///
  /// [groupId] narrows the pool to one group's restaurants (the safety-net
  /// export offered before leaving or dissolving a group); left null, every
  /// restaurant is included, groups and personal alike.
  Future<List<RestaurantExport>> exportRestaurants({
    List<String>? restaurantIds,
    bool includeVisits = true,
    String? groupId,
  }) async {
    Iterable<Restaurant> pool = await _restaurants.getAll();
    if (groupId != null) {
      pool = pool.where((Restaurant r) => r.groupId == groupId);
    }
    final List<Restaurant> selected = restaurantIds == null
        ? pool.toList()
        : <Restaurant>[
            for (final Restaurant restaurant in pool)
              if (restaurantIds.contains(restaurant.id)) restaurant,
          ];

    final Set<String> favorites = favoriteIds?.call() ?? const <String>{};
    final Map<String, List<Visit>> visitsByRestaurant = includeVisits
        ? _groupVisits(await _visits.getAllVisits())
        : const <String, List<Visit>>{};

    return <RestaurantExport>[
      for (final Restaurant restaurant in selected)
        exportRestaurant(
          restaurant,
          visits: visitsByRestaurant[restaurant.id] ?? const <Visit>[],
          isFavorite: favorites.contains(restaurant.id),
        ),
    ];
  }

  static Map<String, List<Visit>> _groupVisits(List<Visit> visits) {
    final Map<String, List<Visit>> byRestaurant = <String, List<Visit>>{};
    for (final Visit visit in visits) {
      (byRestaurant[visit.restaurantId] ??= <Visit>[]).add(visit);
    }
    return byRestaurant;
  }
}
