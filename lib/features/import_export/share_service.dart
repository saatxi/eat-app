import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/share/restaurant_share_models.dart';
import '../../data/share/restaurant_share_writer.dart';
import 'export_options_dialog.dart';

/// The MIME type of a shared restaurant file.
///
/// A plain, standard `application/json` — not a custom type — mirrors the
/// Android app and is what makes "Open with EatApp" reliable for a file
/// forwarded through another app, since those apps generally can't be trusted
/// to preserve a custom type. The native side also matches the ".eatapp"
/// extension directly as a fallback (see `restaurant_share_writer.dart`).
const String restaurantShareMimeType = 'application/json';

/// The global rect the system share sheet pops over from on iPad and Mac, or
/// null on platforms that anchor it themselves. Derived from the widget that
/// triggered the share so the popover points at it rather than the screen's
/// top-left corner.
Rect? sharePositionOriginFor(BuildContext context) {
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
  return null;
}

/// The whole share flow, in the order every caller wants it: ask what to
/// include, export the chosen rows from [repository], write a throwaway file
/// and open the system share sheet with it.
///
/// [restaurantIds] null means every restaurant ("share all" and Settings'
/// "export my data"); a single id means the detail screen's share of one.
/// [singleName] is that one restaurant's name, folded into the filename.
///
/// Nothing is exported until the user confirms the options dialog; an exception
/// on the way (a failed write, a platform channel error) surfaces as a snackbar
/// rather than crashing the screen.
Future<void> exportAndShareRestaurants(
  BuildContext context, {
  required RestaurantRepository repository,
  List<String>? restaurantIds,
  String? singleName,
}) async {
  // Read everything off the context before the first await, so no async gap
  // leaves these lookups dangling.
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  final bool? includeVisits = await showExportOptionsDialog(context);
  if (includeVisits == null || !context.mounted) {
    return;
  }
  final Rect? origin = sharePositionOriginFor(context);

  try {
    final List<RestaurantExport> exports = await repository.exportRestaurants(
      restaurantIds: restaurantIds,
      includeVisits: includeVisits,
    );
    await shareRestaurants(
      restaurants: exports,
      singleName: singleName,
      sharePositionOrigin: origin,
    );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
  }
}

/// Writes [restaurants] to a timestamped file under the temp directory and
/// opens the system share sheet with it.
Future<ShareResult> shareRestaurants({
  required List<RestaurantExport> restaurants,
  String? singleName,
  Rect? sharePositionOrigin,
}) async {
  final Directory directory = await getTemporaryDirectory();
  final File file = await writeRestaurantShareFile(
    directory: directory,
    restaurants: restaurants,
    singleName: singleName,
  );
  return SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: restaurantShareMimeType)],
      // XFile only derives a name from the path on some platforms; overriding it
      // keeps the ".eatapp" filename the recipient sees identical everywhere.
      fileNameOverrides: <String>[p.basename(file.path)],
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
