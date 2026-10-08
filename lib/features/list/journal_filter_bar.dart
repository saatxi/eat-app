import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/filter_dropdown_chip.dart';
import '../../core/widgets/price_range_label.dart';
import '../../core/widgets/presentation_bounds.dart';
import '../../data/models/restaurant_sort.dart';
import 'restaurant_list_controller.dart';

/// The list's quick view: everything / visited / want-to-try / favourites.
///
/// Exclusive by nature — picking one clears the other — so it is drawn as a
/// single dropdown chip like every other dimension rather than as a row of
/// chips, which is what keeps the filter panel to one tidy grid.
enum JournalSegment {
  all,
  visited,
  wantToTry,
  favorites;

  /// The visited / want-to-try dimension this segment maps onto in the query.
  /// `favorites` leaves it open and narrows on the favourite flag instead.
  bool? get visitedFilter => switch (this) {
    JournalSegment.all => null,
    JournalSegment.visited => true,
    JournalSegment.wantToTry => false,
    JournalSegment.favorites => null,
  };

  bool get favoritesOnly => this == JournalSegment.favorites;
}

/// The top of the list: a prominent search field and, behind a compact filter
/// button, the sort control and all filter dimensions inside a bottom sheet.
///
/// Only the search field and the filter button are always visible; the sheet
/// stays hidden until the user asks for it, so the list gets the vertical
/// space.
class JournalFilterBar extends StatefulWidget {
  const JournalFilterBar({
    super.key,
    required this.controller,
    required this.state,
    required this.searchController,
    required this.showFilters,
  });

  final RestaurantListController controller;
  final RestaurantListUiState state;

  /// Owned by the screen, so a filter change that resets the query can push the
  /// empty string back into the field.
  final TextEditingController searchController;

  /// Hides the filter button while there is nothing to sort or filter yet (the
  /// initial load, or before any restaurant exists at all). The search field
  /// stays.
  final bool showFilters;

  @override
  State<JournalFilterBar> createState() => _JournalFilterBarState();
}

class _JournalFilterBarState extends State<JournalFilterBar> {
  JournalSegment get _segment {
    if (widget.state.favoritesOnly) {
      return JournalSegment.favorites;
    }
    return switch (widget.state.visited) {
      true => JournalSegment.visited,
      false => JournalSegment.wantToTry,
      null => JournalSegment.all,
    };
  }

  int get _activeFilterCount =>
      (_segment != JournalSegment.all ? 1 : 0) +
      (widget.state.minRating != null ? 1 : 0) +
      (widget.state.cuisineType != null ? 1 : 0) +
      (widget.state.city != null ? 1 : 0) +
      (widget.state.region != null ? 1 : 0) +
      (widget.state.country != null ? 1 : 0) +
      (widget.state.priceRange != null ? 1 : 0);

  void _applySegment(JournalSegment segment) {
    widget.controller.onFavoritesOnlyChange(segment.favoritesOnly);
    widget.controller.onVisitedChange(segment.visitedFilter);
  }

  /// Clears every dimension, including the quick view.
  void _clearAll() {
    widget.controller.clearFilterDimensions();
    widget.controller.onFavoritesOnlyChange(false);
  }

