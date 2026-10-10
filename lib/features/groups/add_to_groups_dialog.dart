import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/groups/group_models.dart';

/// Asks which of [groups] the Journal's ticked restaurants should be added to.
///
/// Only groups the user may write to are offered — a reader can't share into
/// one — so the caller passes the full list and this narrows it. Resolves to
/// the chosen group ids, or null when the dialog is dismissed.
Future<Set<String>?> showAddToGroupsDialog(
  BuildContext context, {
  required List<Group> groups,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (BuildContext context) => _AddToGroupsDialog(
      groups: <Group>[
        for (final Group group in groups)
          if (group.role.canEdit) group,
      ],
    ),
  );
}

class _AddToGroupsDialog extends StatefulWidget {
  const _AddToGroupsDialog({required this.groups});

  final List<Group> groups;

  @override
  State<_AddToGroupsDialog> createState() => _AddToGroupsDialogState();
}

class _AddToGroupsDialogState extends State<_AddToGroupsDialog> {
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    // With a single writable group there is nothing to choose between.
    if (widget.groups.length == 1) {
      _selected.add(widget.groups.single.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addToGroupsDialogTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final Group group in widget.groups)
              CheckboxListTile(
                value: _selected.contains(group.id),
                title: Text(group.name),
                onChanged: (bool? value) => setState(() {
                  if (value ?? false) {
                    _selected.add(group.id);
                  } else {
                    _selected.remove(group.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(<String>{..._selected}),
          child: Text(l10n.addToGroupsDialogConfirm),
        ),
      ],
    );
  }
}
