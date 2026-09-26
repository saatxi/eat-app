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

/// Grown from 48 so a photo reads as a portrait rather than a clipped thumbnail.
const double _badgeSize = 52;

/// How many skeleton rows fill the initial-load state — enough for a phone.
const int skeletonRowCount = 6;

/// One restaurant in the list: a cuisine badge, its details, a compact rating
/// and price column, a favourite heart, and the swipe gestures that toggle the
/// favourite or ask to delete.
///
/// Ported from `ui/list/RestaurantRow.kt`. The row never deletes anything
/// itself: a left swipe calls [onDeleteRequest] and the screen decides whether
/// and how to confirm before anything is removed, so the row does not have to
/// know whether the request was granted.
class RestaurantRow extends StatelessWidget {
  const RestaurantRow({
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

    // The badge, name, rating and price are separate nodes a screen reader would
    // otherwise announce one fragment at a time; the semantics node below
    // collapses the whole card into this one description instead.
    final String description = <String>[
      restaurant.name,
      cuisine,
      ratingDescription,
      ?priceDescription,
      ?restaurant.formattedAddress,
      // Only worth announcing for the exception case; "visited" is the default
      // and every row already implies it by omission.
      if (!restaurant.visited) visitStatus,
    ].join(', ');

    return Dismissible(
      key: ValueKey<String>('restaurant-row-${restaurant.id}'),
      direction: DismissDirection.horizontal,
      background: _SwipeHint(
        alignment: Alignment.centerLeft,
        containerColor: scheme.primaryContainer,
        contentColor: scheme.onPrimaryContainer,
        // The heart reflects what the swipe would actually do: offer to add when
        // it is not a favourite yet, remove when it already is.
        icon: restaurant.isFavorite ? Icons.favorite_border : Icons.favorite,
      ),
      secondaryBackground: _SwipeHint(
        alignment: Alignment.centerRight,
        containerColor: scheme.errorContainer,
        contentColor: scheme.onErrorContainer,
        icon: Icons.delete,
      ),
      // Never let the swipe itself carry the row away: favouriting removes
      // nothing, and a delete only happens once the confirmation the request
      // below triggers is accepted — so the row springs back either way.
      confirmDismiss: (DismissDirection direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          onFavoriteToggle(restaurant.id);
        } else {
          onDeleteRequest();
        }
        return false;
      },
      child: Stack(
        children: <Widget>[
          Semantics(
            label: description,
            button: true,
            onTap: onTap,
            child: ExcludeSemantics(
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  // Extra end padding reserves room for the heart overlaid in
                  // the Stack below, so it does not sit on the rating column.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      44,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        RestaurantThumbnail(
                          cuisineKey: restaurant.cuisineKey,
                          photoPath: restaurant.photoPath,
                          size: _badgeSize,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _Details(
                            restaurant: restaurant,
                            cuisine: cuisine,
                            visitStatus: visitStatus,
                          ),
                        ),
                        RatingAndPriceRow(
                          rating: restaurant.rating,
                          priceLabel: priceLabel,
                          starCount: 1,
                          starSize: 16,
                          stacked: true,
                          priceContainerColor: scheme.primaryContainer,
                          priceContentColor: scheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onFavoriteToggle(restaurant.id);
              },
              tooltip: restaurant.isFavorite
                  ? l10n.actionRemoveFavorite
                  : l10n.actionAddFavorite,
              icon: Icon(
                restaurant.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is revealed behind a row as it is dragged: a favourite hint on the side
/// swiped from, a delete hint on the other. Nothing draws once the row has
/// sprung back, so a row that was only tapped shows no flash of colour.
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
        borderRadius: AppRadius.mediumAll,
      ),
      // Decorative: a hint drawn behind a row mid-drag, not a target of its own.
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? address = restaurant.formattedAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(restaurant.name, style: theme.textTheme.titleLarge),
        if (!restaurant.visited)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _StatusPill(text: visitStatus),
          ),
        Text(
          cuisine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (address != null)
          Row(
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
        if (restaurant.tagsLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: TagPillRow(tags: restaurant.tags, maxVisible: 3),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

/// Stands in for [RestaurantRow] while the first load is still pending: the same
/// badge-plus-two-lines-plus-trailing-column shape, pulsing instead of drawing
/// real content, so the list reads as loading rather than empty.
class RestaurantRowSkeleton extends StatelessWidget {
  const RestaurantRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            ShimmerBox(width: 48, height: 48, borderRadius: AppRadius.pill),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.55,
                    child: ShimmerBox(height: 18),
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
            SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                ShimmerBox(width: 44, height: 14),
                SizedBox(height: AppSpacing.sm),
                ShimmerBox(width: 28, height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
