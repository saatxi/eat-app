import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/filter_dropdown_chip.dart';
import '../../core/widgets/presentation_bounds.dart';
import '../../core/widgets/price_range_label.dart';
import '../../data/models/restaurant_sort.dart';

/// The search field, sort control and filter-chip panel — everything above the
/// list itself.
///
/// Reused whole by the favourites screen, which shows the same kind of list
/// rather than a second copy of this block, the same way it reuses
/// `RestaurantRow` and `EmptyState`.
///
/// [showSortAndFilters] hides the sort/filter section — but never the search
/// field itself — while there is nothing to sort or filter yet (the initial
/// load, or before any restaurant exists at all); each screen computes that
/// condition itself.
///
/// Ported from `ui/list/SearchAndFilterBar.kt`. The chip dropdowns use
/// [FilterDropdownChip], and the location sheet keeps local state while it is
/// open, since a modal route does not rebuild with the screen behind it.
class SearchAndFilterBar extends StatefulWidget {
  const SearchAndFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchQueryChange,
    required this.showSortAndFilters,
    required this.sort,
    required this.onSortChange,
    required this.minRating,
    required this.onMinRatingChange,
    required this.cuisineType,
    required this.availableCuisines,
    required this.onCuisineChange,
    required this.visited,
    required this.onVisitedChange,
    required this.city,
    required this.availableCities,
    required this.onCityChange,
    required this.region,
    required this.availableRegions,
    required this.onRegionChange,
    required this.country,
    required this.availableCountries,
    required this.onCountryChange,
    required this.priceRange,
    required this.onPriceRangeChange,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchQueryChange;
  final bool showSortAndFilters;
  final RestaurantSort sort;
  final ValueChanged<RestaurantSort> onSortChange;
  final int? minRating;
  final ValueChanged<int?> onMinRatingChange;
  final String? cuisineType;
  final List<String> availableCuisines;
  final ValueChanged<String?> onCuisineChange;
  final bool? visited;
  final ValueChanged<bool?> onVisitedChange;
  final String? city;
  final List<String> availableCities;
  final ValueChanged<String?> onCityChange;
  final String? region;
  final List<String> availableRegions;
  final ValueChanged<String?> onRegionChange;
  final String? country;
  final List<String> availableCountries;
  final ValueChanged<String?> onCountryChange;
  final int? priceRange;
  final ValueChanged<int?> onPriceRangeChange;

  /// Puts every dimension above back to "any" at once, so a stack of them does
  /// not have to be unpicked chip by chip. The search query is not one of them,
  /// and is left alone.
  final VoidCallback onClearFilters;

  @override
  State<SearchAndFilterBar> createState() => _SearchAndFilterBarState();
}

class _SearchAndFilterBarState extends State<SearchAndFilterBar> {
  bool _filtersExpanded = false;

