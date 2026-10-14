import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../list/restaurant_ui_model.dart';
import 'detail_info_row.dart';

class LinksCard extends StatelessWidget {
  const LinksCard({super.key, required this.restaurant, required this.onOpen});

  final RestaurantUiModel restaurant;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? website = restaurant.website;
    final String? instagram = restaurant.instagram;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.detailSectionLinks,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (website != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DetailInfoRow(
                  icon: Icons.language,
                  text: website,
                  onTap: () => onOpen(website),
                ),
              ),
            if (instagram != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DetailInfoRow(
                  icon: Icons.alternate_email,
                  text: l10n.detailLinkHandleFormat(instagram),
                  onTap: () => onOpen('https://instagram.com/$instagram'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
