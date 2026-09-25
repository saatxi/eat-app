import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// The confirmation shown before an irreversible delete — shared by the detail
/// screen's trash icon and the list/favourites rows' swipe-to-delete gesture, so
/// the wording and button layout for the same destructive action cannot drift
/// between its two entry points.
///
/// Returns true only when the user confirmed; dismissing returns false. Ported
/// from `ui/common/DeleteConfirmDialog.kt`.
Future<bool> showDeleteConfirmDialog(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(l10n.detailDeleteConfirmTitle),
      content: Text(l10n.detailDeleteConfirmBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.actionDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
