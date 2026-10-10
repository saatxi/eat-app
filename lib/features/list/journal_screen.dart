import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/journal_density.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../../data/groups/group_models.dart';
import '../groups/add_to_groups_dialog.dart';
import '../groups/group_scope_button.dart';
import '../groups/group_sync_button.dart';
import '../groups/groups_controller.dart';
import 'journal_filter_bar.dart';
import 'restaurant_card.dart';
import 'restaurant_list_controller.dart';
import 'restaurant_ui_model.dart';

/// The Journal: the app's primary surface. A prominent search field and a row of
/// quick segments (All / Visited / Want to try / Favorites) sit above the cards,
/// with the finer filters folded underneath and an add button floating over the
/// list.
///
/// This replaces the old restaurants/favourites pair of tabs: Favorites is now
/// one of the segments on this one screen rather than a destination of its own,
/// and the layout is a column of soft cards rather than compact rows. The screen
/// owns its [RestaurantListController] and rebuilds from it through a
/// `ListenableBuilder`; the controller is built in [didChangeDependencies]
/// because it reads the repositories off [AppScope], and an inherited-widget
/// lookup is only legal once dependencies have been established.
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    this.onOpenRestaurant,
    this.onAddRestaurant,
  });

  /// Null leaves the cards untappable — the case in a bare widget test.
  final ValueChanged<RestaurantUiModel>? onOpenRestaurant;
  final VoidCallback? onAddRestaurant;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  RestaurantListController? _controller;

  /// Owned here rather than by the bar so the screen can push the active query
  /// back into it when a filter change resets it.
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= RestaurantListController(
      repository: scope.restaurants,
      preferences: scope.preferences,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// A card only ever requests a delete; the confirmation is shown here, and the
  /// card is removed only once it is accepted.
  Future<void> _confirmDelete(RestaurantUiModel restaurant) async {
    final bool confirmed = await showDeleteConfirmDialog(context);
    if (!confirmed) {
      return;
    }
    await _controller?.deleteRestaurant(restaurant.id);
  }

  /// Whether a long press may start the bulk "Add to group" selection: only
  /// with groups in play and at least one group the user may write to.
  bool _canAddToGroups(GroupsController? groups) =>
      groups != null &&
      groups.canUseGroups &&
      groups.state.groups.any((Group group) => group.role.canEdit);

  /// Asks which groups the ticked restaurants go into, adds them, and confirms
  /// with a snackbar. Dismissing the dialog leaves the selection as it was.
  Future<void> _addSelectedToGroups(
    RestaurantListController controller,
    GroupsController groups,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppScope scope = AppScope.of(context);
    final Set<String>? chosen = await showAddToGroupsDialog(
      context,
      groups: groups.state.groups,
    );
    if (chosen == null || chosen.isEmpty) {
      return;
    }
    final String? me = (await scope.identity?.current())?.userId;
    if (me == null) {
      return;
    }
    final int added = await controller.addSelectedToGroups(
      chosen,
      createdBy: me,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.listAddedToGroups(added))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The scope selector listens to the groups controller itself, so the screen
    // no longer has to rebuild when the selection moves — and the Members
    // action it used to drive from the app bar now lives in Settings.
    return _scaffold(context);
  }

  Widget _scaffold(BuildContext context) {
    final RestaurantListController controller = _controller!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppScope scope = AppScope.of(context);
    final GroupsController? groups = scope.groupsController;

    // The preferences are listened to as well, so switching the list density
    // in Settings re-lays the cards out without rebuilding the controller.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        scope.preferences.listenable,
      ]),
      builder: (BuildContext context, Widget? child) {
        final RestaurantListUiState state = controller.state;
        final bool compact =
            scope.preferences.current.journalDensity == JournalDensity.compact;
        // Keep the field in step with the state: clearing the filters resets
        // the query, and the field has to go blank with it.
        if (_searchController.text != state.searchQuery) {
          _searchController.value = TextEditingValue(
            text: state.searchQuery,
            selection: TextSelection.collapsed(
              offset: state.searchQuery.length,
            ),
          );
        }
        // Back leaves selection mode before it leaves the screen.
        return PopScope(
          canPop: !state.isSelecting,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              controller.clearSelection();
            }
          },
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxScrolled) => <Widget>[
                    if (state.isSelecting && groups != null)
                      _selectionAppBar(state, controller, groups, l10n)
                    else
                      _appBar(groups, l10n),
                  ],
              body: Column(
                children: <Widget>[
                  JournalFilterBar(
                    controller: controller,
                    state: state,
                    searchController: _searchController,
                    showFilters: !state.isInitialLoad &&
                        (state.restaurants.isNotEmpty ||
                            state.hasActiveFilter ||
                            state.favoritesOnly),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _refresh(controller, groups),
                      child: _content(state, controller, groups, l10n, compact: compact),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _appBar(GroupsController? groups, AppLocalizations l10n) {
    return SliverAppBar(
      pinned: true,
      title: Text(l10n.navJournal),
      actions: <Widget>[
        if (groups != null && groups.canUseGroups) ...<Widget>[
          GroupScopeButton(controller: groups),
          GroupSyncButton(controller: groups),
        ],
        if (widget.onAddRestaurant != null)
          IconButton(
            onPressed: widget.onAddRestaurant,
            tooltip: l10n.listActionAddRestaurant,
            icon: const Icon(Icons.add_rounded),
          ),
      ],
    );
  }

  /// The contextual bar shown while restaurants are ticked. Its actions are
  /// icon-only, with tooltips, so the count in the title never has to compete
  /// with a translated button label for the width.
  Widget _selectionAppBar(
    RestaurantListUiState state,
    RestaurantListController controller,
    GroupsController groups,
    AppLocalizations l10n,
  ) {
    return SliverAppBar(
      pinned: true,
      leading: IconButton(
        onPressed: controller.clearSelection,
        tooltip: l10n.listActionCancelSelection,
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text(
        l10n.listSelectionCount(state.selectedIds.length),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: <Widget>[
        IconButton(
          onPressed: controller.selectAllVisible,
          tooltip: l10n.listActionSelectAll,
          icon: const Icon(Icons.select_all_rounded),
        ),
        IconButton(
          onPressed: () => _addSelectedToGroups(controller, groups),
          tooltip: l10n.listActionAddToGroup,
          icon: const Icon(Icons.group_add_rounded),
        ),
      ],
    );
  }

  /// Pull-to-refresh: pull the selected group's changes, then re-run the local
  /// query. The pull is what surfaces a restaurant another member added; the
  /// requery then shows it. A no-op when no group is selected.
  Future<void> _refresh(
    RestaurantListController controller,
    GroupsController? groups,
  ) async {
    await groups?.syncNow();
    await controller.refresh();
  }

  Widget _content(
    RestaurantListUiState state,
    RestaurantListController controller,
    GroupsController? groups,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    if (state.isInitialLoad) {
      // The database has not emitted yet, so an empty list here means "not
      // loaded", not "nothing to show" — painting the empty state would flash it
      // for a frame on every cold start.
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        itemCount: skeletonRowCount,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) =>
            RestaurantCardSkeleton(compact: compact),
      );
    }

    final bool noResults = state.restaurants.isEmpty;

    if (noResults && !state.hasActiveFilter) {
      // There is nothing to narrow down yet — either no restaurant has been
      // added, or the Favorites segment is on and none has been hearted.
      return _refreshableEmpty(
        state.favoritesOnly
            ? EmptyState(
                icon: Icons.favorite_border_rounded,
                title: l10n.favoritesEmptyTitle,
                body: l10n.favoritesEmptyBody,
              )
            : EmptyState(
                icon: Icons.restaurant_menu_rounded,
                title: l10n.listEmptyTitle,
                body: l10n.listEmptyBody,
                actionLabel:
                    widget.onAddRestaurant != null
                        ? l10n.listActionAddRestaurant
                        : null,
                onAction: widget.onAddRestaurant,
              ),
      );
    }

    // A result count is most useful precisely when something has narrowed the
    // list down; browsing everything, it would just repeat the obvious.
    final Widget? header = state.hasActiveFilter
        ? Semantics(
            // A live region, so narrowing the list announces the new count
            // instead of leaving a screen-reader user to go looking for it.
            liveRegion: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.listResultCount(state.restaurants.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        : null;
    final int headerCount = header == null ? 0 : 1;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: headerCount + (noResults ? 1 : state.restaurants.length),
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        if (header != null && index == 0) {
          return header;
        }
        if (noResults) {
          return SizedBox(
            height: 360,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.listEmptyNoResultsTitle,
              body: l10n.listEmptyNoResultsBody,
              actionLabel: l10n.listActionClearFilters,
              onAction: controller.clearFilters,
            ),
          );
        }
        final RestaurantUiModel restaurant =
            state.restaurants[index - headerCount];
        return StaggeredEntrance(
          // Indexed by the card's place in the list, so the cascade runs top to
          // bottom whether or not the result-count header is showing above it.
          index: index,
          child: RestaurantCard(
            restaurant: restaurant,
            compact: compact,
            selectionMode: state.isSelecting,
            selected: state.selectedIds.contains(restaurant.id),
            onTap: state.isSelecting
                ? () => controller.toggleSelection(restaurant.id)
                : widget.onOpenRestaurant == null
                ? null
                : () => widget.onOpenRestaurant!(restaurant),
            onLongPress: _canAddToGroups(groups)
                ? () {
                    HapticFeedback.selectionClick();
                    controller.startSelection(restaurant.id);
                  }
                : null,
            onFavoriteToggle: controller.toggleFavorite,
            onDeleteRequest: () => _confirmDelete(restaurant),
          ),
        );
      },
    );
  }

  /// Wraps a shorter-than-the-viewport state so it can still be pulled.
  ///
  /// A [RefreshIndicator] needs a scrollable child, and the empty states are
  /// centred blocks lighter than the screen — handed over raw, they would give
  /// the gesture nothing to grab.
  Widget _refreshableEmpty(Widget child) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: child,
              ),
            ),
      );
}
