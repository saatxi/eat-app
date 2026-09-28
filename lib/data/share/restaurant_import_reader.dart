import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'restaurant_share_models.dart';

/// A file bigger than this is rejected before it is even parsed.
const int maxImportBytes = 5 * 1024 * 1024;

enum ImportFailureReason { tooLarge, invalidFile, ioError }

/// One validated import row: the [Restaurant] itself paired with its own
/// validated visits and its exported favourite flag.
///
/// The flag is kept here rather than on [Restaurant] because it is not a
/// restaurant column — it lives in the user's preferences, so the writer has to
/// re-apply it by id once the row lands.
class ImportedRestaurant {
  const ImportedRestaurant({
    required this.restaurant,
    required this.visits,
    this.isFavorite = false,
  });

  final Restaurant restaurant;
  final List<VisitExport> visits;
  final bool isFavorite;
}

/// The result of parsing a share file.
sealed class ImportOutcome {
  const ImportOutcome();
}

final class ImportSuccess extends ImportOutcome {
  const ImportSuccess({required this.restaurants, required this.skippedCount});

  final List<ImportedRestaurant> restaurants;

  /// How many rows were dropped by per-row validation rather than failing the
  /// whole file.
  final int skippedCount;
}

final class ImportError extends ImportOutcome {
  const ImportError(this.reason);

  final ImportFailureReason reason;
}

const Uuid _uuid = Uuid();

/// Parses and validates a share file already read into memory.
///
/// Deliberately free of any Flutter or platform import: the file's *contents*
/// are untrusted, and the same rule applies — validate every field before
/// anything reaches the database. Fetching the bytes off a picked file is a
/// separate step handled by the import screen.
ImportOutcome readRestaurantImport(String rawJson) {
  // A UTF-8 BOM is legal at the head of a text file but not inside JSON, and
  // Dart's parser rejects it outright — so a file that picked one up in transit
  // (a Windows editor's "save as", a cloud round-trip) would be turned away as
  // if it were somebody else's file, though its bytes are otherwise identical
  // to one the app wrote. Drop a single leading BOM before parsing.
  final String source = rawJson.startsWith('\uFEFF')
      ? rawJson.substring(1)
      : rawJson;

  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return const ImportError(ImportFailureReason.invalidFile);
  }

  if (decoded is! Map<String, Object?>) {
    return const ImportError(ImportFailureReason.invalidFile);
  }
  if (decoded['format'] != restaurantShareFormat) {
    return const ImportError(ImportFailureReason.invalidFile);
  }
  final Object? rawRestaurants = decoded['restaurants'];
  if (rawRestaurants is! List<Object?>) {
    return const ImportError(ImportFailureReason.invalidFile);
  }

  final List<ImportedRestaurant> imported = <ImportedRestaurant>[];
  for (final Object? entry in rawRestaurants) {
    final ImportedRestaurant? candidate = _readRow(entry);
    if (candidate != null) {
      imported.add(candidate);
    }
  }

  return ImportSuccess(
    restaurants: imported,
    skippedCount: rawRestaurants.length - imported.length,
  );
}

/// One row, or null when it fails validation and should be dropped.
ImportedRestaurant? _readRow(Object? entry) {
  if (entry is! Map<String, Object?>) {
    return null;
  }
  final RestaurantExport export;
  try {
    export = RestaurantExport.fromJson(entry);
  } on Object {
    // A missing or mistyped required field is this row's problem, not the
    // file's — the same per-row-lenient rule the rest of the import follows.
    return null;
  }
  final Restaurant? restaurant = restaurantFromExport(export, _uuid.v4());
  if (restaurant == null) {
    return null;
  }
  return ImportedRestaurant(
    restaurant: restaurant,
    visits: validatedVisits(export),
    isFavorite: export.isFavorite,
  );
}
