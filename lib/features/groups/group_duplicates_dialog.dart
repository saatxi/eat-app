import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

/// What the user chose when told a restaurant looks like one the group has.
enum GroupDuplicatesChoice {
  /// Leave the look-alikes out and add the rest.
  skip,

  /// Add every one regardless, as a separate copy.
  addAnyway,
}

/// Warns that [names] look like restaurants the chosen group already has, since
/// each copy gets its own id and nothing would merge them afterwards.
///
/// [allowSkip] offers leaving just those out — for a bulk add, where the rest
/// of the selection can still go in; a single restaurant only has "add anyway"
/// or backing out. Resolves to null when the dialog is dismissed or cancelled.
Future<GroupDuplicatesChoice?> showGroupDuplicatesDialog(
  BuildContext context, {
  required List<String> names,
  bool allowSkip = false,
}) {
  return showDialog<GroupDuplicatesChoice>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l10n.groupDuplicatesTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Text(l10n.groupDuplicatesMessage(names.length)),
              const SizedBox(height: 8),
              for (final String name in names)
                Text('• $name', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(GroupDuplicatesChoice.addAnyway),
            child: Text(l10n.groupDuplicatesAddAnyway),
          ),
          if (allowSkip)
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(GroupDuplicatesChoice.skip),
              child: Text(l10n.groupDuplicatesSkip),
            ),
        ],
      );
    },
  );
}
