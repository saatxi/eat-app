import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/tokens/app_radius.dart';
import 'presentation_bounds.dart';

/// The stars-plus-"N/5"-plus-price-pill markup shared by the list row, the
/// detail screen and the roulette result card — pulled out once so a future
/// tweak to the star tint logic or the price pill's styling cannot silently
/// drift between the three.
///
/// The three call sites do not draw quite the same *layout*: the list row
/// stacks a compact single-star line above the price pill to stay narrow, while
/// the detail and roulette screens lay a full five-star gauge and the pill side
/// by side — so [stacked] switches between those two shapes rather than forcing
/// one look on all three.
///
/// A [starCount] of 1 is what produces the list row's "decorative accent star"
/// look: with only one star, `index < rating` is not a meaningful gauge, so it
/// always renders filled.
///
/// Ported from `ui/common/RatingAndPriceRow.kt`.
class RatingAndPriceRow extends StatelessWidget {
  const RatingAndPriceRow({
    super.key,
    required this.rating,
    required this.priceLabel,
    this.starCount = maxRating,
    this.starSize = 18,
    this.showRatingLabel = true,
    this.stacked = false,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.pricePadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    this.ratingContentDescription,
    this.priceContentDescription,
    this.priceContainerColor,
    this.priceContentColor,
  });

  /// 0-5; 0 means unrated.
  final int rating;

  /// Empty draws no pill at all, rather than an empty one.
  final String priceLabel;

  final int starCount;
  final double starSize;
  final bool showRatingLabel;
  final bool stacked;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsets pricePadding;

  /// Only non-null on the detail screen, which is not nested inside an element
  /// that already collapses its semantics.
  final String? ratingContentDescription;
  final String? priceContentDescription;

  /// Defaults preserve the tertiary pill everywhere except list/detail, which
  /// pass the primary container explicitly so the price chip reads as one
  /// consistent accent instead of competing with the cuisine tint.
  final Color? priceContainerColor;
  final Color? priceContentColor;

  @override
  Widget build(BuildContext context) {
    final Widget stars = _Stars(
      rating: rating,
      starCount: starCount,
      starSize: starSize,
      showRatingLabel: showRatingLabel,
      contentDescription: ratingContentDescription,
    );
    final Widget price = priceLabel.isEmpty
        ? const SizedBox.shrink()
        : _PricePill(
            label: priceLabel,
            padding: pricePadding,
            containerColor: priceContainerColor,
            contentColor: priceContentColor,
            contentDescription: priceContentDescription,
          );

    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          stars,
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: price,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[stars, price],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({
    required this.rating,
    required this.starCount,
    required this.starSize,
    required this.showRatingLabel,
    required this.contentDescription,
  });

  final int rating;
  final int starCount;
  final double starSize;
  final bool showRatingLabel;
  final String? contentDescription;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < starCount; index++)
          Icon(
            Icons.star,
            size: starSize,
            // A single star is a decorative accent next to the number, not a
            // gauge — it is always filled, regardless of the actual rating.
            color: starCount == 1 || index < rating
                ? scheme.primary
                : scheme.outlineVariant,
          ),
        if (showRatingLabel)
          Padding(
            padding: EdgeInsets.only(left: starCount == 1 ? 4 : 6),
            child: Text(
              AppLocalizations.of(context).ratingFormat(rating),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: starCount == 1 ? scheme.primary : null,
              ),
            ),
          ),
      ],
    );
    if (contentDescription == null) {
      return row;
    }
    return Semantics(label: contentDescription, child: ExcludeSemantics(child: row));
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({
    required this.label,
    required this.padding,
    required this.containerColor,
    required this.contentColor,
    required this.contentDescription,
  });

  final String label;
  final EdgeInsets padding;
  final Color? containerColor;
  final Color? contentColor;
  final String? contentDescription;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: containerColor ?? scheme.tertiaryContainer,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: contentColor ?? scheme.onTertiaryContainer,
        ),
      ),
    );
    if (contentDescription == null) {
      return pill;
    }
    return Semantics(label: contentDescription, child: ExcludeSemantics(child: pill));
  }
}
