import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_motion.dart';
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

/// The top of the list: the prominent search field and, folded underneath, the
/// filter dimensions as a grid of dropdown chips — including the quick view
/// (all / visited / want-to-try / favourites) and the three location dimensions,
/// each its own chip rather than one sheet.
///
/// Only the search field is always visible; the chip grid stays folded until
/// asked for, so the list gets the vertical space.
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

  /// Hides the sort control and the filter panel while there is nothing to sort
  /// or filter yet (the initial load, or before any restaurant exists at all).
  /// The search field stays.
  final bool showFilters;

  @override
  State<JournalFilterBar> createState() => _JournalFilterBarState();
}

class _JournalFilterBarState extends State<JournalFilterBar> {
  bool _filtersExpanded = false;

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

  /// Clears every dimension, including the quick view — which lives outside
  /// [RestaurantFilters], so the panel has to reset it separately.
  void _clearAll() {
    widget.controller.clearFilterDimensions();
    widget.controller.onFavoritesOnlyChange(false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

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
            // Results already follow every keystroke, so the Search key has
            // nothing left to submit — it just gets the keyboard out of the way.
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        if (widget.showFilters) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<RestaurantSort>(
                segments: <ButtonSegment<RestaurantSort>>[
                  for (final RestaurantSort option in RestaurantSort.values)
                    ButtonSegment<RestaurantSort>(
                      value: option,
                      label: Text(_sortLabelShort(l10n, option)),
                      tooltip: _sortLabel(l10n, option),
                    ),
                ],
                selected: <RestaurantSort>{widget.state.sort},
                onSelectionChanged: (Set<RestaurantSort> selection) =>
                    widget.controller.onSortChange(selection.first),
                showSelectedIcon: false,
              ),
            ),
          ),
          _filtersHeader(theme, l10n),
          // AnimatedSize rather than a hard swap: the section folds open and
          // shut instead of appearing at full height in one frame.
          AnimatedSize(
            duration: AppMotion.short,
            curve: AppMotion.entering,
            alignment: Alignment.topCenter,
            child: _filtersExpanded
                ? _filterSection(l10n)
                : const SizedBox(width: double.infinity),
          ),
          Divider(color: theme.colorScheme.outlineVariant),
        ],
      ],
    );
  }

  Widget _filtersHeader(ThemeData theme, AppLocalizations l10n) {
    final int count = _activeFilterCount;
    return InkWell(
      onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.tune_rounded, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.listFiltersTitle, style: theme.textTheme.labelLarge),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Semantics(
                    label: l10n.listFiltersActiveCount(count),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            AnimatedRotation(
              turns: _filtersExpanded ? 0.5 : 0,
              duration: AppMotion.short,
              child: Icon(
                Icons.expand_more_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterSection(AppLocalizations l10n) {
    final List<MapEntry<String, String>> cuisines = <MapEntry<String, String>>[
      for (final String key in widget.state.availableCuisines)
        MapEntry<String, String>(key, cuisineLabel(l10n, key)),
    ]..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _segmentChip(l10n),
              FilterDropdownChip(
                selectedLabel: widget.state.minRating == null
                    ? l10n.listFilterMinRating
                    : '${widget.state.minRating}+',
                isActive: widget.state.minRating != null,
                menuBuilder: (VoidCallback close) => <Widget>[
                  for (int rating = 1; rating <= maxRating; rating++)
                    MenuItemButton(
                      onPressed: () {
                        widget.controller.onMinRatingChange(
                          widget.state.minRating == rating ? null : rating,
                        );
                        close();
                      },
                      trailingIcon: widget.state.minRating == rating
                          ? const Icon(Icons.check_rounded)
                          : null,
                      child: Text('$rating+'),
                    ),
                ],
              ),
              FilterDropdownChip(
                selectedLabel: widget.state.priceRange == null
                    ? l10n.listFilterPrice
                    : priceRangeLabel(l10n, widget.state.priceRange!),
                isActive: widget.state.priceRange != null,
                menuBuilder: (VoidCallback close) => <Widget>[
                  for (int price = 1; price <= maxPriceRange; price++)
                    MenuItemButton(
                      onPressed: () {
                        widget.controller.onPriceRangeChange(
                          widget.state.priceRange == price ? null : price,
                        );
                        close();
                      },
                      trailingIcon: widget.state.priceRange == price
                          ? const Icon(Icons.check_rounded)
                          : null,
                      child: Text(priceRangeLabel(l10n, price)),
                    ),
                ],
              ),
              // Only the cuisines actually present in the data are offered, so
              // the menu stays short instead of listing all 24 vocabulary
              // entries.
              if (cuisines.isNotEmpty)
                FilterDropdownChip(
                  selectedLabel: widget.state.cuisineType == null
                      ? l10n.listFilterCuisine
                      : cuisines
                            .firstWhere(
                              (MapEntry<String, String> entry) =>
                                  entry.key == widget.state.cuisineType,
                              orElse: () => MapEntry<String, String>(
                                widget.state.cuisineType!,
                                cuisineLabel(l10n, widget.state.cuisineType!),
                              ),
                            )
                            .value,
                  isActive: widget.state.cuisineType != null,
                  leading: widget.state.cuisineType == null
                      ? null
                      : Icon(cuisineIcon(widget.state.cuisineType!), size: 18),
                  menuBuilder: (VoidCallback close) => <Widget>[
                    for (final MapEntry<String, String> entry in cuisines)
                      MenuItemButton(
                        onPressed: () {
                          widget.controller.onCuisineChange(
                            widget.state.cuisineType == entry.key
                                ? null
                                : entry.key,
                          );
                          close();
                        },
                        leadingIcon: Icon(cuisineIcon(entry.key)),
                        trailingIcon: widget.state.cuisineType == entry.key
                            ? const Icon(Icons.check_rounded)
                            : null,
                        child: Text(entry.value),
                      ),
                  ],
                ),
              // Only the dimensions that actually have values are offered, the
              // same rule the cuisine chip follows: an empty dropdown whose menu
              // can only say "All" is noise.
              if (widget.state.availableRegions.isNotEmpty)
                _locationChip(
                  l10n: l10n,
                  label: l10n.listFilterRegion,
                  value: widget.state.region,
                  options: widget.state.availableRegions,
                  onChanged: widget.controller.onRegionChange,
                ),
              if (widget.state.availableCountries.isNotEmpty)
                _locationChip(
                  l10n: l10n,
                  label: l10n.listFilterCountry,
                  value: widget.state.country,
                  options: widget.state.availableCountries,
                  onChanged: widget.controller.onCountryChange,
                ),
            ],
          ),
          // Only while there is something to clear, the same rule the header's
          // count badge follows. On a line of its own rather than inside the
          // wrap, so it reads as the panel's action instead of one more filter.
          if (_activeFilterCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(l10n.listActionClearFilters),
              ),
            ),
        ],
      ),
    );
  }

  /// The quick view as one dropdown, since its options are mutually exclusive.
  Widget _segmentChip(AppLocalizations l10n) {
    final JournalSegment selected = _segment;
    return FilterDropdownChip(
      selectedLabel: selected == JournalSegment.all
          ? l10n.journalSegmentsLabel
          : _segmentLabel(l10n, selected),
      isActive: selected != JournalSegment.all,
      menuBuilder: (VoidCallback close) => <Widget>[
        for (final JournalSegment segment in JournalSegment.values)
          MenuItemButton(
            onPressed: () {
              _applySegment(segment);
              close();
            },
            trailingIcon: segment == selected
                ? const Icon(Icons.check_rounded)
                : null,
            child: Text(_segmentLabel(l10n, segment)),
          ),
      ],
    );
  }

  /// One location dimension as a dropdown chip: an "All" entry that clears the
  /// dimension, then every value present in the data. Only drawn when there is
  /// something to list, so a dimension with no values never opens an
  /// all-but-empty menu.
  Widget _locationChip({
    required AppLocalizations l10n,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return FilterDropdownChip(
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
  }

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

  static String _sortLabelShort(AppLocalizations l10n, RestaurantSort sort) =>
      switch (sort) {
        RestaurantSort.name => l10n.listSortNameShort,
        RestaurantSort.rating => l10n.listSortRatingShort,
      };
}
