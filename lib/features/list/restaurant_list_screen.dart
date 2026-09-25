import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import 'restaurant_list_controller.dart';
import 'restaurant_row.dart';
import 'restaurant_ui_model.dart';
import 'search_and_filter_bar.dart';

/// The list of restaurants: search, sort and filters above, the rows below, and
/// the loading, empty and no-results states in between.
///
/// The screen owns its [RestaurantListController] and rebuilds from it through a
/// `ListenableBuilder`, which is the Flutter counterpart of the Android screen's
/// `collectAsState()` over its ViewModel's `StateFlow`. The controller is built
/// in [didChangeDependencies] rather than `initState` because it reads the
/// repositories off [AppScope], and an inherited-widget lookup is only legal
/// once dependencies have been established.
class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({
    super.key,
    this.onOpenRestaurant,
    this.onAddRestaurant,
  });

  /// Null leaves the rows untappable — the case in a bare widget test.
  final ValueChanged<RestaurantUiModel>? onOpenRestaurant;
  final VoidCallback? onAddRestaurant;

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
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

  /// A row only ever requests a delete; the confirmation is shown here, and the
  /// row is removed only once it is accepted.
  Future<void> _confirmDelete(RestaurantUiModel restaurant) async {
    final bool confirmed = await showDeleteConfirmDialog(context);
    if (!confirmed) {
      return;
    }
    await _controller?.deleteRestaurant(restaurant.id);
  }

  @override
  Widget build(BuildContext context) {
    final RestaurantListController controller = _controller!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.listTitle),
        // A two-stop tonal wash rather than a flat container colour: a sense of
        // place above the list without touching the app bar's scroll behaviour.
        flexibleSpace: const _TopGradient(),
      ),
      floatingActionButton: widget.onAddRestaurant == null
          ? null
          : FloatingActionButton(
              onPressed: widget.onAddRestaurant,
              tooltip: l10n.listActionAddRestaurant,
              child: const Icon(Icons.add),
            ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          final RestaurantListUiState state = controller.state;
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
          return Column(
            children: <Widget>[
              SearchAndFilterBar(
                searchController: _searchController,
                onSearchQueryChange: controller.onSearchQueryChange,
                // Nothing to sort or filter yet during the first load, or before
                // any restaurant has ever been added.
                showSortAndFilters: !state.isInitialLoad &&
                    (state.restaurants.isNotEmpty || state.hasActiveFilter),
                sort: state.sort,
                onSortChange: controller.onSortChange,
                minRating: state.minRating,
                onMinRatingChange: controller.onMinRatingChange,
                cuisineType: state.cuisineType,
                availableCuisines: state.availableCuisines,
                onCuisineChange: controller.onCuisineChange,
                visited: state.visited,
                onVisitedChange: controller.onVisitedChange,
                city: state.city,
                availableCities: state.availableCities,
                onCityChange: controller.onCityChange,
                region: state.region,
                availableRegions: state.availableRegions,
                onRegionChange: controller.onRegionChange,
                country: state.country,
                availableCountries: state.availableCountries,
                onCountryChange: controller.onCountryChange,
                priceRange: state.priceRange,
                onPriceRangeChange: controller.onPriceRangeChange,
              ),
              Expanded(child: _content(state, controller, l10n)),
            ],
          );
        },
      ),
    );
  }

  Widget _content(
    RestaurantListUiState state,
    RestaurantListController controller,
    AppLocalizations l10n,
  ) {
    if (state.isInitialLoad) {
      // The database has not emitted yet, so an empty list here means "not
      // loaded", not "nothing to show" — painting the empty state would flash it
      // for a frame on every cold start. Shape-matching skeleton rows read as
      // faster than a centred spinner even though the wait is identical.
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: skeletonRowCount,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) =>
            const RestaurantRowSkeleton(),
      );
    }

    if (state.restaurants.isEmpty && !state.hasActiveFilter) {
      // Nothing has ever been added: there are no filters to offer yet.
      return EmptyState(
        icon: Icons.restaurant_menu,
        title: l10n.listEmptyTitle,
        body: l10n.listEmptyBody,
        actionLabel:
            widget.onAddRestaurant == null ? null : l10n.listActionAddRestaurant,
        onAction: widget.onAddRestaurant,
      );
    }

    final bool noResults = state.restaurants.isEmpty;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 1 + (noResults ? 1 : state.restaurants.length),
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          // A result count is most useful precisely when a filter has narrowed
          // the list down; browsing everything instead, that same spot offers a
          // starting point rather than sitting blank.
          return state.hasActiveFilter
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.listResultCount(state.restaurants.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : SearchSuggestionsRow(
                  onMinRatingChange: controller.onMinRatingChange,
                  onVisitedChange: controller.onVisitedChange,
                );
        }
        if (noResults) {
          return SizedBox(
            height: 360,
            child: EmptyState(
              icon: Icons.search_off,
              title: l10n.listEmptyNoResultsTitle,
              body: l10n.listEmptyNoResultsBody,
              actionLabel: l10n.listActionClearFilters,
              onAction: controller.clearFilters,
            ),
          );
        }
        final RestaurantUiModel restaurant = state.restaurants[index - 1];
        return RestaurantRow(
          restaurant: restaurant,
          onTap: widget.onOpenRestaurant == null
              ? null
              : () => widget.onOpenRestaurant!(restaurant),
          onFavoriteToggle: controller.toggleFavorite,
          onDeleteRequest: () => _confirmDelete(restaurant),
        );
      },
    );
  }
}

class _TopGradient extends StatelessWidget {
  const _TopGradient();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[scheme.primaryContainer, scheme.surface],
        ),
      ),
    );
  }
}
