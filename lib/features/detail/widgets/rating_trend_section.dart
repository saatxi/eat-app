import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/theme/tokens/cuisine_accents.dart';
import '../../../core/widgets/cuisine_visuals.dart';
import '../../../core/widgets/rating_trend_chart.dart';
import '../../../core/widgets/section_label.dart';
import '../detail_state.dart';

class RatingTrendSection extends StatelessWidget {
  const RatingTrendSection({
    super.key,
    required this.points,
    required this.cuisineKey,
  });

  final List<RatingPoint> points;
  final String cuisineKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CuisineTint tint = cuisineTint(context, cuisineKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionLabel(l10n.detailSectionRatingTrend),
        Container(
          height: 100,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tint.container,
            borderRadius: AppRadius.mediumAll,
          ),
          child: RatingTrendChart(
            values: <double>[for (final RatingPoint p in points) p.rating.toDouble()],
            lineColor: tint.onContainer,
          ),
        ),
      ],
    );
  }
}
