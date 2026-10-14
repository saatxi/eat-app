import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/theme/tokens/cuisine_accents.dart';
import '../../../core/widgets/cuisine_visuals.dart';
import '../../../core/widgets/photo_decode_size.dart';
import '../../../core/widgets/price_range_label.dart';
import '../../../core/widgets/rating_and_price_row.dart';
import '../../../core/widgets/section_label.dart';
import '../detail_state.dart';

class VisitsSection extends StatelessWidget {
  const VisitsSection({
    super.key,
    required this.visits,
    required this.cuisineKey,
    this.onAddVisit,
    this.onEditVisit,
  });

  final List<VisitUiModel> visits;
  final String cuisineKey;

  /// Null leaves the action out of the header.
  final VoidCallback? onAddVisit;

  /// Null leaves the cards untappable.
  final ValueChanged<String>? onEditVisit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The action lives in its own section's header rather than in a FAB:
        // a FAB floats over a scrolling list and hides the very cards it is
        // about, which these are.
        Row(
          children: <Widget>[
            SectionLabel(l10n.detailSectionVisits),
            const Spacer(),
            if (onAddVisit != null)
              TextButton.icon(
                onPressed: onAddVisit,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.detailActionLogVisit),
              ),
          ],
        ),
        if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.schedule_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.detailVisitsEmptyTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.detailVisitsEmptyBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final VisitUiModel visit in visits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: VisitCard(
                    visit: visit,
                    cuisineKey: cuisineKey,
                    onEdit: onEditVisit == null
                        ? null
                        : () => onEditVisit!(visit.id),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// One past visit. Tapping it reopens the visit form on that visit, which is
/// the only way back into a visit once it is logged — hence the whole card is
/// the target rather than a small icon tucked into its corner.
class VisitCard extends StatelessWidget {
  const VisitCard({
    super.key,
    required this.visit,
    required this.cuisineKey,
    this.onEdit,
  });

  final VisitUiModel visit;
  final String cuisineKey;

  /// Null leaves the card inert, the case in a bare widget test.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CuisineTint tint = cuisineTint(context, cuisineKey);
    final String date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(DateTime.fromMillisecondsSinceEpoch(visit.visitDate));
    final String? notes = visit.notes;

    return Material(
      color: tint.container,
      borderRadius: AppRadius.mediumAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Semantics(
          button: onEdit != null,
          hint: onEdit == null ? null : l10n.visitCardEditHint,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      date,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: tint.onContainer,
                      ),
                    ),
                    RatingAndPriceRow(
                      rating: visit.rating,
                      priceLabel: priceRangeLabel(l10n, visit.priceRange),
                      showRatingLabel: false,
                      starSize: 16,
                    ),
                  ],
                ),
                if (notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tint.onContainer,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (visit.photoPaths.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: visit.photoPaths.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int index) => ClipRRect(
                          borderRadius: AppRadius.smallAll,
                          child: Image.file(
                            File(visit.photoPaths[index]),
                            width: 64,
                            height: 64,
                            cacheWidth: thumbnailCacheWidth(context, 64),
                            fit: BoxFit.cover,
                            semanticLabel: l10n.visitCardPhotoDescription,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
