import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/price_range_label.dart';
import '../../core/widgets/rating_and_price_row.dart';
import '../../core/widgets/restaurant_thumbnail.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../core/widgets/tag_pill_row.dart';
import 'restaurant_ui_model.dart';

/// The thumbnail's edge, in logical pixels.
const double _thumbSize = 64;

/// How many skeleton cards fill the initial-load state — enough for a phone.
const int skeletonRowCount = 6;

/// One restaurant in the journal: a soft card carrying its photo or cuisine
/// badge, its name and details, a heart, and a compact rating-and-price line.
///
/// Grown from the flat row it replaces: the card owns its own surface and
/// rounding, the photo is a rounded square rather than a ringed circle, and the
/// rating and price share one line instead of a stacked column. The swipe
/// gestures are kept — a right swipe toggles the favourite, a left swipe asks
/// to delete — but the card never removes itself: a left swipe only calls
/// [onDeleteRequest] and the screen decides whether and how to confirm.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    required this.onFavoriteToggle,
    required this.onDeleteRequest,
  });

  final RestaurantUiModel restaurant;
  final VoidCallback? onTap;
  final ValueChanged<String> onFavoriteToggle;
  final VoidCallback onDeleteRequest;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final String cuisine = cuisineLabel(l10n, restaurant.cuisineKey);
    final String priceLabel = priceRangeLabel(l10n, restaurant.priceRange);
    final String ratingDescription =
        l10n.restaurantRatingDescription(restaurant.rating);
    final String? priceDescription = priceLabel.isEmpty
        ? null
        : l10n.restaurantPriceDescription(priceLabel);
    final String visitStatus =
        restaurant.visited ? l10n.visitStatusVisited : l10n.visitStatusWantToTry;

    // The badge, name, rating and price are separate nodes a screen reader
    // would otherwise announce one fragment at a time; the semantics node below
    // collapses the whole card into this one description instead.
    final String description = <String>[
      restaurant.name,
      cuisine,
      ratingDescription,
      ?priceDescription,
      ?restaurant.formattedAddress,
      // Only worth announcing for the exception case; "visited" is the default
      // and every card already implies it by omission.
      if (!restaurant.visited) visitStatus,
    ].join(', ');

    return Dismissible(
      key: ValueKey<String>('restaurant-card-${restaurant.id}'),
      direction: DismissDirection.horizontal,
      background: _SwipeHint(
        alignment: Alignment.centerLeft,
        containerColor: scheme.primaryContainer,
        contentColor: scheme.onPrimaryContainer,
        // The heart reflects what the swipe would actually do: offer to add
        // when it is not a favourite yet, remove when it already is.
        icon: restaurant.isFavorite ? Icons.favorite_border : Icons.favorite,
      ),
      secondaryBackground: _SwipeHint(
        alignment: Alignment.centerRight,
        containerColor: scheme.errorContainer,
        contentColor: scheme.onErrorContainer,
        icon: Icons.delete_outline,
      ),
      // Never let the swipe itself carry the card away: favouriting removes
      // nothing, and a delete only happens once the confirmation the request
      // triggers is accepted — so the card springs back either way. The two
      // gestures get different feedback: favouriting is a selection, deleting is
      // heavier and deliberate.
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.selectionClick();
          onFavoriteToggle(restaurant.id);
        } else {
          HapticFeedback.heavyImpact();
          onDeleteRequest();
        }
        return false;
      },
      child: Semantics(
        label: description,
        button: true,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Card(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Paired with the detail screen's header by
                    // [restaurantHeroTag], so tapping a card flies the image
                    // across rather than swapping screens outright.
                    Hero(
                      tag: restaurantHeroTag(restaurant.id),
                      child: RestaurantThumbnail(
                        cuisineKey: restaurant.cuisineKey,
                        photoPath: restaurant.photoPath,
                        size: _thumbSize,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _Details(
                        restaurant: restaurant,
                        cuisine: cuisine,
                        visitStatus: visitStatus,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onFavoriteToggle(restaurant.id);
                      },
                      tooltip: restaurant.isFavorite
                          ? l10n.actionRemoveFavorite
                          : l10n.actionAddFavorite,
                      icon: Icon(
                        restaurant.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What is revealed behind a card as it is dragged: a favourite hint on the
/// side swiped from, a delete hint on the other.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.alignment,
    required this.containerColor,
    required this.contentColor,
    required this.icon,
  });

  final Alignment alignment;
  final Color containerColor;
  final Color contentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: AppRadius.largeAll,
      ),
      // Decorative: a hint drawn behind a card mid-drag, not a target of its own.
      child: Icon(icon, color: contentColor),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.restaurant,
    required this.cuisine,
    required this.visitStatus,
  });

  final RestaurantUiModel restaurant;
  final String cuisine;
  final String visitStatus;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? address = restaurant.formattedAddress;
    final String priceLabel = priceRangeLabel(l10n, restaurant.priceRange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          restaurant.name,
          style: theme.textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!restaurant.visited)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: _StatusPill(text: visitStatus),
          ),
        Text(
          cuisine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (address != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (restaurant.tagsLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TagPillRow(tags: restaurant.tags, maxVisible: 3),
          ),
        const SizedBox(height: AppSpacing.sm),
        RatingAndPriceRow(
          rating: restaurant.rating,
          priceLabel: priceLabel,
          starCount: 1,
          starSize: 16,
          priceContainerColor: scheme.primaryContainer,
          priceContentColor: scheme.onPrimaryContainer,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: AppRadius.pill,
        ),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// Stands in for [RestaurantCard] while the first load is still pending: the
/// same thumbnail-plus-lines shape, pulsing instead of drawing real content, so
/// the journal reads as loading rather than empty.
class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ShimmerBox(width: _thumbSize, height: _thumbSize, borderRadius: AppRadius.mediumAll),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.55,
                    child: ShimmerBox(height: 20),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.35,
                    child: ShimmerBox(height: 14),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.7,
                    child: ShimmerBox(height: 14),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            ShimmerBox(width: 28, height: 28, borderRadius: AppRadius.pill),
          ],
        ),
      ),
    );
  }
}
