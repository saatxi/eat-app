import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_dropdown_chip.dart';
import '../../core/widgets/price_range_label.dart';
import '../../core/widgets/rating_and_price_row.dart';
import '../../core/widgets/restaurant_thumbnail.dart';
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
                  duration: const Duration(milliseconds: 250),
                  child: picked == null
                      ? _Prompt(
                          key: const ValueKey<String>('prompt'),
                          l10n: l10n,
                        )
                      : _ResultCard(
                          key: ValueKey<String>('pick-${state.pickCount}'),
                          restaurant: picked,
                          onTap: widget.onOpenRestaurant == null
                              ? null
                              : () => widget.onOpenRestaurant!(picked),
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
  const _ResultCard({super.key, required this.restaurant, this.onTap});

  final RestaurantUiModel restaurant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String priceLabel = priceRangeLabel(l10n, restaurant.priceRange);
    final String? address = restaurant.formattedAddress;

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
              if (address != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  address,
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

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.controller});

  final RouletteState state;
  final RouletteController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          FilterChip(
            selected: state.favoritesOnly,
            onSelected: controller.onFavoritesOnlyChange,
            avatar: state.favoritesOnly
                ? null
                : const Icon(Icons.favorite_border, size: 18),
            label: Text(l10n.rouletteOnlyFavorites),
          ),
          FilterDropdownChip(
            selectedLabel: switch (state.visited) {
              false => l10n.visitStatusWantToTry,
              true => l10n.visitStatusVisited,
              null => l10n.rouletteFilterStatus,
            },
            isActive: state.visited != null,
            menuBuilder: (VoidCallback close) => <Widget>[
              MenuItemButton(
                onPressed: () {
                  controller.onVisitedChange(
                    state.visited == false ? null : false,
                  );
                  close();
                },
                child: Text(l10n.visitStatusWantToTry),
              ),
              MenuItemButton(
                onPressed: () {
                  controller.onVisitedChange(state.visited == true ? null : true);
                  close();
                },
                child: Text(l10n.visitStatusVisited),
              ),
            ],
          ),
          FilterDropdownChip(
            selectedLabel: state.minRating == null
                ? l10n.rouletteFilterRating
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
                  child: Text('$rating+'),
                ),
            ],
          ),
          FilterDropdownChip(
            selectedLabel: state.priceRange == null
                ? l10n.rouletteFilterPrice
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
                  child: Text(priceRangeLabel(l10n, price)),
                ),
            ],
          ),
          // How many places a spin could land on — the number that explains why
          // a filter combination is turning up nothing.
          if (!state.isInitialLoad)
            Chip(
              avatar: const Icon(Icons.casino_outlined, size: 18),
              label: Text(l10n.listResultCount(state.candidates.length)),
            ),
        ],
      ),
    );
  }
}
