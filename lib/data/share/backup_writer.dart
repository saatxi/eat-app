import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'restaurant_share_models.dart';
import 'restaurant_share_writer.dart';

/// Where the automatic on-device snapshot goes after every change.
///
/// An interface rather than a bare function so the repository can take one
/// without dragging `path_provider`'s platform channel into every unit test —
/// the tests pass a fake (or nothing at all), and only `main` wires in the real
/// [FileBackupWriter].
abstract interface class BackupWriter {
  Future<void> write(List<RestaurantExport> restaurants);
}

/// Writes the snapshot to `backup.json` in the app's support directory.
///
/// That is the same directory the database file lives in — so the snapshot
/// travels with the data on an Android Auto Backup or iOS device restore, and
/// a user never has to have pressed "export" for it to be current.
class FileBackupWriter implements BackupWriter {
  const FileBackupWriter();

  @override
  Future<void> write(List<RestaurantExport> restaurants) async {
    final Directory directory = await getApplicationSupportDirectory();
    await writeBackupFile(directory: directory, restaurants: restaurants);
  }
}
