import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import 'groups_controller.dart';

/// The scope switcher above the list: Personal, and the group currently in
/// force.
///
/// Deliberately compact — this row only toggles between the private list and
/// the group you are already in. The full roster, plus creating, joining and
/// managing a group, lives on the settings screen's Groups section, so the top
/// of the Journal stays a switch rather than a management surface.
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
        // A selection that no longer resolves (the group was left or dissolved
        // elsewhere) reads as null, leaving Personal as the only chip — the
        // same fallback the rest of the app applies to a stale selection.
        final Group? selected = state.selected;
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
              if (selected != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: Text(selected.name),
                  selected: true,
                  onSelected: (_) => controller.select(selected.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
