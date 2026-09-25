// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_dao.dart';

// ignore_for_file: type=lint
mixin _$RestaurantDaoMixin on DatabaseAccessor<AppDatabase> {
  $RestaurantsTable get restaurants => attachedDatabase.restaurants;
  $VisitsTable get visits => attachedDatabase.visits;
  RestaurantDaoManager get managers => RestaurantDaoManager(this);
}

class RestaurantDaoManager {
  final _$RestaurantDaoMixin _db;
  RestaurantDaoManager(this._db);
  $$RestaurantsTableTableManager get restaurants =>
      $$RestaurantsTableTableManager(_db.attachedDatabase, _db.restaurants);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db.attachedDatabase, _db.visits);
}
