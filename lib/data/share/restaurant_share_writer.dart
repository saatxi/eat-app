import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'restaurant_share_models.dart';

/// The subdirectory of a temp directory the share files are written to, so a
/// leftover share never mingles with anything else.
const String shareSubdir = 'shared';

/// The automatic device-backup snapshot's name.
const String backupFileName = 'backup.json';

/// Longest a restaurant's name is allowed to grow in a filename — long enough
/// to stay recognisable, short enough to stay portable.
const int _maxNameSlugLength = 60;

/// Used when a name is blank or nothing survives sanitising.
const String _fallbackSlug = 'restaurant';

/// Turns a restaurant name into a filesystem-safe slug: anything that isn't a
/// letter or a digit (spaces, punctuation, path separators) folds to a single
/// `-`, runs collapse, and the result is capped so one long name can't produce
/// an unwieldy filename. Letters keep their accents — a filename is UTF-8, and
/// stripping them would make `Cafè` unreachable from `Cafe`.
///
/// Dart's `toLowerCase` is locale-independent, so unlike a Turkish-locale
/// `lowercase()` it can't turn an `I` into a dotless `ı` here.
String restaurantNameSlug(String name) {
  final String slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-');
  final String capped = slug.length > _maxNameSlugLength
      ? slug.substring(0, _maxNameSlugLength)
      : slug;
  final String trimmed = _trimDashes(capped);
  return trimmed.isEmpty ? _fallbackSlug : trimmed;
}

/// e.g. `restaurants-20260913_1742.eatapp` for a bulk export, or
/// `cal-ferran-20260913_1742.eatapp` when sharing a single restaurant. The
/// timestamp is kept either way so re-sharing later doesn't overwrite a file
/// the recipient already saved under the same name.
String shareFileName({String? singleName, DateTime? now}) {
  final String base = singleName == null
      ? 'restaurants'
      : restaurantNameSlug(singleName);
  return '$base-${DateFormat('yyyyMMdd_HHmm').format(now ?? DateTime.now())}.eatapp';
}

/// Writes [restaurants] to a timestamped file under `directory/shared/` and
/// returns it. Any share file left over from a previous call is deleted first,
/// so the directory never accumulates one file per share.
///
/// [singleName], when non-null, is the one restaurant in [restaurants] and is
/// folded into the filename so a shared single restaurant arrives named after
/// itself rather than as a generic "restaurants" file.
Future<File> writeRestaurantShareFile({
  required Directory directory,
  required List<RestaurantExport> restaurants,
  String? singleName,
  DateTime? now,
}) async {
  final Directory dir = Directory(p.join(directory.path, shareSubdir));
  await dir.create(recursive: true);
  await for (final FileSystemEntity entity in dir.list()) {
    if (entity is File) {
      await entity.delete();
    }
  }
  final File file = File(
    p.join(dir.path, shareFileName(singleName: singleName, now: now)),
  );
  await file.writeAsString(encodeRestaurantShareFile(restaurants));
  return file;
}

/// Writes [restaurants] to `backup.json` under [directory].
///
/// Unlike [writeRestaurantShareFile], this is meant to live in the app's own
/// persistent support directory — next to the database, so Android's Auto
/// Backup and iOS's device backup cover it — never in a temp directory that
/// the OS is free to clear.
Future<File> writeBackupFile({
  required Directory directory,
  required List<RestaurantExport> restaurants,
}) async {
  final File file = File(p.join(directory.path, backupFileName));
  await file.writeAsString(encodeRestaurantShareFile(restaurants));
  return file;
}

String _trimDashes(String value) {
  int start = 0;
  int end = value.length;
  while (start < end && value.codeUnitAt(start) == 0x2D) {
    start++;
  }
  while (end > start && value.codeUnitAt(end - 1) == 0x2D) {
    end--;
  }
  return value.substring(start, end);
}
