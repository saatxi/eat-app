import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/groups/group_models.dart';
import 'groups_controller.dart';

/// The scope selector as an app-bar action: an icon that says which kind of
/// scope is in force and opens a menu of Personal and every group.
///
/// Shared by the journal, the roulette and the statistics screens — they all
/// read the same [GroupsController], so switching here moves all three at once.
/// An icon rather than the group's own name, because an app bar already carries
/// a title and up to three actions and a long name would not fit beside them;
/// the menu is where the names live.
///
/// Only ever built when [GroupsController.canUseGroups] is true, so a build
/// without a backend shows nothing at all.
class GroupScopeButton extends StatelessWidget {
  const GroupScopeButton({super.key, required this.controller});

  final GroupsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final GroupsState state = controller.state;
        final Group? selected = state.selected;
        return MenuAnchor(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () => controller.select(null),
              trailingIcon: selected == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              child: Text(l10n.groupsScopePersonal),
            ),
            for (final Group group in state.groups)
              MenuItemButton(
                onPressed: () => controller.select(group.id),
                trailingIcon: group.id == state.selectedGroupId
                    ? const Icon(Icons.check_rounded)
                    : null,
                child: Text(group.name),
              ),
          ],
          builder: (BuildContext context, MenuController menu, Widget? child) {
            return IconButton(
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              // The icon says which kind of scope is in force; the tooltip says
              // exactly which one, since the name itself has no room here.
              tooltip: selected?.name ?? l10n.groupsScopePersonal,
              icon: Icon(
                selected == null ? Icons.person_outline : Icons.group_outlined,
              ),
            );
          },
        );
      },
    );
  }
}
