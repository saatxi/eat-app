import '../l10n/generated/app_localizations.dart';

/// Euro-band display text for a price level (1-[maxPriceRange]), empty for 0
/// ("not set") or anything else out of range.
///
/// Shared by every screen that draws a restaurant's or a visit's `priceRange`,
/// so the band boundaries live in exactly one place — the ARB's `priceRange1`
/// through `priceRange6`. Ported from `ui/common/PriceRangePicker.kt`.
String priceRangeLabel(AppLocalizations l10n, int priceRange) =>
    switch (priceRange) {
      1 => l10n.priceRange1,
      2 => l10n.priceRange2,
      3 => l10n.priceRange3,
      4 => l10n.priceRange4,
      5 => l10n.priceRange5,
      6 => l10n.priceRange6,
      _ => '',
    };
