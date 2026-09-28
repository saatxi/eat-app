import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/filter_dropdown_chip.dart';
import '../../data/groups/group_models.dart';
import 'groups_controller.dart';

/// The scope switcher above the list: Personal, and the user's groups.
///
/// A switch, not a management surface — creating, joining and the members
/// roster live on the settings screen's Groups section.
///
/// Up to one group the row is plain chips, which is the clearest shape for two
/// choices. Past that it collapses to a single dropdown, so the row does not
/// grow without bound as groups are added.
///
/// Only ever built when [GroupsController.canUseGroups] is true, so a build
/// without a backend never renders it at all.
class GroupSelector extends StatelessWidget {
  const GroupSelector({super.key, required this.controller});

  final GroupsController controller;

  /// How many groups tip the row from chips over to a dropdown.
  static const int _chipLimit = 1;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final GroupsState state = controller.state;
        final bool dropdown = state.groups.length > _chipLimit;
        return SizedBox(
          height: 48,
          child: dropdown
              ? _ScopeDropdown(state: state, controller: controller)
              : _ScopeChips(state: state, controller: controller),
        );
      },
    );
  }
}

/// Personal and every group as a chip each — used while there is at most one
/// group, where the choice still fits comfortably on one line.
class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.state, required this.controller});

  final GroupsState state;
  final GroupsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
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
    );
  }
}

/// Every scope behind one dropdown chip, labelled with the one in force — the
/// shape the row takes once there is more than one group.
class _ScopeDropdown extends StatelessWidget {
  const _ScopeDropdown({required this.state, required this.controller});

  final GroupsState state;
  final GroupsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Group? selected = state.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilterDropdownChip(
          selectedLabel: selected?.name ?? l10n.groupsScopePersonal,
          // A group in force reads as active and Personal as the plain default —
          // the same emphasis the chips give the two.
          isActive: selected != null,
          menuBuilder: (VoidCallback close) => <Widget>[
            MenuItemButton(
              onPressed: () {
                controller.select(null);
                close();
              },
              trailingIcon: selected == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              child: Text(l10n.groupsScopePersonal),
            ),
            for (final Group group in state.groups)
              MenuItemButton(
                onPressed: () {
                  controller.select(group.id);
                  close();
                },
                trailingIcon: group.id == state.selectedGroupId
                    ? const Icon(Icons.check_rounded)
                    : null,
                child: Text(group.name),
              ),
          ],
        ),
      ),
    );
  }
}
