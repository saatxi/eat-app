import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'restaurant_share_models.dart';

/// A file bigger than this is rejected before it is even parsed.
const int maxImportBytes = 5 * 1024 * 1024;

enum ImportFailureReason { tooLarge, invalidFile, ioError }

/// One validated import row: the [Restaurant] itself paired with its own
/// validated tags and visits.
class ImportedRestaurant {
  const ImportedRestaurant({
    required this.restaurant,
    required this.tags,
    required this.visits,
  });

  final Restaurant restaurant;
  final List<String> tags;
  final List<VisitExport> visits;
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
  final Object? decoded;
  try {
    decoded = jsonDecode(rawJson);
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
    tags: validatedTagNames(export),
    visits: validatedVisits(export),
  );
}
