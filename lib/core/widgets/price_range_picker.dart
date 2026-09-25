import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/tokens/app_spacing.dart';
import 'presentation_bounds.dart';
import 'price_range_label.dart';

/// Six tappable euro-band tiles, single-select: tapping the already-selected
/// tile clears it back to 0 ("not set").
///
/// Shared by the restaurant form and the log-visit form, both on the same 0-6
/// scale. Ported from `ui/common/PriceRangePicker.kt`.
class PriceRangePicker extends StatelessWidget {
  const PriceRangePicker({
    super.key,
    required this.priceRange,
    required this.onChanged,
  });

  final int priceRange;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (int level = 1; level <= maxPriceRange; level++)
          _PriceTile(
            label: priceRangeLabel(l10n, level),
            selected: level == priceRange,
            // Tapping the tile that is already on clears the band.
            onTap: () => onChanged(level == priceRange ? 0 : level),
            theme: theme,
          ),
      ],
    );
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
