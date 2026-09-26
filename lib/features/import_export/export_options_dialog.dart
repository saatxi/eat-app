import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

/// The "what goes in the file?" step shown before any share or export — one
/// restaurant from the detail screen, the whole list from "share all", or the
/// settings "export my data" row. All three want the same decision (whether to
/// carry visits along), so they share one dialog rather than three hand-rolled
/// variants whose wording could drift.
///
/// Ported from `ui/common/ExportOptionsDialog.kt`. Resolves to the chosen
/// "include visits" value, or null when the user backs out — dismissing with the
/// Cancel button or the system back gesture. Callers read that null as "don't
/// export anything", so a stray tap never writes a file.
Future<bool?> showExportOptionsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => const _ExportOptionsDialog(),
  );
}

class _ExportOptionsDialog extends StatefulWidget {
  const _ExportOptionsDialog();

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  /// On by default: visits are the user's own history and the whole point of a
  /// backup, so turning the switch off is the deliberate opt-out.
  bool _includeVisits = true;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.exportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.exportDialogBody),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Switch(
                value: _includeVisits,
                onChanged: (bool value) =>
                    setState(() => _includeVisits = value),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.exportDialogIncludeVisits)),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_includeVisits),
          child: Text(l10n.actionExport),
        ),
      ],
    );
  }
}
