import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/groups/group_models.dart';
import 'groups_controller.dart';

/// The scope selector as an app-bar action: a button naming the scope in force
/// that opens a menu of Personal and every group.
///
/// Shared by the journal, the roulette and the statistics screens — they all
/// read the same [GroupsController], so switching here moves all three at once.
///
/// The label is the group's own name, capped by [_labelWidth] and ellipsized:
/// wide enough to recognise the group at a glance, narrow enough to leave the
/// app bar's title and its other actions their room. The full name is the
/// tooltip, and the menu lists every scope.
///
/// Only ever built when [GroupsController.canUseGroups] is true, so a build
/// without a backend shows nothing at all.
class GroupScopeButton extends StatelessWidget {
  const GroupScopeButton({super.key, required this.controller});

  final GroupsController controller;

  /// How wide the scope's name is allowed to grow before it ellipsizes. Sized to
  /// fit a group name beside the journal's title and its two other actions.
  static const double _labelWidth = 84;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final GroupsState state = controller.state;
        final Group? selected = state.selected;
        final String scope = selected?.name ?? l10n.groupsScopePersonal;
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
            return Tooltip(
              message: scope,
              child: TextButton(
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _labelWidth),
                      child: Text(
                        scope,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
