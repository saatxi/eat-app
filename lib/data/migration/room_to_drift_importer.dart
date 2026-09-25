import 'dart:convert' show latin1;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

/// Where the SQLite file the Kotlin app's Room database left behind lives.
///
/// Pulled out as an interface so the importer can be tested against a database
/// it creates itself, instead of a path that only exists on a phone that has
/// had both apps installed.
abstract interface class RoomDatabaseLocator {
  /// Null when there is nothing to migrate — a fresh install, or any platform
  /// where the Android app never ran.
  Future<File?> locate();
}

/// The real locator.
///
/// Room puts its database at `<dataDir>/databases/<name>`, i.e. the private
/// `databases/` directory next to the `files/` directory
/// `getApplicationSupportDirectory()` resolves to. `path_provider` has no
/// accessor for that directory itself, hence the parent hop; on every other
/// platform the file simply won't be there, and [locate] returns null.
class RoomDatabaseFileLocator implements RoomDatabaseLocator {
  const RoomDatabaseFileLocator();

  @override
  Future<File?> locate() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    final File candidate = File(
      p.join(supportDirectory.parent.path, 'databases', 'eatapp.db'),
    );
    return await candidate.exists() ? candidate : null;
  }
}

/// What [RoomToDriftImporter.run] did.
enum RoomImportOutcome {
  /// The flag saying the move already happened was set.
  alreadyImported,

  /// No Room database to move, or a file that isn't one. A perfectly normal
  /// outcome: it is what every fresh install gets.
  nothingToImport,

  /// Rows were copied across.
  imported,
}

/// Rows of one table, before and after the copy.
///
/// [copied] is counted in the drift database once the copy has finished rather
/// than taken from the insert's affected-row count, so a row silently skipped by
/// `OR IGNORE` shows up as a discrepancy instead of being reported as a success.
class RoomTableImport {
  const RoomTableImport({required this.available, required this.copied});

  /// Rows the legacy database held.
  final int available;

  /// Rows the drift database holds now.
  final int copied;

  bool get isComplete => copied >= available;
}

/// The result of one import attempt, detailed enough to log and to assert on.
class RoomImportResult {
  const RoomImportResult({
    required this.outcome,
    this.tables = const <String, RoomTableImport>{},
  });

  final RoomImportOutcome outcome;

  /// Keyed by SQLite table name, e.g. `restaurant_tags`.
  final Map<String, RoomTableImport> tables;

  /// True when every table's rows all made it. Only meaningful for
  /// [RoomImportOutcome.imported].
  bool get isComplete =>
      tables.values.every((RoomTableImport table) => table.isComplete);
}

/// Moves an existing Android install's database into the drift one.
///
/// The two apps share an `applicationId` and a signing key, so upgrading in
/// place leaves Room's file exactly where it was and fully readable; this runs
/// once, on first launch, and copies its rows into the drift-owned file. Rows
/// are matched by primary key, so ids — and therefore favourites and stored
/// photo paths — survive untouched.
///
/// The copy is done with `ATTACH DATABASE` and `INSERT ... SELECT`, entirely
/// inside SQLite: nothing is decoded, re-encoded or held in memory, which is
/// what keeps it fast enough to run before the first frame. Columns are named on
/// both sides rather than selected with `*`, because Room and drift each wrote
/// their own `CREATE TABLE` and the two are only guaranteed to agree on column
/// *names*, not on the order they were declared in.
///
/// Two safety nets: the legacy file is copied to `<name>.bak` (plus its write
/// ahead log, if Room left one) before anything is touched, and a flag in the
/// preference file keeps the whole thing from running twice.
class RoomToDriftImporter {
  RoomToDriftImporter({
    required this.database,
    required this.locator,
    required this.preferences,
  });

  /// Namespaced so it can't collide with a user preference.
  static const String _doneFlag = 'data_migration.room_to_drift.done';

  static const String _legacySchema = 'legacy';

  /// In foreign-key order, so every referenced row exists before the row that
  /// points at it — the connection runs with `PRAGMA foreign_keys = ON`, and
  /// that pragma's rules are not subject to `OR IGNORE`.
  static const List<_TableCopy> _copies = <_TableCopy>[
    _TableCopy('restaurants', <String>[
      'id',
      'name',
      'cuisineType',
      // The Kotlin entity calls this `streetAddress` and the column `address`;
      // only the column name matters here.
      'address',
      'priceRange',
      'website',
      'instagram',
      'city',
      'region',
      'country',
      'searchText',
    ]),
    _TableCopy('tags', <String>['id', 'name']),
    _TableCopy('restaurant_tags', <String>['restaurantId', 'tagId']),
    _TableCopy('visits', <String>[
      'id',
      'restaurantId',
      'visitDate',
      'rating',
      'notes',
      'priceRange',
    ]),
    _TableCopy('photos', <String>[
      'id',
      'restaurantId',
      'visitId',
      'path',
      'position',
    ]),
  ];

