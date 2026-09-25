// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_dao.dart';

// ignore_for_file: type=lint
mixin _$TagDaoMixin on DatabaseAccessor<AppDatabase> {
  $TagsTable get tags => attachedDatabase.tags;
  $RestaurantsTable get restaurants => attachedDatabase.restaurants;
  $RestaurantTagsTable get restaurantTags => attachedDatabase.restaurantTags;
  TagDaoManager get managers => TagDaoManager(this);
}

class TagDaoManager {
  final _$TagDaoMixin _db;
  TagDaoManager(this._db);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$RestaurantsTableTableManager get restaurants =>
      $$RestaurantsTableTableManager(_db.attachedDatabase, _db.restaurants);
  $$RestaurantTagsTableTableManager get restaurantTags =>
      $$RestaurantTagsTableTableManager(
        _db.attachedDatabase,
        _db.restaurantTags,
      );
}
