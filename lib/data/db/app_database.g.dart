// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RestaurantsTable extends Restaurants
    with TableInfo<$RestaurantsTable, Restaurant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestaurantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'groupId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'createdBy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updatedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deletedAt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cuisineTypeMeta = const VerificationMeta(
    'cuisineType',
  );
  @override
  late final GeneratedColumn<String> cuisineType = GeneratedColumn<String>(
    'cuisineType',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streetAddressMeta = const VerificationMeta(
    'streetAddress',
  );
  @override
  late final GeneratedColumn<String> streetAddress = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceRangeMeta = const VerificationMeta(
    'priceRange',
  );
  @override
  late final GeneratedColumn<int> priceRange = GeneratedColumn<int>(
    'priceRange',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _websiteMeta = const VerificationMeta(
    'website',
  );
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
    'website',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _instagramMeta = const VerificationMeta(
    'instagram',
  );
  @override
  late final GeneratedColumn<String> instagram = GeneratedColumn<String>(
    'instagram',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'searchText',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    createdBy,
    updatedAt,
    deletedAt,
    id,
    name,
    cuisineType,
    streetAddress,
    priceRange,
    website,
    instagram,
    city,
    region,
    country,
    searchText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restaurants';
  @override
  VerificationContext validateIntegrity(
    Insertable<Restaurant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupId')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['groupId']!, _groupIdMeta),
      );
    }
    if (data.containsKey('createdBy')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['createdBy']!, _createdByMeta),
      );
    }
    if (data.containsKey('updatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updatedAt']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deletedAt')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deletedAt']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cuisineType')) {
      context.handle(
        _cuisineTypeMeta,
        cuisineType.isAcceptableOrUnknown(
          data['cuisineType']!,
          _cuisineTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cuisineTypeMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _streetAddressMeta,
        streetAddress.isAcceptableOrUnknown(
          data['address']!,
          _streetAddressMeta,
        ),
      );
    }
    if (data.containsKey('priceRange')) {
      context.handle(
        _priceRangeMeta,
        priceRange.isAcceptableOrUnknown(data['priceRange']!, _priceRangeMeta),
      );
    } else if (isInserting) {
      context.missing(_priceRangeMeta);
    }
    if (data.containsKey('website')) {
      context.handle(
        _websiteMeta,
        website.isAcceptableOrUnknown(data['website']!, _websiteMeta),
      );
    }
    if (data.containsKey('instagram')) {
      context.handle(
        _instagramMeta,
        instagram.isAcceptableOrUnknown(data['instagram']!, _instagramMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('searchText')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['searchText']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Restaurant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Restaurant(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupId'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createdBy'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updatedAt'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deletedAt'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cuisineType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cuisineType'],
      )!,
      streetAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      priceRange: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priceRange'],
      )!,
      website: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website'],
      ),
      instagram: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instagram'],
      ),
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      ),
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}searchText'],
      )!,
    );
  }

  @override
  $RestaurantsTable createAlias(String alias) {
    return $RestaurantsTable(attachedDatabase, alias);
  }
}

class Restaurant extends DataClass implements Insertable<Restaurant> {
  /// The group this row belongs to, or null for a private, never-synced row.
  final String? groupId;

  /// Auth user id of whoever created the row; null while the row is private.
  final String? createdBy;

  /// Epoch millis of the last write, set by the repository on every change.
  /// Defaults to 0 ("never written since the 15→16 upgrade"); the repository
  /// stamps the real value on every insert and update.
  final int updatedAt;

  /// Epoch millis of the soft delete, or null while the row is alive.
  final int? deletedAt;

  /// Client-generated UUID string, assigned by the repository at insert time —
  /// never an autoincrement.
  final String id;
  final String name;
  final String cuisineType;

  /// Street line only — town/region/country live in [city]/[region]/[country].
  /// The physical column stays named `address` for historical continuity with
  /// earlier schemas.
  final String? streetAddress;

  /// General price band of the place (0-6, euro tiers) — not per-visit.
  final int priceRange;

  /// Optional links. Both are validated on import and are null whenever the
  /// source data omits the column, leaves it empty, or holds something that
  /// isn't safe to open.
  final String? website;

  /// Bare handle, no leading `@` and never a URL.
  final String? instagram;

  /// Town/city ("poble"). Free text with autocomplete over existing values — no
  /// closed vocabulary, unlike [cuisineType].
  final String? city;

  /// State/province ("regió"). Same free-text-with-autocomplete treatment as
  /// [city].
  final String? region;

  /// Country ("país"). Same free-text-with-autocomplete treatment as [city].
  final String? country;

