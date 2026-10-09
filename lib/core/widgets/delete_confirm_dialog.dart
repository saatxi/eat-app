import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// The confirmation shown before an irreversible delete — shared by the detail
/// screen's trash icon, the list/favourites rows' swipe-to-delete gesture and
/// the visit form's delete action, so the wording and button layout for the
/// same destructive action cannot drift between its entry points.
///
/// [title] names what is being deleted; it defaults to the restaurant copy,
/// which is what all but the visit form delete. The body is deliberately not a
/// parameter: "this can't be undone" is true of every one of them.
///
/// Returns true only when the user confirmed; dismissing returns false. Ported
/// from `ui/common/DeleteConfirmDialog.kt`.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  String? title,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title ?? l10n.detailDeleteConfirmTitle),
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
