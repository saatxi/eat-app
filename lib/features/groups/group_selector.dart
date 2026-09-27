import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import 'groups_controller.dart';

/// The scope selector above the list: Personal, each of the user's groups, and
/// a way to create a new one.
///
/// Only ever built when [GroupsController.canUseGroups] is true, so a build
/// without a backend never renders it at all.
class GroupSelector extends StatelessWidget {
  const GroupSelector({super.key, required this.controller});

  final GroupsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final GroupsState state = controller.state;
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.groupsScopePersonal),
                selected: state.selectedGroupId == null,
                onSelected: (_) => controller.select(null),
              ),
              for (final Group group in state.groups) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: Text(group.name),
                  selected: state.selectedGroupId == group.id,
                  onSelected: (_) => controller.select(group.id),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.groupsActionCreate),
                onPressed: () => _createGroup(context, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A one-field dialog rather than a whole screen: creating a group is a name
  /// and nothing else.
  Future<void> _createGroup(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final TextEditingController name = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.groupsCreateTitle),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.groupsFieldName),
          onSubmitted: (String value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              final String value = name.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: Text(l10n.groupsCreateAction),
          ),
        ],
      ),
    );
    name.dispose();
    if (result == null) {
      return;
    }
    await controller.createGroup(result);
  }
}
