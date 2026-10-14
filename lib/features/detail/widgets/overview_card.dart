import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/cuisine_visuals.dart';
import '../../../core/widgets/rating_and_price_row.dart';
import '../../../core/widgets/section_label.dart';
import '../../list/restaurant_ui_model.dart';
import 'detail_info_row.dart';

/// The restaurant's overview and its rating/price, folded into one soft card so
/// the detail screen reads as a stack of cards rather than a flat column.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.restaurant,
    required this.priceLabel,
    required this.address,
    required this.onOpen,
  });

  final RestaurantUiModel restaurant;
  final String priceLabel;
  final String? address;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionLabel(l10n.detailSectionOverview),
            DetailInfoRow(
              icon: cuisineIcon(restaurant.cuisineKey),
              text: cuisineLabel(l10n, restaurant.cuisineKey),
              textStyle: theme.textTheme.titleMedium,
            ),
            if (!restaurant.visited)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: DetailInfoRow(
                  icon: Icons.schedule_outlined,
                  text: l10n.visitStatusWantToTry,
                ),
              ),
            if (address != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: DetailInfoRow(
                  icon: Icons.location_on_outlined,
                  text: address!,
                  onTap: () =>
                      onOpen('geo:0,0?q=${Uri.encodeComponent(address!)}'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(color: theme.colorScheme.outlineVariant),
            ),
            SectionLabel(l10n.detailSectionRating),
            RatingAndPriceRow(
              rating: restaurant.rating,
              priceLabel: priceLabel,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              pricePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              ratingContentDescription: l10n.restaurantRatingDescription(
                restaurant.rating,
              ),
              priceContentDescription: priceLabel.isEmpty
                  ? null
                  : l10n.restaurantPriceDescription(priceLabel),
              priceContainerColor: theme.colorScheme.primaryContainer,
              priceContentColor: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