  int get _activeFilterCount =>
      (widget.minRating != null ? 1 : 0) +
      (widget.cuisineType != null ? 1 : 0) +
      (widget.visited != null ? 1 : 0) +
      (widget.city != null ? 1 : 0) +
      (widget.region != null ? 1 : 0) +
      (widget.country != null ? 1 : 0) +
      (widget.priceRange != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            controller: widget.searchController,
            onChanged: widget.onSearchQueryChange,
            // A hint rather than a label: the label would float above the text
            // for good once the field has content, costing height for a field
            // whose purpose the icon already states.
            decoration: InputDecoration(
              hintText: l10n.listSearchPlaceholder,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: widget.searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onSearchQueryChange('');
                      },
                      tooltip: l10n.listSearchClear,
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            // Results already follow every keystroke, so the Search key has
            // nothing left to submit — it just gets the keyboard out of the way.
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        if (widget.showSortAndFilters) ...<Widget>[
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
                selected: <RestaurantSort>{widget.sort},
                onSelectionChanged: (Set<RestaurantSort> selection) =>
                    widget.onSortChange(selection.first),
                showSelectedIcon: false,
              ),
            ),
          ),
          _filtersHeader(theme, l10n),
          // AnimatedSize rather than a hard swap: the section folds open and
          // shut instead of appearing at full height in one frame.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _filtersExpanded
                ? _filterSection(l10n)
                : const SizedBox(width: double.infinity),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
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
            Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.listFiltersTitle, style: theme.textTheme.labelLarge),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
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
      for (final String key in widget.availableCuisines)
        MapEntry<String, String>(key, cuisineLabel(l10n, key)),
    ]..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );
    final int activeLocationCount =
        (widget.city != null ? 1 : 0) +
        (widget.region != null ? 1 : 0) +
        (widget.country != null ? 1 : 0);

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
                selectedLabel: switch (widget.visited) {
                  false => l10n.visitStatusWantToTry,
                  true => l10n.visitStatusVisited,
                  null => l10n.listFilterVisitStatus,
                },
                isActive: widget.visited != null,
                menuBuilder: (VoidCallback close) => <Widget>[
                  MenuItemButton(
                    onPressed: () {
                      widget.onVisitedChange(
                        widget.visited == false ? null : false,
                      );
                      close();
                    },
                    child: Text(l10n.visitStatusWantToTry),
                  ),
                  MenuItemButton(
                    onPressed: () {
                      widget.onVisitedChange(
                        widget.visited == true ? null : true,
                      );
                      close();
                    },
                    child: Text(l10n.visitStatusVisited),
                  ),
                ],
              ),
              FilterDropdownChip(
                selectedLabel: widget.minRating == null
                    ? l10n.listFilterMinRating
                    : '${widget.minRating}+',
                isActive: widget.minRating != null,
                menuBuilder: (VoidCallback close) => <Widget>[
                  for (int rating = 1; rating <= maxRating; rating++)
                    MenuItemButton(
                      onPressed: () {
                        widget.onMinRatingChange(
                          widget.minRating == rating ? null : rating,
                        );
                        close();
                      },
                      child: Text('$rating+'),
                    ),
                ],
              ),
              FilterDropdownChip(
                selectedLabel: widget.priceRange == null
                    ? l10n.listFilterPrice
                    : priceRangeLabel(l10n, widget.priceRange!),
                isActive: widget.priceRange != null,
                menuBuilder: (VoidCallback close) => <Widget>[
                  for (int price = 1; price <= maxPriceRange; price++)
                    MenuItemButton(
                      onPressed: () {
                        widget.onPriceRangeChange(
                          widget.priceRange == price ? null : price,
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
                  selectedLabel: widget.cuisineType == null
                      ? l10n.listFilterCuisine
                      : cuisines
                            .firstWhere(
                              (MapEntry<String, String> entry) =>
                                  entry.key == widget.cuisineType,
                              orElse: () => MapEntry<String, String>(
                                widget.cuisineType!,
                                cuisineLabel(l10n, widget.cuisineType!),
                              ),
                            )
                            .value,
                  isActive: widget.cuisineType != null,
                  leading: widget.cuisineType == null
                      ? null
                      : Icon(cuisineIcon(widget.cuisineType!), size: 18),
                  menuBuilder: (VoidCallback close) => <Widget>[
                    for (final MapEntry<String, String> entry in cuisines)
                      MenuItemButton(
                        onPressed: () {
                          widget.onCuisineChange(
                            widget.cuisineType == entry.key ? null : entry.key,
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
              // dozens, so this one opens a sheet with all three groups
              // instead.
              if (widget.availableCities.isNotEmpty ||
                  widget.availableRegions.isNotEmpty ||
                  widget.availableCountries.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 18),
                  label: Text(
                    activeLocationCount > 0
                        ? l10n.listFilterLocationActive(activeLocationCount)
                        : l10n.listFilterLocation,
                  ),
                  onPressed: _openLocationSheet,
                ),
            ],
          ),
          // Only while there is something to clear, the same rule the header's
          // count badge follows. On a line of its own rather than inside the
          // wrap, so it reads as the panel's action instead of as one more
          // filter to pick.
          if (_activeFilterCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onClearFilters,
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: Text(l10n.listActionClearFilters),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openLocationSheet() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext sheetContext) => _LocationSheet(
          title: AppLocalizations.of(sheetContext).listFilterLocation,
          city: widget.city,
          availableCities: widget.availableCities,
          onCityChange: widget.onCityChange,
          region: widget.region,
          availableRegions: widget.availableRegions,
          onRegionChange: widget.onRegionChange,
          country: widget.country,
          availableCountries: widget.availableCountries,
          onCountryChange: widget.onCountryChange,
        ),
      );

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
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionDone),
                ),
              ),
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
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: Text(allLabel),
                  selected: selected == null,
                  onSelected: (_) => onChanged(null),
                ),
                for (final String option in options)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(option),
                      selected: selected == option,
                      onSelected: (_) => onChanged(option),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What "top rated" means for the shortcut — the same threshold the rating
/// filter's own "4+" entry offers.
const int topRatedMinRating = 4;

/// A starting point for browsing, shown in place of the (otherwise blank) space
/// above the list once there is nothing to search or filter by yet. Each chip is
/// a shortcut into the bar's own filters, not a separate feature.
class SearchSuggestionsRow extends StatelessWidget {
  const SearchSuggestionsRow({
    super.key,
    required this.onMinRatingChange,
    required this.onVisitedChange,
  });

  final ValueChanged<int?> onMinRatingChange;
  final ValueChanged<bool?> onVisitedChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.listSuggestionsTitle,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.star, size: 18),
                label: Text(l10n.listSuggestionTopRated),
                onPressed: () => onMinRatingChange(topRatedMinRating),
              ),
              ActionChip(
                avatar: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(l10n.visitStatusWantToTry),
                onPressed: () => onVisitedChange(false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
