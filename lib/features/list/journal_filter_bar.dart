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

/// The Journal's top-of-screen controls: the prominent search field, the quick
/// segments (All / Visited / Want to try / Favorites) and, folded underneath, the
/// finer filter dimensions.
///
/// The segments are new: where the old design put "visited" in the filter panel
/// and gave favourites a whole bottom tab, this one line of chips answers the
/// question a journal user actually asks first — "what am I looking at right
/// now?" — without opening a panel. Only the search field is always visible; the
/// finer filters stay folded until asked for.
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
  /// The search field and the segments stay.
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
      (widget.state.minRating != null ? 1 : 0) +
      (widget.state.cuisineType != null ? 1 : 0) +
      (widget.state.city != null ? 1 : 0) +
      (widget.state.region != null ? 1 : 0) +
      (widget.state.country != null ? 1 : 0) +
      (widget.state.priceRange != null ? 1 : 0);

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
        _segments(l10n),
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

  Widget _segments(AppLocalizations l10n) {
    final JournalSegment selected = _segment;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: <Widget>[
          for (final JournalSegment segment in JournalSegment.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(_segmentLabel(l10n, segment)),
                selected: segment == selected,
                onSelected: (_) {
                  if (segment == selected) {
                    return;
                  }
                  widget.controller.onFavoritesOnlyChange(segment.favoritesOnly);
                  widget.controller.onVisitedChange(segment.visitedFilter);
                },
              ),
            ),
        ],
      ),
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
                        child: Text(entry.value),
                      ),
                  ],
                ),
              // City/region/country are unbounded free text, unlike the closed
              // cuisine vocabulary above — a menu entry per value could run to
              // dozens, so this one opens a sheet with all three groups instead.
              if (widget.state.availableCities.isNotEmpty ||
                  widget.state.availableRegions.isNotEmpty ||
                  widget.state.availableCountries.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 18),
                  label: Text(
                    _locationLabel(l10n),
                  ),
                  onPressed: _openLocationSheet,
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
                onPressed: widget.controller.clearFilterDimensions,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(l10n.listActionClearFilters),
              ),
            ),
        ],
      ),
    );
  }

  String _locationLabel(AppLocalizations l10n) {
    final int active =
        (widget.state.city != null ? 1 : 0) +
        (widget.state.region != null ? 1 : 0) +
        (widget.state.country != null ? 1 : 0);
    return active > 0
        ? l10n.listFilterLocationActive(active)
        : l10n.listFilterLocation;
  }

  Future<void> _openLocationSheet() => showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext sheetContext) => _LocationSheet(
          title: AppLocalizations.of(sheetContext).listFilterLocation,
          city: widget.state.city,
          availableCities: widget.state.availableCities,
          onCityChange: widget.controller.onCityChange,
          region: widget.state.region,
          availableRegions: widget.state.availableRegions,
          onRegionChange: widget.controller.onRegionChange,
          country: widget.state.country,
          availableCountries: widget.state.availableCountries,
          onCountryChange: widget.controller.onCountryChange,
        ),
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

  static String _sortLabelShort(AppLocalizations l10n, RestaurantSort sort) =>
      switch (sort) {
        RestaurantSort.name => l10n.listSortNameShort,
        RestaurantSort.rating => l10n.listSortRatingShort,
      };
}

/// The sheet the combined "Location" chip opens: city/region/country as three
/// independent single-select groups, each with an "All" chip that clears that
/// one dimension.
class _LocationSheet extends StatefulWidget {
  const _LocationSheet({
    required this.title,
    required this.city,
    required this.availableCities,
    required this.onCityChange,
    required this.region,
    required this.availableRegions,
    required this.onRegionChange,
    required this.country,
    required this.availableCountries,
    required this.onCountryChange,
  });

  final String title;
  final String? city;
  final List<String> availableCities;
  final ValueChanged<String?> onCityChange;
  final String? region;
  final List<String> availableRegions;
  final ValueChanged<String?> onRegionChange;
  final String? country;
  final List<String> availableCountries;
  final ValueChanged<String?> onCountryChange;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  // Mirrored locally: a modal route does not rebuild when the screen behind it
  // changes, so the chips have to update themselves as they are tapped.
  late String? _city = widget.city;
  late String? _region = widget.region;
  late String? _country = widget.country;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            _LocationGroup(
              label: l10n.listFilterCity,
              allLabel: l10n.listFilterAll,
              selected: _city,
              options: widget.availableCities,
              onChanged: (String? value) {
                setState(() => _city = value);
                widget.onCityChange(value);
              },
              topPadding: AppSpacing.lg,
            ),
            _LocationGroup(
              label: l10n.listFilterRegion,
              allLabel: l10n.listFilterAll,
              selected: _region,
              options: widget.availableRegions,
              onChanged: (String? value) {
                setState(() => _region = value);
                widget.onRegionChange(value);
              },
              topPadding: AppSpacing.lg,
            ),
            _LocationGroup(
              label: l10n.listFilterCountry,
              allLabel: l10n.listFilterAll,
              selected: _country,
              options: widget.availableCountries,
              onChanged: (String? value) {
                setState(() => _country = value);
                widget.onCountryChange(value);
              },
              topPadding: AppSpacing.lg,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationGroup extends StatelessWidget {
  const _LocationGroup({
    required this.label,
    required this.allLabel,
    required this.selected,
    required this.options,
    required this.onChanged,
    required this.topPadding,
  });

  final String label;
  final String allLabel;
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ChoiceChip(
                label: Text(allLabel),
                selected: selected == null,
                onSelected: (_) => onChanged(null),
              ),
              for (final String option in options)
                ChoiceChip(
                  label: Text(option),
                  selected: selected == option,
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