  /// Accent-stripped, lowercased concatenation of every searchable field —
  /// built by `buildSearchText`, which is what keeps it from drifting.
  final String searchText;
  const Restaurant({
    this.groupId,
    this.createdBy,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.name,
    required this.cuisineType,
    this.streetAddress,
    required this.priceRange,
    this.website,
    this.instagram,
    this.city,
    this.region,
    this.country,
    required this.searchText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || groupId != null) {
      map['groupId'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['createdBy'] = Variable<String>(createdBy);
    }
    map['updatedAt'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deletedAt'] = Variable<int>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['cuisineType'] = Variable<String>(cuisineType);
    if (!nullToAbsent || streetAddress != null) {
      map['address'] = Variable<String>(streetAddress);
    }
    map['priceRange'] = Variable<int>(priceRange);
    if (!nullToAbsent || website != null) {
      map['website'] = Variable<String>(website);
    }
    if (!nullToAbsent || instagram != null) {
      map['instagram'] = Variable<String>(instagram);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    map['searchText'] = Variable<String>(searchText);
    return map;
  }

  RestaurantsCompanion toCompanion(bool nullToAbsent) {
    return RestaurantsCompanion(
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      name: Value(name),
      cuisineType: Value(cuisineType),
      streetAddress: streetAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(streetAddress),
      priceRange: Value(priceRange),
      website: website == null && nullToAbsent
          ? const Value.absent()
          : Value(website),
      instagram: instagram == null && nullToAbsent
          ? const Value.absent()
          : Value(instagram),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      searchText: Value(searchText),
    );
  }

  factory Restaurant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Restaurant(
      groupId: serializer.fromJson<String?>(json['groupId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cuisineType: serializer.fromJson<String>(json['cuisineType']),
      streetAddress: serializer.fromJson<String?>(json['streetAddress']),
      priceRange: serializer.fromJson<int>(json['priceRange']),
      website: serializer.fromJson<String?>(json['website']),
      instagram: serializer.fromJson<String?>(json['instagram']),
      city: serializer.fromJson<String?>(json['city']),
      region: serializer.fromJson<String?>(json['region']),
      country: serializer.fromJson<String?>(json['country']),
      searchText: serializer.fromJson<String>(json['searchText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String?>(groupId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cuisineType': serializer.toJson<String>(cuisineType),
      'streetAddress': serializer.toJson<String?>(streetAddress),
      'priceRange': serializer.toJson<int>(priceRange),
      'website': serializer.toJson<String?>(website),
      'instagram': serializer.toJson<String?>(instagram),
      'city': serializer.toJson<String?>(city),
      'region': serializer.toJson<String?>(region),
      'country': serializer.toJson<String?>(country),
      'searchText': serializer.toJson<String>(searchText),
    };
  }

  Restaurant copyWith({
    Value<String?> groupId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? id,
    String? name,
    String? cuisineType,
    Value<String?> streetAddress = const Value.absent(),
    int? priceRange,
    Value<String?> website = const Value.absent(),
    Value<String?> instagram = const Value.absent(),
    Value<String?> city = const Value.absent(),
    Value<String?> region = const Value.absent(),
    Value<String?> country = const Value.absent(),
    String? searchText,
  }) => Restaurant(
    groupId: groupId.present ? groupId.value : this.groupId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    name: name ?? this.name,
    cuisineType: cuisineType ?? this.cuisineType,
    streetAddress: streetAddress.present
        ? streetAddress.value
        : this.streetAddress,
    priceRange: priceRange ?? this.priceRange,
    website: website.present ? website.value : this.website,
    instagram: instagram.present ? instagram.value : this.instagram,
    city: city.present ? city.value : this.city,
    region: region.present ? region.value : this.region,
    country: country.present ? country.value : this.country,
    searchText: searchText ?? this.searchText,
  );
  Restaurant copyWithCompanion(RestaurantsCompanion data) {
    return Restaurant(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cuisineType: data.cuisineType.present
          ? data.cuisineType.value
          : this.cuisineType,
      streetAddress: data.streetAddress.present
          ? data.streetAddress.value
          : this.streetAddress,
      priceRange: data.priceRange.present
          ? data.priceRange.value
          : this.priceRange,
      website: data.website.present ? data.website.value : this.website,
      instagram: data.instagram.present ? data.instagram.value : this.instagram,
      city: data.city.present ? data.city.value : this.city,
      region: data.region.present ? data.region.value : this.region,
      country: data.country.present ? data.country.value : this.country,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Restaurant(')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cuisineType: $cuisineType, ')
          ..write('streetAddress: $streetAddress, ')
          ..write('priceRange: $priceRange, ')
          ..write('website: $website, ')
          ..write('instagram: $instagram, ')
          ..write('city: $city, ')
          ..write('region: $region, ')
          ..write('country: $country, ')
          ..write('searchText: $searchText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    createdBy,
    updatedAt,
    deletedAt,
    id,
    name,
    cuisineType,
    streetAddress,
    priceRange,
    website,
    instagram,
    city,
    region,
    country,
    searchText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Restaurant &&
          other.groupId == this.groupId &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.name == this.name &&
          other.cuisineType == this.cuisineType &&
          other.streetAddress == this.streetAddress &&
          other.priceRange == this.priceRange &&
          other.website == this.website &&
          other.instagram == this.instagram &&
          other.city == this.city &&
          other.region == this.region &&
          other.country == this.country &&
          other.searchText == this.searchText);
}

class RestaurantsCompanion extends UpdateCompanion<Restaurant> {
  final Value<String?> groupId;
  final Value<String?> createdBy;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> id;
  final Value<String> name;
  final Value<String> cuisineType;
  final Value<String?> streetAddress;
  final Value<int> priceRange;
  final Value<String?> website;
  final Value<String?> instagram;
  final Value<String?> city;
  final Value<String?> region;
  final Value<String?> country;
  final Value<String> searchText;
  final Value<int> rowid;
  const RestaurantsCompanion({
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cuisineType = const Value.absent(),
    this.streetAddress = const Value.absent(),
    this.priceRange = const Value.absent(),
    this.website = const Value.absent(),
    this.instagram = const Value.absent(),
    this.city = const Value.absent(),
    this.region = const Value.absent(),
    this.country = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestaurantsCompanion.insert({
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    required String name,
    required String cuisineType,
    this.streetAddress = const Value.absent(),
    required int priceRange,
    this.website = const Value.absent(),
    this.instagram = const Value.absent(),
    this.city = const Value.absent(),
    this.region = const Value.absent(),
    this.country = const Value.absent(),
    required String searchText,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       cuisineType = Value(cuisineType),
       priceRange = Value(priceRange),
       searchText = Value(searchText);
  static Insertable<Restaurant> custom({
    Expression<String>? groupId,
    Expression<String>? createdBy,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? cuisineType,
    Expression<String>? streetAddress,
    Expression<int>? priceRange,
    Expression<String>? website,
    Expression<String>? instagram,
    Expression<String>? city,
    Expression<String>? region,
    Expression<String>? country,
    Expression<String>? searchText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'groupId': groupId,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cuisineType != null) 'cuisineType': cuisineType,
      if (streetAddress != null) 'address': streetAddress,
      if (priceRange != null) 'priceRange': priceRange,
      if (website != null) 'website': website,
      if (instagram != null) 'instagram': instagram,
      if (city != null) 'city': city,
      if (region != null) 'region': region,
      if (country != null) 'country': country,
      if (searchText != null) 'searchText': searchText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestaurantsCompanion copyWith({
    Value<String?>? groupId,
    Value<String?>? createdBy,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? id,
    Value<String>? name,
    Value<String>? cuisineType,
    Value<String?>? streetAddress,
    Value<int>? priceRange,
    Value<String?>? website,
    Value<String?>? instagram,
    Value<String?>? city,
    Value<String?>? region,
    Value<String?>? country,
    Value<String>? searchText,
    Value<int>? rowid,
  }) {
    return RestaurantsCompanion(
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      name: name ?? this.name,
      cuisineType: cuisineType ?? this.cuisineType,
      streetAddress: streetAddress ?? this.streetAddress,
      priceRange: priceRange ?? this.priceRange,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      city: city ?? this.city,
      region: region ?? this.region,
      country: country ?? this.country,
      searchText: searchText ?? this.searchText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['groupId'] = Variable<String>(groupId.value);
    }
    if (createdBy.present) {
      map['createdBy'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updatedAt'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deletedAt'] = Variable<int>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cuisineType.present) {
      map['cuisineType'] = Variable<String>(cuisineType.value);
    }
    if (streetAddress.present) {
      map['address'] = Variable<String>(streetAddress.value);
    }
    if (priceRange.present) {
      map['priceRange'] = Variable<int>(priceRange.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (instagram.present) {
      map['instagram'] = Variable<String>(instagram.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (searchText.present) {
      map['searchText'] = Variable<String>(searchText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cuisineType: $cuisineType, ')
          ..write('streetAddress: $streetAddress, ')
          ..write('priceRange: $priceRange, ')
          ..write('website: $website, ')
          ..write('instagram: $instagram, ')
          ..write('city: $city, ')
          ..write('region: $region, ')
          ..write('country: $country, ')
          ..write('searchText: $searchText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitsTable extends Visits with TableInfo<$VisitsTable, Visit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'groupId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'createdBy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updatedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deletedAt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restaurantIdMeta = const VerificationMeta(
    'restaurantId',
  );
  @override
  late final GeneratedColumn<String> restaurantId = GeneratedColumn<String>(
    'restaurantId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES restaurants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _visitDateMeta = const VerificationMeta(
    'visitDate',
  );
  @override
  late final GeneratedColumn<int> visitDate = GeneratedColumn<int>(
    'visitDate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceRangeMeta = const VerificationMeta(
    'priceRange',
  );
  @override
  late final GeneratedColumn<int> priceRange = GeneratedColumn<int>(
    'priceRange',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    createdBy,
    updatedAt,
    deletedAt,
    id,
    restaurantId,
    visitDate,
    rating,
    notes,
    priceRange,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<Visit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupId')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['groupId']!, _groupIdMeta),
      );
    }
    if (data.containsKey('createdBy')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['createdBy']!, _createdByMeta),
      );
    }
    if (data.containsKey('updatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updatedAt']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deletedAt')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deletedAt']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('restaurantId')) {
      context.handle(
        _restaurantIdMeta,
        restaurantId.isAcceptableOrUnknown(
          data['restaurantId']!,
          _restaurantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_restaurantIdMeta);
    }
    if (data.containsKey('visitDate')) {
      context.handle(
        _visitDateMeta,
        visitDate.isAcceptableOrUnknown(data['visitDate']!, _visitDateMeta),
      );
    } else if (isInserting) {
      context.missing(_visitDateMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('priceRange')) {
      context.handle(
        _priceRangeMeta,
        priceRange.isAcceptableOrUnknown(data['priceRange']!, _priceRangeMeta),
      );
    } else if (isInserting) {
      context.missing(_priceRangeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Visit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Visit(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupId'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createdBy'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updatedAt'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deletedAt'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      restaurantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restaurantId'],
      )!,
      visitDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visitDate'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      priceRange: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priceRange'],
      )!,
    );
  }

  @override
  $VisitsTable createAlias(String alias) {
    return $VisitsTable(attachedDatabase, alias);
  }
}

class Visit extends DataClass implements Insertable<Visit> {
  /// The group this row belongs to, or null for a private, never-synced row.
  final String? groupId;

  /// Auth user id of whoever created the row; null while the row is private.
  final String? createdBy;

  /// Epoch millis of the last write, set by the repository on every change.
  /// Defaults to 0 ("never written since the 15→16 upgrade"); the repository
  /// stamps the real value on every insert and update.
  final int updatedAt;

  /// Epoch millis of the soft delete, or null while the row is alive.
  final int? deletedAt;
  final String id;
  final String restaurantId;

  /// Epoch millis.
  final int visitDate;

  /// 0-5.
  final int rating;
  final String? notes;

  /// Price band on this particular visit (0-6, same scale as
  /// `Restaurants.priceRange`); 0 means "not set".
  final int priceRange;
  const Visit({
    this.groupId,
    this.createdBy,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.restaurantId,
    required this.visitDate,
    required this.rating,
    this.notes,
    required this.priceRange,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || groupId != null) {
      map['groupId'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['createdBy'] = Variable<String>(createdBy);
    }
    map['updatedAt'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deletedAt'] = Variable<int>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['restaurantId'] = Variable<String>(restaurantId);
    map['visitDate'] = Variable<int>(visitDate);
    map['rating'] = Variable<int>(rating);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['priceRange'] = Variable<int>(priceRange);
    return map;
  }

  VisitsCompanion toCompanion(bool nullToAbsent) {
    return VisitsCompanion(
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      restaurantId: Value(restaurantId),
      visitDate: Value(visitDate),
      rating: Value(rating),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      priceRange: Value(priceRange),
    );
  }

  factory Visit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Visit(
      groupId: serializer.fromJson<String?>(json['groupId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      restaurantId: serializer.fromJson<String>(json['restaurantId']),
      visitDate: serializer.fromJson<int>(json['visitDate']),
      rating: serializer.fromJson<int>(json['rating']),
      notes: serializer.fromJson<String?>(json['notes']),
      priceRange: serializer.fromJson<int>(json['priceRange']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String?>(groupId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'restaurantId': serializer.toJson<String>(restaurantId),
      'visitDate': serializer.toJson<int>(visitDate),
      'rating': serializer.toJson<int>(rating),
      'notes': serializer.toJson<String?>(notes),
      'priceRange': serializer.toJson<int>(priceRange),
    };
  }

  Visit copyWith({
    Value<String?> groupId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? id,
    String? restaurantId,
    int? visitDate,
    int? rating,
    Value<String?> notes = const Value.absent(),
    int? priceRange,
  }) => Visit(
    groupId: groupId.present ? groupId.value : this.groupId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    visitDate: visitDate ?? this.visitDate,
    rating: rating ?? this.rating,
    notes: notes.present ? notes.value : this.notes,
    priceRange: priceRange ?? this.priceRange,
  );
  Visit copyWithCompanion(VisitsCompanion data) {
    return Visit(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      restaurantId: data.restaurantId.present
          ? data.restaurantId.value
          : this.restaurantId,
      visitDate: data.visitDate.present ? data.visitDate.value : this.visitDate,
      rating: data.rating.present ? data.rating.value : this.rating,
      notes: data.notes.present ? data.notes.value : this.notes,
      priceRange: data.priceRange.present
          ? data.priceRange.value
          : this.priceRange,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Visit(')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('visitDate: $visitDate, ')
          ..write('rating: $rating, ')
          ..write('notes: $notes, ')
          ..write('priceRange: $priceRange')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    createdBy,
    updatedAt,
    deletedAt,
    id,
    restaurantId,
    visitDate,
    rating,
    notes,
    priceRange,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Visit &&
          other.groupId == this.groupId &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.restaurantId == this.restaurantId &&
          other.visitDate == this.visitDate &&
          other.rating == this.rating &&
          other.notes == this.notes &&
          other.priceRange == this.priceRange);
}

class VisitsCompanion extends UpdateCompanion<Visit> {
  final Value<String?> groupId;
  final Value<String?> createdBy;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> id;
  final Value<String> restaurantId;
  final Value<int> visitDate;
  final Value<int> rating;
  final Value<String?> notes;
  final Value<int> priceRange;
  final Value<int> rowid;
  const VisitsCompanion({
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.restaurantId = const Value.absent(),
    this.visitDate = const Value.absent(),
    this.rating = const Value.absent(),
    this.notes = const Value.absent(),
    this.priceRange = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitsCompanion.insert({
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    required String restaurantId,
    required int visitDate,
    required int rating,
    this.notes = const Value.absent(),
    required int priceRange,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       restaurantId = Value(restaurantId),
       visitDate = Value(visitDate),
       rating = Value(rating),
       priceRange = Value(priceRange);
  static Insertable<Visit> custom({
    Expression<String>? groupId,
    Expression<String>? createdBy,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? id,
    Expression<String>? restaurantId,
    Expression<int>? visitDate,
    Expression<int>? rating,
    Expression<String>? notes,
    Expression<int>? priceRange,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'groupId': groupId,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (id != null) 'id': id,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (visitDate != null) 'visitDate': visitDate,
      if (rating != null) 'rating': rating,
      if (notes != null) 'notes': notes,
      if (priceRange != null) 'priceRange': priceRange,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitsCompanion copyWith({
    Value<String?>? groupId,
    Value<String?>? createdBy,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? id,
    Value<String>? restaurantId,
    Value<int>? visitDate,
    Value<int>? rating,
    Value<String?>? notes,
    Value<int>? priceRange,
    Value<int>? rowid,
  }) {
    return VisitsCompanion(
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      visitDate: visitDate ?? this.visitDate,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      priceRange: priceRange ?? this.priceRange,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['groupId'] = Variable<String>(groupId.value);
    }
    if (createdBy.present) {
      map['createdBy'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updatedAt'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deletedAt'] = Variable<int>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (restaurantId.present) {
      map['restaurantId'] = Variable<String>(restaurantId.value);
    }
    if (visitDate.present) {
      map['visitDate'] = Variable<int>(visitDate.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (priceRange.present) {
      map['priceRange'] = Variable<int>(priceRange.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('visitDate: $visitDate, ')
          ..write('rating: $rating, ')
          ..write('notes: $notes, ')
          ..write('priceRange: $priceRange, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'groupId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'createdBy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updatedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deletedAt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restaurantIdMeta = const VerificationMeta(
    'restaurantId',
  );
  @override
  late final GeneratedColumn<String> restaurantId = GeneratedColumn<String>(
    'restaurantId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES restaurants (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _visitIdMeta = const VerificationMeta(
    'visitId',
  );
  @override
  late final GeneratedColumn<String> visitId = GeneratedColumn<String>(
    'visitId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES visits (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    createdBy,
    updatedAt,
    deletedAt,
    id,
    restaurantId,
    visitId,
    path,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Photo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupId')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['groupId']!, _groupIdMeta),
      );
    }
    if (data.containsKey('createdBy')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['createdBy']!, _createdByMeta),
      );
    }
    if (data.containsKey('updatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updatedAt']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deletedAt')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deletedAt']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('restaurantId')) {
      context.handle(
        _restaurantIdMeta,
        restaurantId.isAcceptableOrUnknown(
          data['restaurantId']!,
          _restaurantIdMeta,
        ),
      );
    }
    if (data.containsKey('visitId')) {
      context.handle(
        _visitIdMeta,
        visitId.isAcceptableOrUnknown(data['visitId']!, _visitIdMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupId'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createdBy'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updatedAt'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deletedAt'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      restaurantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restaurantId'],
      ),
      visitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visitId'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class Photo extends DataClass implements Insertable<Photo> {
  /// The group this row belongs to, or null for a private, never-synced row.
  final String? groupId;

  /// Auth user id of whoever created the row; null while the row is private.
  final String? createdBy;

  /// Epoch millis of the last write, set by the repository on every change.
  /// Defaults to 0 ("never written since the 15→16 upgrade"); the repository
  /// stamps the real value on every insert and update.
  final int updatedAt;

  /// Epoch millis of the soft delete, or null while the row is alive.
  final int? deletedAt;
  final String id;
  final String? restaurantId;
  final String? visitId;

  /// Absolute path to a copy this app made under its own `filesDir/photos/`.
  final String path;
  final int position;
  const Photo({
    this.groupId,
    this.createdBy,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    this.restaurantId,
    this.visitId,
    required this.path,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || groupId != null) {
      map['groupId'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['createdBy'] = Variable<String>(createdBy);
    }
    map['updatedAt'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deletedAt'] = Variable<int>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || restaurantId != null) {
      map['restaurantId'] = Variable<String>(restaurantId);
    }
    if (!nullToAbsent || visitId != null) {
      map['visitId'] = Variable<String>(visitId);
    }
    map['path'] = Variable<String>(path);
    map['position'] = Variable<int>(position);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      restaurantId: restaurantId == null && nullToAbsent
          ? const Value.absent()
          : Value(restaurantId),
      visitId: visitId == null && nullToAbsent
          ? const Value.absent()
          : Value(visitId),
      path: Value(path),
      position: Value(position),
    );
  }

  factory Photo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      groupId: serializer.fromJson<String?>(json['groupId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      restaurantId: serializer.fromJson<String?>(json['restaurantId']),
      visitId: serializer.fromJson<String?>(json['visitId']),
      path: serializer.fromJson<String>(json['path']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String?>(groupId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'restaurantId': serializer.toJson<String?>(restaurantId),
      'visitId': serializer.toJson<String?>(visitId),
      'path': serializer.toJson<String>(path),
      'position': serializer.toJson<int>(position),
    };
  }

  Photo copyWith({
    Value<String?> groupId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? id,
    Value<String?> restaurantId = const Value.absent(),
    Value<String?> visitId = const Value.absent(),
    String? path,
    int? position,
  }) => Photo(
    groupId: groupId.present ? groupId.value : this.groupId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    restaurantId: restaurantId.present ? restaurantId.value : this.restaurantId,
    visitId: visitId.present ? visitId.value : this.visitId,
    path: path ?? this.path,
    position: position ?? this.position,
  );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      restaurantId: data.restaurantId.present
          ? data.restaurantId.value
          : this.restaurantId,
      visitId: data.visitId.present ? data.visitId.value : this.visitId,
      path: data.path.present ? data.path.value : this.path,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('visitId: $visitId, ')
          ..write('path: $path, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    createdBy,
    updatedAt,
    deletedAt,
    id,
    restaurantId,
    visitId,
    path,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.groupId == this.groupId &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.restaurantId == this.restaurantId &&
          other.visitId == this.visitId &&
          other.path == this.path &&
          other.position == this.position);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<String?> groupId;
  final Value<String?> createdBy;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> id;
  final Value<String?> restaurantId;
  final Value<String?> visitId;
  final Value<String> path;
  final Value<int> position;
  final Value<int> rowid;
  const PhotosCompanion({
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.restaurantId = const Value.absent(),
    this.visitId = const Value.absent(),
    this.path = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    this.restaurantId = const Value.absent(),
    this.visitId = const Value.absent(),
    required String path,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       path = Value(path),
       position = Value(position);
  static Insertable<Photo> custom({
    Expression<String>? groupId,
    Expression<String>? createdBy,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? id,
    Expression<String>? restaurantId,
    Expression<String>? visitId,
    Expression<String>? path,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'groupId': groupId,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (id != null) 'id': id,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (visitId != null) 'visitId': visitId,
      if (path != null) 'path': path,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith({
    Value<String?>? groupId,
    Value<String?>? createdBy,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? id,
    Value<String?>? restaurantId,
    Value<String?>? visitId,
    Value<String>? path,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PhotosCompanion(
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      visitId: visitId ?? this.visitId,
      path: path ?? this.path,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['groupId'] = Variable<String>(groupId.value);
    }
    if (createdBy.present) {
      map['createdBy'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updatedAt'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deletedAt'] = Variable<int>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (restaurantId.present) {
      map['restaurantId'] = Variable<String>(restaurantId.value);
    }
    if (visitId.present) {
      map['visitId'] = Variable<String>(visitId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('visitId: $visitId, ')
          ..write('path: $path, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingSyncsTable extends PendingSyncs
    with TableInfo<$PendingSyncsTable, PendingSync> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sharedTableMeta = const VerificationMeta(
    'sharedTable',
  );
  @override
  late final GeneratedColumn<String> sharedTable = GeneratedColumn<String>(
    'sharedTable',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'rowId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'groupId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sharedTable, rowId, groupId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_syncs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSync> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sharedTable')) {
      context.handle(
        _sharedTableMeta,
        sharedTable.isAcceptableOrUnknown(
          data['sharedTable']!,
          _sharedTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sharedTableMeta);
    }
    if (data.containsKey('rowId')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['rowId']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('groupId')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['groupId']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sharedTable, rowId};
  @override
  PendingSync map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSync(
      sharedTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sharedTable'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rowId'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupId'],
      )!,
    );
  }

  @override
  $PendingSyncsTable createAlias(String alias) {
    return $PendingSyncsTable(attachedDatabase, alias);
  }
}

class PendingSync extends DataClass implements Insertable<PendingSync> {
  /// Which shared table the dirty row lives in: the Dart name of one of the
  /// `SyncTable` values (`restaurants`, `visits` or `photos`), which is the
  /// same string on both the drift and the Supabase side.
  final String sharedTable;

  /// The dirty row's id — a client-generated UUID.
  final String rowId;

  /// The group the row belongs to, copied at enqueue time so a push can be
  /// scoped to one group without joining back to the source row first.
  final String groupId;
  const PendingSync({
    required this.sharedTable,
    required this.rowId,
    required this.groupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sharedTable'] = Variable<String>(sharedTable);
    map['rowId'] = Variable<String>(rowId);
    map['groupId'] = Variable<String>(groupId);
    return map;
  }

  PendingSyncsCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncsCompanion(
      sharedTable: Value(sharedTable),
      rowId: Value(rowId),
      groupId: Value(groupId),
    );
  }

  factory PendingSync.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSync(
      sharedTable: serializer.fromJson<String>(json['sharedTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      groupId: serializer.fromJson<String>(json['groupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sharedTable': serializer.toJson<String>(sharedTable),
      'rowId': serializer.toJson<String>(rowId),
      'groupId': serializer.toJson<String>(groupId),
    };
  }

  PendingSync copyWith({String? sharedTable, String? rowId, String? groupId}) =>
      PendingSync(
        sharedTable: sharedTable ?? this.sharedTable,
        rowId: rowId ?? this.rowId,
        groupId: groupId ?? this.groupId,
      );
  PendingSync copyWithCompanion(PendingSyncsCompanion data) {
    return PendingSync(
      sharedTable: data.sharedTable.present
          ? data.sharedTable.value
          : this.sharedTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSync(')
          ..write('sharedTable: $sharedTable, ')
          ..write('rowId: $rowId, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sharedTable, rowId, groupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSync &&
          other.sharedTable == this.sharedTable &&
          other.rowId == this.rowId &&
          other.groupId == this.groupId);
}

class PendingSyncsCompanion extends UpdateCompanion<PendingSync> {
  final Value<String> sharedTable;
  final Value<String> rowId;
  final Value<String> groupId;
  final Value<int> rowid;
  const PendingSyncsCompanion({
    this.sharedTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingSyncsCompanion.insert({
    required String sharedTable,
    required String rowId,
    required String groupId,
    this.rowid = const Value.absent(),
  }) : sharedTable = Value(sharedTable),
       rowId = Value(rowId),
       groupId = Value(groupId);
  static Insertable<PendingSync> custom({
    Expression<String>? sharedTable,
    Expression<String>? rowId,
    Expression<String>? groupId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sharedTable != null) 'sharedTable': sharedTable,
      if (rowId != null) 'rowId': rowId,
      if (groupId != null) 'groupId': groupId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingSyncsCompanion copyWith({
    Value<String>? sharedTable,
    Value<String>? rowId,
    Value<String>? groupId,
    Value<int>? rowid,
  }) {
    return PendingSyncsCompanion(
      sharedTable: sharedTable ?? this.sharedTable,
      rowId: rowId ?? this.rowId,
      groupId: groupId ?? this.groupId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sharedTable.present) {
      map['sharedTable'] = Variable<String>(sharedTable.value);
    }
    if (rowId.present) {
      map['rowId'] = Variable<String>(rowId.value);
    }
    if (groupId.present) {
      map['groupId'] = Variable<String>(groupId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncsCompanion(')
          ..write('sharedTable: $sharedTable, ')
          ..write('rowId: $rowId, ')
          ..write('groupId: $groupId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'groupId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<String> lastPulledAt = GeneratedColumn<String>(
    'lastPulledAt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, lastPulledAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupId')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['groupId']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('lastPulledAt')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['lastPulledAt']!,
          _lastPulledAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPulledAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupId'],
      )!,
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lastPulledAt'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  /// The group this cursor advances for.
  final String groupId;

  /// ISO-8601 `updated_at` of the newest remote row already pulled.
  final String lastPulledAt;
  const SyncCursor({required this.groupId, required this.lastPulledAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['groupId'] = Variable<String>(groupId);
    map['lastPulledAt'] = Variable<String>(lastPulledAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      groupId: Value(groupId),
      lastPulledAt: Value(lastPulledAt),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      groupId: serializer.fromJson<String>(json['groupId']),
      lastPulledAt: serializer.fromJson<String>(json['lastPulledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'lastPulledAt': serializer.toJson<String>(lastPulledAt),
    };
  }

  SyncCursor copyWith({String? groupId, String? lastPulledAt}) => SyncCursor(
    groupId: groupId ?? this.groupId,
    lastPulledAt: lastPulledAt ?? this.lastPulledAt,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      lastPulledAt: data.lastPulledAt.present
          ? data.lastPulledAt.value
          : this.lastPulledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('groupId: $groupId, ')
          ..write('lastPulledAt: $lastPulledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, lastPulledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.groupId == this.groupId &&
          other.lastPulledAt == this.lastPulledAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> groupId;
  final Value<String> lastPulledAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.groupId = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String groupId,
    required String lastPulledAt,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       lastPulledAt = Value(lastPulledAt);
  static Insertable<SyncCursor> custom({
    Expression<String>? groupId,
    Expression<String>? lastPulledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'groupId': groupId,
      if (lastPulledAt != null) 'lastPulledAt': lastPulledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? groupId,
    Value<String>? lastPulledAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      groupId: groupId ?? this.groupId,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['groupId'] = Variable<String>(groupId.value);
    }
    if (lastPulledAt.present) {
      map['lastPulledAt'] = Variable<String>(lastPulledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RestaurantsTable restaurants = $RestaurantsTable(this);
  late final $VisitsTable visits = $VisitsTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $PendingSyncsTable pendingSyncs = $PendingSyncsTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final Index indexRestaurantsName = Index(
    'index_restaurants_name',
    'CREATE INDEX index_restaurants_name ON restaurants (name)',
  );
  late final Index indexVisitsRestaurantId = Index(
    'index_visits_restaurantId',
    'CREATE INDEX index_visits_restaurantId ON visits (restaurantId)',
  );
  late final Index indexPhotosRestaurantId = Index(
    'index_photos_restaurantId',
    'CREATE INDEX index_photos_restaurantId ON photos (restaurantId)',
  );
  late final Index indexPhotosVisitId = Index(
    'index_photos_visitId',
    'CREATE INDEX index_photos_visitId ON photos (visitId)',
  );
  late final Index indexPendingSyncsGroupId = Index(
    'index_pending_syncs_groupId',
    'CREATE INDEX index_pending_syncs_groupId ON pending_syncs (groupId)',
  );
  late final RestaurantDao restaurantDao = RestaurantDao(this as AppDatabase);
  late final VisitDao visitDao = VisitDao(this as AppDatabase);
  late final PhotoDao photoDao = PhotoDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    restaurants,
    visits,
    photos,
    pendingSyncs,
    syncCursors,
    indexRestaurantsName,
    indexVisitsRestaurantId,
    indexPhotosRestaurantId,
    indexPhotosVisitId,
    indexPendingSyncsGroupId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'restaurants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('visits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'restaurants',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('photos', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'visits',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('photos', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RestaurantsTableCreateCompanionBuilder =
    RestaurantsCompanion Function({
      Value<String?> groupId,
      Value<String?> createdBy,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      required String id,
      required String name,
      required String cuisineType,
      Value<String?> streetAddress,
      required int priceRange,
      Value<String?> website,
      Value<String?> instagram,
      Value<String?> city,
      Value<String?> region,
      Value<String?> country,
      required String searchText,
      Value<int> rowid,
    });
typedef $$RestaurantsTableUpdateCompanionBuilder =
    RestaurantsCompanion Function({
      Value<String?> groupId,
      Value<String?> createdBy,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> id,
      Value<String> name,
      Value<String> cuisineType,
      Value<String?> streetAddress,
      Value<int> priceRange,
      Value<String?> website,
      Value<String?> instagram,
      Value<String?> city,
      Value<String?> region,
      Value<String?> country,
      Value<String> searchText,
      Value<int> rowid,
    });

final class $$RestaurantsTableReferences
    extends BaseReferences<_$AppDatabase, $RestaurantsTable, Restaurant> {
  $$RestaurantsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VisitsTable, List<Visit>> _visitsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.visits,
    aliasName: 'restaurants__id__visits__restaurantId',
  );

  $$VisitsTableProcessedTableManager get visitsRefs {
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.restaurantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_visitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PhotosTable, List<Photo>> _photosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.photos,
    aliasName: 'restaurants__id__photos__restaurantId',
  );

  $$PhotosTableProcessedTableManager get photosRefs {
    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.restaurantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_photosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RestaurantsTableFilterComposer
    extends Composer<_$AppDatabase, $RestaurantsTable> {
  $$RestaurantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cuisineType => $composableBuilder(
    column: $table.cuisineType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streetAddress => $composableBuilder(
    column: $table.streetAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceRange => $composableBuilder(
    column: $table.priceRange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instagram => $composableBuilder(
    column: $table.instagram,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> visitsRefs(
    Expression<bool> Function($$VisitsTableFilterComposer f) f,
  ) {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.restaurantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> photosRefs(
    Expression<bool> Function($$PhotosTableFilterComposer f) f,
  ) {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.restaurantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RestaurantsTableOrderingComposer
    extends Composer<_$AppDatabase, $RestaurantsTable> {
  $$RestaurantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cuisineType => $composableBuilder(
    column: $table.cuisineType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streetAddress => $composableBuilder(
    column: $table.streetAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceRange => $composableBuilder(
    column: $table.priceRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instagram => $composableBuilder(
    column: $table.instagram,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestaurantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestaurantsTable> {
  $$RestaurantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cuisineType => $composableBuilder(
    column: $table.cuisineType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streetAddress => $composableBuilder(
    column: $table.streetAddress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priceRange => $composableBuilder(
    column: $table.priceRange,
    builder: (column) => column,
  );

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get instagram =>
      $composableBuilder(column: $table.instagram, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  Expression<T> visitsRefs<T extends Object>(
    Expression<T> Function($$VisitsTableAnnotationComposer a) f,
  ) {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.restaurantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> photosRefs<T extends Object>(
    Expression<T> Function($$PhotosTableAnnotationComposer a) f,
  ) {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.restaurantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RestaurantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RestaurantsTable,
          Restaurant,
          $$RestaurantsTableFilterComposer,
          $$RestaurantsTableOrderingComposer,
          $$RestaurantsTableAnnotationComposer,
          $$RestaurantsTableCreateCompanionBuilder,
          $$RestaurantsTableUpdateCompanionBuilder,
          (Restaurant, $$RestaurantsTableReferences),
          Restaurant,
          PrefetchHooks Function({bool visitsRefs, bool photosRefs})
        > {
  $$RestaurantsTableTableManager(_$AppDatabase db, $RestaurantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestaurantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestaurantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestaurantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> groupId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cuisineType = const Value.absent(),
                Value<String?> streetAddress = const Value.absent(),
                Value<int> priceRange = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> instagram = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestaurantsCompanion(
                groupId: groupId,
                createdBy: createdBy,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
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
                searchText: searchText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> groupId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String id,
                required String name,
                required String cuisineType,
                Value<String?> streetAddress = const Value.absent(),
                required int priceRange,
                Value<String?> website = const Value.absent(),
                Value<String?> instagram = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> country = const Value.absent(),
                required String searchText,
                Value<int> rowid = const Value.absent(),
              }) => RestaurantsCompanion.insert(
                groupId: groupId,
                createdBy: createdBy,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
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
                searchText: searchText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RestaurantsTable, Restaurant>(table),
                  $$RestaurantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({visitsRefs = false, photosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (visitsRefs) db.visits,
                if (photosRefs) db.photos,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (visitsRefs)
                    await $_getPrefetchedData<
                      Restaurant,
                      $RestaurantsTable,
                      Visit
                    >(
                      currentTable: table,
                      referencedTable: $$RestaurantsTableReferences
                          ._visitsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RestaurantsTableReferences(
                            db,
                            table,
                            p0,
                          ).visitsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.restaurantId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (photosRefs)
                    await $_getPrefetchedData<
                      Restaurant,
                      $RestaurantsTable,
                      Photo
                    >(
                      currentTable: table,
                      referencedTable: $$RestaurantsTableReferences
                          ._photosRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RestaurantsTableReferences(
                            db,
                            table,
                            p0,
                          ).photosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.restaurantId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RestaurantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RestaurantsTable,
      Restaurant,
      $$RestaurantsTableFilterComposer,
      $$RestaurantsTableOrderingComposer,
      $$RestaurantsTableAnnotationComposer,
      $$RestaurantsTableCreateCompanionBuilder,
      $$RestaurantsTableUpdateCompanionBuilder,
      (Restaurant, $$RestaurantsTableReferences),
      Restaurant,
      PrefetchHooks Function({bool visitsRefs, bool photosRefs})
    >;
typedef $$VisitsTableCreateCompanionBuilder = VisitsCompanion Function({
  Value<String?> groupId,
  Value<String?> createdBy,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  required String id,
  required String restaurantId,
  required int visitDate,
  required int rating,
  Value<String?> notes,
  required int priceRange,
  Value<int> rowid,
});
typedef $$VisitsTableUpdateCompanionBuilder = VisitsCompanion Function({
  Value<String?> groupId,
  Value<String?> createdBy,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> id,
  Value<String> restaurantId,
  Value<int> visitDate,
  Value<int> rating,
  Value<String?> notes,
  Value<int> priceRange,
  Value<int> rowid,
});

final class $$VisitsTableReferences
    extends BaseReferences<_$AppDatabase, $VisitsTable, Visit> {
  $$VisitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RestaurantsTable _restaurantIdTable(_$AppDatabase db) =>
      db.restaurants.createAlias('visits__restaurantId__restaurants__id');

  $$RestaurantsTableProcessedTableManager get restaurantId {
    final $_column = $_itemColumn<String>('restaurantId')!;

    final manager = $$RestaurantsTableTableManager(
      $_db,
      $_db.restaurants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_restaurantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PhotosTable, List<Photo>> _photosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.photos,
    aliasName: 'visits__id__photos__visitId',
  );

  $$PhotosTableProcessedTableManager get photosRefs {
    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.visitId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_photosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VisitsTableFilterComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visitDate => $composableBuilder(
    column: $table.visitDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceRange => $composableBuilder(
    column: $table.priceRange,
    builder: (column) => ColumnFilters(column),
  );

  $$RestaurantsTableFilterComposer get restaurantId {
    final $$RestaurantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restaurantId,
      referencedTable: $db.restaurants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestaurantsTableFilterComposer(
            $db: $db,
            $table: $db.restaurants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> photosRefs(
    Expression<bool> Function($$PhotosTableFilterComposer f) f,
  ) {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.visitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visitDate => $composableBuilder(
    column: $table.visitDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceRange => $composableBuilder(
    column: $table.priceRange,
    builder: (column) => ColumnOrderings(column),
  );

  $$RestaurantsTableOrderingComposer get restaurantId {
    final $$RestaurantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restaurantId,
      referencedTable: $db.restaurants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestaurantsTableOrderingComposer(
            $db: $db,
            $table: $db.restaurants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get visitDate =>
      $composableBuilder(column: $table.visitDate, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get priceRange => $composableBuilder(
    column: $table.priceRange,
    builder: (column) => column,
  );

  $$RestaurantsTableAnnotationComposer get restaurantId {
    final $$RestaurantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restaurantId,
      referencedTable: $db.restaurants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestaurantsTableAnnotationComposer(
            $db: $db,
            $table: $db.restaurants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> photosRefs<T extends Object>(
    Expression<T> Function($$PhotosTableAnnotationComposer a) f,
  ) {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.visitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisitsTable,
          Visit,
          $$VisitsTableFilterComposer,
          $$VisitsTableOrderingComposer,
          $$VisitsTableAnnotationComposer,
          $$VisitsTableCreateCompanionBuilder,
          $$VisitsTableUpdateCompanionBuilder,
          (Visit, $$VisitsTableReferences),
          Visit,
          PrefetchHooks Function({bool restaurantId, bool photosRefs})
        > {
  $$VisitsTableTableManager(_$AppDatabase db, $VisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> groupId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> restaurantId = const Value.absent(),
                Value<int> visitDate = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> priceRange = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion(
                groupId: groupId,
                createdBy: createdBy,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                restaurantId: restaurantId,
                visitDate: visitDate,
                rating: rating,
                notes: notes,
                priceRange: priceRange,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> groupId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String id,
                required String restaurantId,
                required int visitDate,
                required int rating,
                Value<String?> notes = const Value.absent(),
                required int priceRange,
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion.insert(
                groupId: groupId,
                createdBy: createdBy,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                restaurantId: restaurantId,
                visitDate: visitDate,
                rating: rating,
                notes: notes,
                priceRange: priceRange,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VisitsTable, Visit>(table),
                  $$VisitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({restaurantId = false, photosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (photosRefs) db.photos],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (restaurantId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.restaurantId,
                        referencedTable: $$VisitsTableReferences
                            ._restaurantIdTable(db),
                        referencedColumn: $$VisitsTableReferences
                            ._restaurantIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (photosRefs)
                    await $_getPrefetchedData<Visit, $VisitsTable, Photo>(
                      currentTable: table,
                      referencedTable: $$VisitsTableReferences._photosRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$VisitsTableReferences(db, table, p0).photosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.visitId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisitsTable,
      Visit,
      $$VisitsTableFilterComposer,
      $$VisitsTableOrderingComposer,
      $$VisitsTableAnnotationComposer,
      $$VisitsTableCreateCompanionBuilder,
      $$VisitsTableUpdateCompanionBuilder,
      (Visit, $$VisitsTableReferences),
      Visit,
      PrefetchHooks Function({bool restaurantId, bool photosRefs})
    >;
typedef $$PhotosTableCreateCompanionBuilder = PhotosCompanion Function({
  Value<String?> groupId,
  Value<String?> createdBy,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  required String id,
  Value<String?> restaurantId,
  Value<String?> visitId,
  required String path,
  required int position,
  Value<int> rowid,
});
typedef $$PhotosTableUpdateCompanionBuilder = PhotosCompanion Function({
  Value<String?> groupId,
  Value<String?> createdBy,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> id,
  Value<String?> restaurantId,
  Value<String?> visitId,
  Value<String> path,
  Value<int> position,
  Value<int> rowid,
});

final class $$PhotosTableReferences
    extends BaseReferences<_$AppDatabase, $PhotosTable, Photo> {
  $$PhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RestaurantsTable _restaurantIdTable(_$AppDatabase db) =>
      db.restaurants.createAlias('photos__restaurantId__restaurants__id');

  $$RestaurantsTableProcessedTableManager? get restaurantId {
    final $_column = $_itemColumn<String>('restaurantId');
    if ($_column == null) return null;
    final manager = $$RestaurantsTableTableManager(
      $_db,
      $_db.restaurants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_restaurantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VisitsTable _visitIdTable(_$AppDatabase db) =>
      db.visits.createAlias('photos__visitId__visits__id');

  $$VisitsTableProcessedTableManager? get visitId {
    final $_column = $_itemColumn<String>('visitId');
    if ($_column == null) return null;
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_visitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$RestaurantsTableFilterComposer get restaurantId {
    final $$RestaurantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restaurantId,
      referencedTable: $db.restaurants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestaurantsTableFilterComposer(
            $db: $db,
            $table: $db.restaurants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableFilterComposer get visitId {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.visitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$RestaurantsTableOrderingComposer get restaurantId {
    final $$RestaurantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restaurantId,
      referencedTable: $db.restaurants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestaurantsTableOrderingComposer(
            $db: $db,
            $table: $db.restaurants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableOrderingComposer get visitId {
    final $$VisitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.visitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableOrderingComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$RestaurantsTableAnnotationComposer get restaurantId {
    final $$RestaurantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restaurantId,
      referencedTable: $db.restaurants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestaurantsTableAnnotationComposer(
            $db: $db,
            $table: $db.restaurants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableAnnotationComposer get visitId {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.visitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosTable,
          Photo,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (Photo, $$PhotosTableReferences),
          Photo,
          PrefetchHooks Function({bool restaurantId, bool visitId})
        > {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> groupId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> restaurantId = const Value.absent(),
                Value<String?> visitId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion(
                groupId: groupId,
                createdBy: createdBy,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                restaurantId: restaurantId,
                visitId: visitId,
                path: path,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> groupId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String id,
                Value<String?> restaurantId = const Value.absent(),
                Value<String?> visitId = const Value.absent(),
                required String path,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion.insert(
                groupId: groupId,
                createdBy: createdBy,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                restaurantId: restaurantId,
                visitId: visitId,
                path: path,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhotosTable, Photo>(table),
                  $$PhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({restaurantId = false, visitId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (restaurantId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.restaurantId,
                        referencedTable: $$PhotosTableReferences
                            ._restaurantIdTable(db),
                        referencedColumn: $$PhotosTableReferences
                            ._restaurantIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (visitId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.visitId,
                        referencedTable: $$PhotosTableReferences._visitIdTable(
                          db,
                        ),
                        referencedColumn: $$PhotosTableReferences
                            ._visitIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosTable,
      Photo,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (Photo, $$PhotosTableReferences),
      Photo,
      PrefetchHooks Function({bool restaurantId, bool visitId})
    >;
typedef $$PendingSyncsTableCreateCompanionBuilder =
    PendingSyncsCompanion Function({
      required String sharedTable,
      required String rowId,
      required String groupId,
      Value<int> rowid,
    });
typedef $$PendingSyncsTableUpdateCompanionBuilder =
    PendingSyncsCompanion Function({
      Value<String> sharedTable,
      Value<String> rowId,
      Value<String> groupId,
      Value<int> rowid,
    });

class $$PendingSyncsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSyncsTable> {
  $$PendingSyncsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sharedTable => $composableBuilder(
    column: $table.sharedTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingSyncsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSyncsTable> {
  $$PendingSyncsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sharedTable => $composableBuilder(
    column: $table.sharedTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSyncsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSyncsTable> {
  $$PendingSyncsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sharedTable => $composableBuilder(
    column: $table.sharedTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);
}

class $$PendingSyncsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSyncsTable,
          PendingSync,
          $$PendingSyncsTableFilterComposer,
          $$PendingSyncsTableOrderingComposer,
          $$PendingSyncsTableAnnotationComposer,
          $$PendingSyncsTableCreateCompanionBuilder,
          $$PendingSyncsTableUpdateCompanionBuilder,
          (
            PendingSync,
            BaseReferences<_$AppDatabase, $PendingSyncsTable, PendingSync>,
          ),
          PendingSync,
          PrefetchHooks Function()
        > {
  $$PendingSyncsTableTableManager(_$AppDatabase db, $PendingSyncsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSyncsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSyncsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSyncsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sharedTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingSyncsCompanion(
                sharedTable: sharedTable,
                rowId: rowId,
                groupId: groupId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sharedTable,
                required String rowId,
                required String groupId,
                Value<int> rowid = const Value.absent(),
              }) => PendingSyncsCompanion.insert(
                sharedTable: sharedTable,
                rowId: rowId,
                groupId: groupId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingSyncsTable, PendingSync>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingSyncsTable,
                    PendingSync
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingSyncsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSyncsTable,
      PendingSync,
      $$PendingSyncsTableFilterComposer,
      $$PendingSyncsTableOrderingComposer,
      $$PendingSyncsTableAnnotationComposer,
      $$PendingSyncsTableCreateCompanionBuilder,
      $$PendingSyncsTableUpdateCompanionBuilder,
      (
        PendingSync,
        BaseReferences<_$AppDatabase, $PendingSyncsTable, PendingSync>,
      ),
      PendingSync,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String groupId,
      required String lastPulledAt,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> groupId,
      Value<String> lastPulledAt,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> lastPulledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                groupId: groupId,
                lastPulledAt: lastPulledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String lastPulledAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                groupId: groupId,
                lastPulledAt: lastPulledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RestaurantsTableTableManager get restaurants =>
      $$RestaurantsTableTableManager(_db, _db.restaurants);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db, _db.visits);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$PendingSyncsTableTableManager get pendingSyncs =>
      $$PendingSyncsTableTableManager(_db, _db.pendingSyncs);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
}
