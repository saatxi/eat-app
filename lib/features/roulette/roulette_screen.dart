import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_motion.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_dropdown_chip.dart';
import '../../core/widgets/price_range_label.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/rating_and_price_row.dart';
import '../../core/widgets/restaurant_thumbnail.dart';
import '../list/journal_filter_bar.dart' show JournalSegment;
import '../list/restaurant_ui_model.dart';
import 'roulette_controller.dart';

/// "Can't decide? Let the app pick." — a random restaurant from a pool narrowed
/// by a few light filters.
///
/// Ported from `ui/roulette/RouletteScreen.kt`.
class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key, this.onOpenRestaurant});

  final ValueChanged<RestaurantUiModel>? onOpenRestaurant;

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> {
  RouletteController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= RouletteController(
      repository: scope.restaurants,
      preferences: scope.preferences,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RouletteController controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final RouletteState state = controller.state;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.rouletteTitle)),
          body: Column(
            children: <Widget>[
              _Filters(state: state, controller: controller),
              Expanded(child: _content(state, controller, l10n)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(
    RouletteState state,
    RouletteController controller,
    AppLocalizations l10n,
  ) {
    if (state.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmpty) {
      return EmptyState(
        icon: Icons.casino_outlined,
        title: l10n.rouletteEmptyTitle,
        body: l10n.rouletteEmptyBody,
      );
    }

    final RestaurantUiModel? picked = state.picked;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            // The card is exactly as tall as what it has to say, and a short
            // window — or a large system text size — can leave it less room than
            // that. Scaling the whole reveal down keeps it fully on screen: the
            // card is never clipped or left below the fold the way a scroll
            // would, and it stays at its natural size whenever there is room to
            // spare.
            child: Center(
              // Keyed by the spin count so a repeat pick still re-runs the
              // fade, which is what makes a second tap feel like it did
              // something even when it landed on the same place.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  // Fades and settles into place rather than popping: the reveal
                  // is the app's one theatrical moment, and an organic ease-out
                  // matches the redesign's "no hard bounce" rule.
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) =>
                      FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                      child: child,
                    ),
                  ),
                  child: picked == null
                      ? _Prompt(
                          key: const ValueKey<String>('prompt'),
                          l10n: l10n,
                        )
                      : PressableScale(
                          key: ValueKey<String>('pick-${state.pickCount}'),
                          child: _ResultCard(
                            restaurant: picked,
                            onTap: widget.onOpenRestaurant == null
                                ? null
                                : () => widget.onOpenRestaurant!(picked),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              // The app's one deliberately theatrical moment, so the tap weighs
              // more than an ordinary button's to match the reveal above it.
              HapticFeedback.mediumImpact();
              controller.pick();
            },
            icon: const Icon(Icons.casino),
            label: Text(
              picked == null
                  ? l10n.rouletteActionPick
                  : l10n.rouletteActionAgain,
            ),
          ),
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.casino_outlined,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.roulettePrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.restaurant, this.onTap});

  final RestaurantUiModel restaurant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String priceLabel = priceRangeLabel(l10n, restaurant.priceRange);
    // Region and country only: the full street address is the detail screen's
    // job, and would crowd the card.
    final String? location = restaurant.formattedRegionCountry;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RestaurantThumbnail(
                cuisineKey: restaurant.cuisineKey,
                photoPath: restaurant.photoPath,
                size: 72,
                iconSize: 32,
                semanticLabel: l10n.detailPhotoDescription,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                restaurant.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                cuisineLabel(l10n, restaurant.cuisineKey),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (location != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  location,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              RatingAndPriceRow(
                rating: restaurant.rating,
                priceLabel: priceLabel,
                starSize: 20,
                showRatingLabel: false,
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same filter dimensions the restaurants list offers — quick view, rating,
/// price, cuisine, region and country — drawn with the same dropdown chips, so
/// the two screens filter their restaurants the same way.
/// The quick view the state is currently on, shared by the header and the chips.
JournalSegment _segmentOf(RouletteState state) {
  if (state.favoritesOnly) {
    return JournalSegment.favorites;
  }
  return switch (state.visited) {
    true => JournalSegment.visited,
    false => JournalSegment.wantToTry,
    null => JournalSegment.all,
  };
}

/// How many dimensions are narrowing the pool, for the header's badge.
int _activeCountOf(RouletteState state) =>
    (_segmentOf(state) != JournalSegment.all ? 1 : 0) +
    (state.minRating != null ? 1 : 0) +
    (state.priceRange != null ? 1 : 0) +
    (state.cuisineType != null ? 1 : 0) +
    (state.region != null ? 1 : 0) +
    (state.country != null ? 1 : 0);

/// The roulette's filters, behind the same collapsible "Filters" header the
/// restaurants list uses — so the two screens present the same controls the same
/// way, and the spinner keeps the vertical space when nothing is being narrowed.
class _Filters extends StatefulWidget {
  const _Filters({required this.state, required this.controller});

  final RouletteState state;
  final RouletteController controller;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final int count = _activeCountOf(widget.state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.listFiltersTitle, style: theme.textTheme.labelLarge),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
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
                  turns: _expanded ? 0.5 : 0,
                  duration: AppMotion.short,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // AnimatedSize rather than a hard swap: the section folds open and shut
        // instead of appearing at full height in one frame.
        AnimatedSize(
          duration: AppMotion.short,
          curve: AppMotion.entering,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _FilterChips(state: widget.state, controller: widget.controller)
              : const SizedBox(width: double.infinity),
        ),
        Divider(color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}

/// The chips themselves, laid out exactly as the restaurants list lays out its
/// own: a wrapping grid of dropdowns, with the candidate count beside them.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state, required this.controller});

  final RouletteState state;
  final RouletteController controller;

  void _applySegment(JournalSegment segment) {
    controller.onFavoritesOnlyChange(segment.favoritesOnly);
    controller.onVisitedChange(segment.visitedFilter);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JournalSegment segment = _segmentOf(state);
    final List<MapEntry<String, String>> cuisines = <MapEntry<String, String>>[
      for (final String key in state.availableCuisines)
        MapEntry<String, String>(key, cuisineLabel(l10n, key)),
    ]..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              // The quick view as one dropdown, since its options are exclusive.
              FilterDropdownChip(
                selectedLabel: segment == JournalSegment.all
                    ? l10n.journalSegmentsLabel
                    : _segmentLabel(l10n, segment),
                isActive: segment != JournalSegment.all,
                menuBuilder: (VoidCallback close) => <Widget>[
                  for (final JournalSegment option in JournalSegment.values)
                    MenuItemButton(
                      onPressed: () {
                        _applySegment(option);
                        close();
                      },
                      trailingIcon: option == segment
                          ? const Icon(Icons.check_rounded)
                          : null,
                      child: Text(_segmentLabel(l10n, option)),
                    ),
                ],
              ),
              FilterDropdownChip(
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
              ),
              FilterDropdownChip(
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
              ),
              // Only the cuisine, region and country values actually present in
              // the data are offered, so no dropdown opens empty.
              if (cuisines.isNotEmpty)
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
              // How many places a spin could land on — the number that explains
              // why a filter combination is turning up nothing.
              if (!state.isInitialLoad)
                Chip(
                  avatar: const Icon(Icons.casino_outlined, size: 18),
                  label: Text(l10n.listResultCount(state.candidates.length)),
                ),
            ],
          ),
          if (_activeCountOf(state) > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.clearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(l10n.listActionClearFilters),
              ),
            ),
        ],
      ),
    );
  }

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
          trailingIcon: value == null ? const Icon(Icons.check_rounded) : null,
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
}
