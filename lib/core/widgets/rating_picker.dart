import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'presentation_bounds.dart';

/// A row of tappable stars, 0-[maxRating]: tapping a star sets that rating, and
/// tapping the star that is already on clears it back to 0 ("not rated").
///
/// Shared by the log-visit form and the roulette filter. Ported from the
/// Android app's `RatingPicker`.
class RatingPicker extends StatelessWidget {
  const RatingPicker({
    super.key,
    required this.rating,
    required this.onChanged,
    this.starSize = 40,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int star = 1; star <= maxRating; star++)
          Semantics(
            button: true,
            label: l10n.restaurantRatingDescription(star),
            child: InkWell(
              onTap: () => onChanged(star == rating ? 0 : star),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  star <= rating ? Icons.star : Icons.star_border,
                  size: starSize,
                  color: star <= rating
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
