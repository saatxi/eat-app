// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit_dao.dart';

// ignore_for_file: type=lint
mixin _$VisitDaoMixin on DatabaseAccessor<AppDatabase> {
  $RestaurantsTable get restaurants => attachedDatabase.restaurants;
  $VisitsTable get visits => attachedDatabase.visits;
  VisitDaoManager get managers => VisitDaoManager(this);
}

class VisitDaoManager {
  final _$VisitDaoMixin _db;
  VisitDaoManager(this._db);
  $$RestaurantsTableTableManager get restaurants =>
      $$RestaurantsTableTableManager(_db.attachedDatabase, _db.restaurants);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db.attachedDatabase, _db.visits);
}
