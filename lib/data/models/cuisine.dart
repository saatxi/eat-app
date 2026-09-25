import '../../core/l10n/generated/app_localizations.dart';

/// The closed vocabulary of cuisine types the app understands.
///
/// The `restaurants.cuisineType` column stores [key] — a stable,
/// language-independent identifier — never a display label. Only [label] is
/// ever translated, so adding a language means adding an ARB file and nothing
/// else.
///
/// The vocabulary is documented in the README. Keep the two in sync.
enum Cuisine {
  // Origin
  mediterranean('mediterranean'),
  spanish('spanish'),
  catalan('catalan'),
  basque('basque'),
  italian('italian'),
  japanese('japanese'),
  chinese('chinese'),
  asian('asian'),
  indian('indian'),
  middleEastern('middle_eastern'),
  american('american'),
  seafood('seafood'),

  // Venue / meal type
  bar('bar'),
  beerBar('beer_bar'),
  wineBar('wine_bar'),
  cafe('cafe'),
  bakery('bakery'),
  dessert('dessert'),
  breakfast('breakfast'),
  brunch('brunch'),
  grill('grill'),
  fastFood('fast_food'),
  fineDining('fine_dining'),
  vegetarian('vegetarian');

  const Cuisine(this.key);

  /// Stable, language-independent identifier stored in the database.
  final String key;

  /// The translated display label for this cuisine.
  String label(AppLocalizations l10n) => switch (this) {
    Cuisine.mediterranean => l10n.cuisineMediterranean,
    Cuisine.spanish => l10n.cuisineSpanish,
    Cuisine.catalan => l10n.cuisineCatalan,
    Cuisine.basque => l10n.cuisineBasque,
    Cuisine.italian => l10n.cuisineItalian,
    Cuisine.japanese => l10n.cuisineJapanese,
    Cuisine.chinese => l10n.cuisineChinese,
    Cuisine.asian => l10n.cuisineAsian,
    Cuisine.indian => l10n.cuisineIndian,
    Cuisine.middleEastern => l10n.cuisineMiddleEastern,
    Cuisine.american => l10n.cuisineAmerican,
    Cuisine.seafood => l10n.cuisineSeafood,
    Cuisine.bar => l10n.cuisineBar,
    Cuisine.beerBar => l10n.cuisineBeerBar,
    Cuisine.wineBar => l10n.cuisineWineBar,
    Cuisine.cafe => l10n.cuisineCafe,
    Cuisine.bakery => l10n.cuisineBakery,
    Cuisine.dessert => l10n.cuisineDessert,
    Cuisine.breakfast => l10n.cuisineBreakfast,
    Cuisine.brunch => l10n.cuisineBrunch,
    Cuisine.grill => l10n.cuisineGrill,
    Cuisine.fastFood => l10n.cuisineFastFood,
    Cuisine.fineDining => l10n.cuisineFineDining,
    Cuisine.vegetarian => l10n.cuisineVegetarian,
  };

  /// Resolves a raw `cuisineType` value, or null when the data uses a key this
  /// build doesn't know. Callers must degrade gracefully rather than fail: an
  /// unrecognised key still shows the raw string and a generic icon, so a
  /// newer data file never breaks an older app.
  static Cuisine? fromKey(String? key) => switch (key?.trim().toLowerCase()) {
    'mediterranean' => Cuisine.mediterranean,
    'spanish' => Cuisine.spanish,
    'catalan' => Cuisine.catalan,
    'basque' => Cuisine.basque,
    'italian' => Cuisine.italian,
    'japanese' => Cuisine.japanese,
    'chinese' => Cuisine.chinese,
    'asian' => Cuisine.asian,
    'indian' => Cuisine.indian,
    'middle_eastern' => Cuisine.middleEastern,
    'american' => Cuisine.american,
    'seafood' => Cuisine.seafood,
    'bar' => Cuisine.bar,
    'beer_bar' => Cuisine.beerBar,
    'wine_bar' => Cuisine.wineBar,
    'cafe' => Cuisine.cafe,
    'bakery' => Cuisine.bakery,
    'dessert' => Cuisine.dessert,
    'breakfast' => Cuisine.breakfast,
    'brunch' => Cuisine.brunch,
    'grill' => Cuisine.grill,
    'fast_food' => Cuisine.fastFood,
    'fine_dining' => Cuisine.fineDining,
    'vegetarian' => Cuisine.vegetarian,
    _ => null,
  };
}