  /// Opens the filter sheet that holds the sort control and all filter chips.
  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        // Rebuild the sheet whenever the controller emits a new state, so
        // selecting a chip instantly reflects in the rest of the sheet.
        // Both segment and activeFilterCount are derived from the live
        // controller state (not the outer widget's snapshot) so that a chip
        // selection inside the sheet is reflected immediately.
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (BuildContext context, Widget? child) {
            final RestaurantListUiState s = widget.controller.state;
            final JournalSegment seg = _segmentFromState(s);
            return _FilterSheet(
              state: s,
              controller: widget.controller,
              segment: seg,
              activeFilterCount: _activeFilterCountFromState(s, seg),
              onApplySegment: _applySegment,
              onClearAll: _clearAll,
            );
          },
        );
      },
    );
  }

  static JournalSegment _segmentFromState(RestaurantListUiState s) {
    if (s.favoritesOnly) return JournalSegment.favorites;
    return switch (s.visited) {
      true => JournalSegment.visited,
      false => JournalSegment.wantToTry,
      null => JournalSegment.all,
    };
  }

  static int _activeFilterCountFromState(
    RestaurantListUiState s,
    JournalSegment seg,
  ) =>
      (seg != JournalSegment.all ? 1 : 0) +
      (s.minRating != null ? 1 : 0) +
      (s.cuisineType != null ? 1 : 0) +
      (s.city != null ? 1 : 0) +
      (s.region != null ? 1 : 0) +
      (s.country != null ? 1 : 0) +
      (s.priceRange != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final int count = _activeFilterCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  onChanged: widget.controller.onSearchQueryChange,
                  decoration: InputDecoration(
                    hintText: l10n.listSearchPlaceholder,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: widget.searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              widget.searchController.clear();
                              widget.controller.onSearchQueryChange('');
                            },
                            tooltip: l10n.listSearchClear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  // Results already follow every keystroke, so the Search key
                  // has nothing left to submit — it just dismisses the keyboard.
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              if (widget.showFilters) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                // Compact filter button: tune icon + active-count badge.
                // Styled as an outlined icon button so it reads as a secondary
                // action next to the prominent search field.
                _FilterButton(
                  count: count,
                  theme: theme,
                  l10n: l10n,
                  onTap: _openFilterSheet,
                ),
              ],
            ],
          ),
        ),
        Divider(color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}

