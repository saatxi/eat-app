import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/theme/tokens/cuisine_accents.dart';
import '../../../core/widgets/cuisine_visuals.dart';
import '../../list/restaurant_ui_model.dart';

/// A 240-px tall rounded header shown when a restaurant has no photo yet.
///
/// Uses the cuisine's accent pair — container as the background gradient base,
/// the on-container colour for the icon and the name — so it reads as part of
/// the same visual vocabulary as the cuisine badge in the list card.
class CuisineHeader extends StatelessWidget {
  const CuisineHeader({super.key, required this.restaurant});

  final RestaurantUiModel restaurant;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CuisineTint tint = cuisineTint(context, restaurant.cuisineKey);
    final Color bg = tint.container;
    final Color fg = tint.onContainer;
    // Top is the raw container colour; bottom is mixed 30% toward black for a
    // clear depth gradient, and the name text sits at the bottom where contrast
    // is highest.
    final Color bgDeep = Color.lerp(bg, Colors.black, 0.30) ?? bg;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.largeAll,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.largeAll,
        child: SizedBox(
          width: double.infinity,
          height: 240,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Gradient: solid at the top, slightly deeper at the bottom.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[bg, bgDeep],
                  ),
                ),
              ),
              // Large decorative icon — translucent, offset to the right.
              Positioned(
                right: -16,
                top: -8,
                child: ExcludeSemantics(
                  child: Icon(
                    cuisineIcon(restaurant.cuisineKey),
                    size: 180,
                    color: fg.withAlpha(40),
                  ),
                ),
              ),
              // Restaurant name anchored to the bottom-left.
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Text(
                  restaurant.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
