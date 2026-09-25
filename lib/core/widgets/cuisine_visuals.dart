import 'package:flutter/material.dart';

import '../../data/models/cuisine.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens/cuisine_accents.dart';

/// The icon, label and tint a cuisine badge is drawn with.
///
/// Restaurants carry no photo of their own yet, so the list and detail screens
/// draw a cuisine-derived badge in its place. All three lookups take the raw
/// `cuisineType` value straight off the entity and degrade gracefully when it
/// is not a key this build knows: a generic icon, a neutral tint and the raw
/// string as the label — so a newer data file never breaks an older app.
///
/// Ported from the Android app's `ui/common/CuisineVisuals.kt`.
IconData cuisineIcon(String cuisineType) =>
    switch (Cuisine.fromKey(cuisineType)) {
      Cuisine.mediterranean => Icons.restaurant,
      Cuisine.spanish => Icons.tapas,
      Cuisine.catalan => Icons.restaurant_menu,
      Cuisine.basque => Icons.room_service,
      Cuisine.italian => Icons.local_pizza,
      Cuisine.japanese => Icons.ramen_dining,
      Cuisine.chinese => Icons.rice_bowl,
      Cuisine.asian => Icons.takeout_dining,
      Cuisine.indian => Icons.soup_kitchen,
      Cuisine.middleEastern => Icons.kebab_dining,
      Cuisine.american => Icons.lunch_dining,
      Cuisine.seafood => Icons.set_meal,
      Cuisine.bar => Icons.local_bar,
      Cuisine.beerBar => Icons.sports_bar,
      Cuisine.wineBar => Icons.wine_bar,
      Cuisine.cafe => Icons.local_cafe,
      Cuisine.bakery => Icons.bakery_dining,
      Cuisine.dessert => Icons.icecream,
      Cuisine.breakfast => Icons.breakfast_dining,
      Cuisine.brunch => Icons.brunch_dining,
      Cuisine.grill => Icons.outdoor_grill,
      Cuisine.fastFood => Icons.fastfood,
      Cuisine.fineDining => Icons.dinner_dining,
      Cuisine.vegetarian => Icons.grass,
      null => Icons.restaurant,
    };

/// The translated label for a cuisine, or the raw stored value when the key is
/// unknown.
String cuisineLabel(AppLocalizations l10n, String cuisineType) {
  final Cuisine? cuisine = Cuisine.fromKey(cuisineType);
  return cuisine == null ? cuisineType : cuisine.label(l10n);
}

/// The accent pair for a cuisine badge.
///
/// Keyed off the enum's index rather than the string's hash: stable across
/// releases, and spread evenly over the palette's accents instead of landing
/// arbitrarily. An unknown key stays neutral so it reads as "no category"
/// rather than borrowing a colour that means something else.
CuisineTint cuisineTint(BuildContext context, String cuisineType) {
  final Cuisine? cuisine = Cuisine.fromKey(cuisineType);
  if (cuisine == null) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return CuisineTint(
      container: scheme.surfaceContainerHighest,
      onContainer: scheme.onSurfaceVariant,
    );
  }
  return CuisineAccents.of(context)[cuisine.index];
}