/// The compact filter button that sits beside the search field.
///
/// Shows the [count] of active filters as a badge on the tune icon so the user
/// can tell at a glance that something is narrowing the list.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.count,
    required this.theme,
    required this.l10n,
    required this.onTap,
  });

  final int count;
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasFilters = count > 0;
    return Semantics(
      button: true,
      label: hasFilters
          ? l10n.listFiltersActiveCount(count)
          : l10n.listFiltersTitle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: hasFilters
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: hasFilters
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (hasFilters) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The bottom sheet content: sort control + all filter chips.
///
/// Rebuilt on every controller state change so chips reflect their active
/// state instantly without the sheet needing its own [StatefulWidget].
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.state,
    required this.controller,
    required this.segment,
    required this.activeFilterCount,
    required this.onApplySegment,
    required this.onClearAll,
  });

  final RestaurantListUiState state;
  final RestaurantListController controller;
  final JournalSegment segment;
  final int activeFilterCount;
  final ValueChanged<JournalSegment> onApplySegment;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    // Sheet content scrolls on tall filter lists and small screens.
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Sort
              Text(l10n.listSortLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<RestaurantSort>(
                  segments: <ButtonSegment<RestaurantSort>>[
                    for (final RestaurantSort option in RestaurantSort.values)
                      ButtonSegment<RestaurantSort>(
                        value: option,
                        label: Text(_sortLabel(l10n, option)),
                        tooltip: _sortLabel(l10n, option),
                      ),
                  ],
                  selected: <RestaurantSort>{state.sort},
                  onSelectionChanged: (Set<RestaurantSort> selection) =>
                      controller.onSortChange(selection.first),
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Filter chips
              Text(l10n.listFiltersTitle, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _segmentChip(l10n),
                  _ratingChip(l10n),
                  _priceChip(l10n),
                  ..._cuisineChips(l10n),
                  ..._locationChips(l10n),
                ],
              ),
              if (activeFilterCount > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onClearAll,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: Text(l10n.listActionClearFilters),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _segmentChip(AppLocalizations l10n) => FilterDropdownChip(
    selectedLabel: segment == JournalSegment.all
        ? l10n.journalSegmentsLabel
        : _segmentLabel(l10n, segment),
    isActive: segment != JournalSegment.all,
    menuBuilder: (VoidCallback close) => <Widget>[
      for (final JournalSegment s in JournalSegment.values)
        MenuItemButton(
          onPressed: () {
            onApplySegment(s);
            close();
          },
          trailingIcon: s == segment
              ? const Icon(Icons.check_rounded)
              : null,
          child: Text(_segmentLabel(l10n, s)),
        ),
    ],
  );

  Widget _ratingChip(AppLocalizations l10n) => FilterDropdownChip(
    selectedLabel: state.minRating == null
        ? l10n.listFilterMinRating
        : '${state.minRating}+',
    isActive: state.minRating != null,
    menuBuilder: (VoidCallback close) => <Widget>[
      for (int rating = 1; rating <= maxRating; rating++)
        MenuItemButton(
          onPressed: () {
            controller.onMinRatingChange(
              state.minRating == rating ? null : rating,
            );
            close();
          },
          trailingIcon: state.minRating == rating
              ? const Icon(Icons.check_rounded)
              : null,
          child: Text('$rating+'),
        ),
    ],
  );

  Widget _priceChip(AppLocalizations l10n) => FilterDropdownChip(
    selectedLabel: state.priceRange == null
        ? l10n.listFilterPrice
        : priceRangeLabel(l10n, state.priceRange!),
    isActive: state.priceRange != null,
    menuBuilder: (VoidCallback close) => <Widget>[
      for (int price = 1; price <= maxPriceRange; price++)
        MenuItemButton(
          onPressed: () {
            controller.onPriceRangeChange(
              state.priceRange == price ? null : price,
            );
            close();
          },
          trailingIcon: state.priceRange == price
              ? const Icon(Icons.check_rounded)
              : null,
          child: Text(priceRangeLabel(l10n, price)),
        ),
    ],
  );

  List<Widget> _cuisineChips(AppLocalizations l10n) {
    if (state.availableCuisines.isEmpty) {
      return const <Widget>[];
    }
    final List<MapEntry<String, String>> cuisines = <MapEntry<String, String>>[
      for (final String key in state.availableCuisines)
        MapEntry<String, String>(key, cuisineLabel(l10n, key)),
    ]..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );
    return <Widget>[
      FilterDropdownChip(
        selectedLabel: state.cuisineType == null
            ? l10n.listFilterCuisine
            : cuisines
                  .firstWhere(
                    (MapEntry<String, String> entry) =>
                        entry.key == state.cuisineType,
                    orElse: () => MapEntry<String, String>(
                      state.cuisineType!,
                      cuisineLabel(l10n, state.cuisineType!),
                    ),
                  )
                  .value,
        isActive: state.cuisineType != null,
        leading: state.cuisineType == null
            ? null
            : Icon(cuisineIcon(state.cuisineType!), size: 18),
        menuBuilder: (VoidCallback close) => <Widget>[
          for (final MapEntry<String, String> entry in cuisines)
            MenuItemButton(
              onPressed: () {
                controller.onCuisineChange(
                  state.cuisineType == entry.key ? null : entry.key,
                );
                close();
              },
              leadingIcon: Icon(cuisineIcon(entry.key)),
              trailingIcon: state.cuisineType == entry.key
                  ? const Icon(Icons.check_rounded)
                  : null,
              child: Text(entry.value),
            ),
        ],
      ),
    ];
  }

  List<Widget> _locationChips(AppLocalizations l10n) => <Widget>[
    if (state.availableRegions.isNotEmpty)
      _locationChip(
        l10n: l10n,
        label: l10n.listFilterRegion,
        value: state.region,
        options: state.availableRegions,
        onChanged: controller.onRegionChange,
      ),
    if (state.availableCountries.isNotEmpty)
      _locationChip(
        l10n: l10n,
        label: l10n.listFilterCountry,
        value: state.country,
        options: state.availableCountries,
        onChanged: controller.onCountryChange,
      ),
  ];

  Widget _locationChip({
    required AppLocalizations l10n,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) => FilterDropdownChip(
    selectedLabel: value ?? label,
    isActive: value != null,
    menuBuilder: (VoidCallback close) => <Widget>[
      MenuItemButton(
        onPressed: () {
          onChanged(null);
          close();
        },
        trailingIcon:
            value == null ? const Icon(Icons.check_rounded) : null,
        child: Text(l10n.listFilterAll),
      ),
      for (final String option in options)
        MenuItemButton(
          onPressed: () {
            onChanged(value == option ? null : option);
            close();
          },
          trailingIcon:
              value == option ? const Icon(Icons.check_rounded) : null,
          child: Text(option),
        ),
    ],
  );

  static String _segmentLabel(AppLocalizations l10n, JournalSegment segment) =>
      switch (segment) {
        JournalSegment.all => l10n.journalSegmentAll,
        JournalSegment.visited => l10n.journalSegmentVisited,
        JournalSegment.wantToTry => l10n.journalSegmentWantToTry,
        JournalSegment.favorites => l10n.journalSegmentFavorites,
      };

  static String _sortLabel(AppLocalizations l10n, RestaurantSort sort) =>
      switch (sort) {
        RestaurantSort.name => l10n.listSortName,
        RestaurantSort.rating => l10n.listSortRating,
      };
}
