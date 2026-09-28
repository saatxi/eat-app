import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import 'groups_controller.dart';

/// The scope switcher above the list: Personal, and each of the user's groups.
///
/// A switch, not a management surface — creating, joining and the members
/// roster live on the settings screen's Groups section. Every group is listed
/// here all the same: dropping the ones that are not in force would leave no way
/// back to a group after choosing Personal without a detour through Settings.
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
            ],
          ),
        );
      },
    );
  }
}