  final AppDatabase database;
  final RoomDatabaseLocator locator;
  final SharedPreferences preferences;

  bool get isDone => preferences.getBool(_doneFlag) ?? false;

  /// Imports if there is anything to import, and reports what happened. Safe to
  /// call on every launch: the flag short-circuits it after it has succeeded
  /// once.
  Future<RoomImportResult> run() async {
    if (isDone) {
      return const RoomImportResult(
        outcome: RoomImportOutcome.alreadyImported,
      );
    }

    final File? legacy = await locator.locate();
    if (legacy == null) {
      return const RoomImportResult(
        outcome: RoomImportOutcome.nothingToImport,
      );
    }

    // A file that exists but isn't a SQLite database — this checks the format
    // stamp before SQLite gets the chance to reject it, so an unrelated `.db`
    // that happens to share the name is a quiet no-op rather than an exception
    // raised on the far side of the database isolate.
    if (!await _isSqliteFile(legacy)) {
      return const RoomImportResult(
        outcome: RoomImportOutcome.nothingToImport,
      );
    }

    // Opening the drift side first, so that by the time anything is attached its
    // tables and its `user_version` already exist.
    await database.customSelect('SELECT 1').get();

    final String alias = _legacySchema;
    await database.customStatement('ATTACH DATABASE ? AS $alias', <Object?>[
      legacy.path,
    ]);

    // From here on the alias is attached, so it always gets detached again —
    // including on the `nothingToImport` short circuits below.
    try {
      if (!await _isRoomDatabase(alias)) {
        return const RoomImportResult(
          outcome: RoomImportOutcome.nothingToImport,
        );
      }

      await _backUp(legacy);

      final Map<String, int> available = <String, int>{};
      for (final _TableCopy copy in _copies) {
        available[copy.name] = await _count(alias, copy.name);
      }

      await database.transaction(() async {
        for (final _TableCopy copy in _copies) {
          await database.customStatement(copy.sql);
        }
      });

      final Map<String, RoomTableImport> tables = <String, RoomTableImport>{};
      for (final _TableCopy copy in _copies) {
        tables[copy.name] = RoomTableImport(
          available: available[copy.name] ?? 0,
          copied: await _count('main', copy.name),
        );
      }

      // Written last: a failure anywhere above leaves the flag unset, so the
      // next launch simply tries again.
      await preferences.setBool(_doneFlag, true);

      return RoomImportResult(
        outcome: RoomImportOutcome.imported,
        tables: tables,
      );
    } finally {
      await database.customStatement('DETACH DATABASE $alias');
    }
  }

  /// Every SQLite file starts with the same 16-byte stamp; anything shorter, or
  /// anything else, isn't one.
  Future<bool> _isSqliteFile(File file) async {
    final RandomAccessFile handle = await file.open();
    try {
      final Uint8List header = await handle.read(16);
      return header.length == 16 && latin1.decode(header) == 'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  /// Room stamps every database it creates with this bookkeeping table, which is
  /// what makes it cheap to tell one of ours from an unrelated `.db` file that
  /// happens to share the name.
  Future<bool> _isRoomDatabase(String alias) async {
    final QueryRow? row = await database
        .customSelect(
          "SELECT name FROM $alias.sqlite_master "
          "WHERE type = 'table' AND name = 'room_master_table'",
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<int> _count(String schema, String table) => database
      .customSelect('SELECT COUNT(*) AS count FROM $schema.$table')
      .getSingle()
      .then((QueryRow row) => row.read<int>('count'));

  /// A copy of the file, in the same directory so it travels with it. The write
  /// ahead log is Room's default journal mode, so a database whose last writes
  /// are still in `-wal` would otherwise be backed up incomplete.
  Future<void> _backUp(File legacy) async {
    await legacy.copy('${legacy.path}.bak');
    final File writeAheadLog = File('${legacy.path}-wal');
    if (await writeAheadLog.exists()) {
      await writeAheadLog.copy('${writeAheadLog.path}.bak');
    }
  }
}

/// One table's copy, as a named-column `INSERT ... SELECT`.
class _TableCopy {
  const _TableCopy(this.name, this.columns);

  final String name;
  final List<String> columns;

  /// `OR IGNORE` so a row that is already there — a repeated run after the
  /// preference flag was lost, say — is skipped rather than aborting startup.
  /// Genuine inconsistencies still fail loudly: SQLite does not let `OR IGNORE`
  /// swallow a foreign-key violation.
  String get sql {
    final String list = columns.join(', ');
    return 'INSERT OR IGNORE INTO $name ($list) '
        'SELECT $list FROM ${RoomToDriftImporter._legacySchema}.$name';
  }
}
