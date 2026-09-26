// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'EatApp';

  @override
  String get listTitle => 'My Restaurants';

  @override
  String get listSearchPlaceholder => 'Search restaurants';

  @override
  String get listSearchClear => 'Clear search';

  @override
  String get listSuggestionsTitle => 'Try one of these';

  @override
  String get listSuggestionTopRated => 'Top rated';

  @override
  String get listFilterMinRating => 'Rating';

  @override
  String get listFilterPrice => 'Price';

  @override
  String get listFilterCuisine => 'Cuisine';

  @override
  String get listFilterVisitStatus => 'Status';

  @override
  String get listFilterLocation => 'Location';

  @override
  String get listFilterCity => 'City';

  @override
  String get listFilterRegion => 'Region';

  @override
  String get listFilterCountry => 'Country';

  @override
  String get listFilterAll => 'All';

  @override
  String listFilterLocationActive(int count) {
    return 'Location · $count';
  }

  @override
  String get listEmptyTitle => 'No restaurants yet';

  @override
  String get listEmptyBody => 'Add your first restaurant to get started.';

  @override
  String get listEmptyNoResultsTitle => 'No matches';

  @override
  String get listEmptyNoResultsBody => 'Try a different search or filter.';

  @override
  String get listActionAddRestaurant => 'Add restaurant';

  @override
  String get listActionShareAll => 'Share all restaurants';

  @override
  String get listActionClearFilters => 'Clear filters';

  @override
  String get listSortName => 'Name (A-Z)';

  @override
  String get listSortRating => 'Rating (highest first)';

  @override
  String get listSortNameShort => 'Name';

  @override
  String get listSortRatingShort => 'Rating';

  @override
  String get listFiltersTitle => 'Filters';

  @override
  String get listFiltersExpand => 'Expand filters';

  @override
  String get listFiltersCollapse => 'Collapse filters';

  @override
  String listFiltersActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active filters',
      one: '$count active filter',
    );
    return '$_temp0';
  }

  @override
  String listResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurants',
      one: '$count restaurant',
    );
    return '$_temp0';
  }

  @override
  String get actionBack => 'Back';

  @override
  String get actionGoBack => 'Go back';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionExport => 'Export';

  @override
  String get actionDone => 'Done';

  @override
  String get actionOk => 'OK';

  @override
  String get detailNotFoundTitle => 'Restaurant not found';

  @override
  String get detailNotFoundBody => 'This restaurant was removed.';

  @override
  String get detailSelectTitle => 'Nothing selected';

  @override
  String get detailSelectBody =>
      'Pick a restaurant from the list to see its details here.';

  @override
  String get detailActionEdit => 'Edit';

  @override
  String get detailActionShare => 'Share';

  @override
  String get detailActionDelete => 'Delete';

  @override
  String get detailActionMore => 'More options';

  @override
  String get detailDeleteConfirmTitle => 'Delete this restaurant?';

  @override
  String get detailDeleteConfirmBody => 'This can\'t be undone.';

  @override
  String get detailPlaceholderTitle => 'Select a restaurant';

  @override
  String get detailPlaceholderBody =>
      'Choose one from the list to see its details here.';

  @override
  String aboutVersionTemplate(String version, int build, String revision) {
    return 'Version $version (build $build, $revision)';
  }

  @override
  String aboutVersionTemplateClean(String version) {
    return 'Version $version';
  }

  @override
  String ratingFormat(int rating) {
    return '$rating/5';
  }

  @override
  String get visitStatusVisited => 'Visited';

  @override
  String get visitStatusWantToTry => 'Want to try';

  @override
  String restaurantRatingDescription(int rating) {
    return 'Rated $rating of 5';
  }

  @override
  String restaurantPriceDescription(String price) {
    return 'Price range: $price';
  }

  @override
  String get priceRange1 => '1-10 €';

  @override
  String get priceRange2 => '10-20 €';

  @override
  String get priceRange3 => '20-30 €';

  @override
  String get priceRange4 => '30-40 €';

  @override
  String get priceRange5 => '40-50 €';

  @override
  String get priceRange6 => '50 € or more';

  @override
  String get navRestaurants => 'Restaurants';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navRoulette => 'Roulette';

  @override
  String get navSettings => 'Settings';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptyBody =>
      'Tap the heart on a restaurant to keep it here.';

  @override
  String get actionAddFavorite => 'Add to favorites';

  @override
  String get actionRemoveFavorite => 'Remove from favorites';

  @override
  String get rouletteTitle => 'What to eat';

  @override
  String get roulettePrompt => 'Can\'t decide? Let the app pick.';

  @override
  String get rouletteActionPick => 'Pick one';

  @override
  String get rouletteActionAgain => 'Try again';

  @override
  String get rouletteOnlyFavorites => 'Favorites only';

  @override
  String get rouletteFilterRating => 'Rating';

  @override
  String get rouletteFilterStatus => 'Status';

  @override
  String get rouletteFilterPrice => 'Price';

  @override
  String get rouletteEmptyTitle => 'Nothing to pick from';

  @override
  String get rouletteEmptyBody => 'No restaurant matches these filters.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get settingsActionViewStatistics => 'View statistics';

  @override
  String get settingsActionExportData => 'Export my data';

  @override
  String get exportDialogTitle => 'Export restaurants';

  @override
  String get exportDialogBody => 'Choose what to include in the exported file.';

  @override
  String get exportDialogIncludeVisits => 'Include visits';

  @override
  String get shareFailed => 'Couldn\'t share the file. Please try again.';

  @override
  String get settingsActionDeleteAllData => 'Delete all restaurants';

  @override
  String get settingsDeleteAllConfirmTitle => 'Delete all restaurants?';

  @override
  String get settingsDeleteAllConfirmBody =>
      'This deletes every restaurant in the app. This can\'t be undone.';

  @override
  String get settingsActionHelp => 'How to use EatApp';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageCatalan => 'Catalan';

  @override
  String get helpTitle => 'How to use EatApp';

  @override
  String get helpIntro =>
      'A quick guide to everything EatApp can do — tap a topic to open it.';

  @override
  String get helpTopicAddTitle => 'Adding a restaurant';

  @override
  String get helpTopicAddBody =>
      'Tap the + button on the list screen. Fill in the name, cuisine and address — everything else is optional. It\'s saved straight to your device, no account needed.';

  @override
  String get helpTopicFavoritesTitle => 'Favorites & want-to-try';

  @override
  String get helpTopicFavoritesBody =>
      'Tap the heart on a restaurant to mark it a favorite — a place you love. Tap the bookmark to add it to want-to-try — somewhere you\'re planning to visit. Both show up in their own tab at the bottom.';

  @override
  String get helpTopicRouletteTitle => 'Roulette: can\'t decide?';

  @override
  String get helpTopicRouletteBody =>
      'Open the Roulette tab and spin — it picks a random restaurant from your want-to-try list. Filter by cuisine first if you\'re after something specific.';

  @override
  String get helpTopicSharingTitle => 'Sharing a restaurant';

  @override
  String get helpTopicSharingBody =>
      'Open a restaurant\'s details and tap Share to send it to a friend who also has EatApp. When they open the file, they\'ll get a review screen to check the details before it\'s added to their own list.';

  @override
  String get helpTopicWidgetTitle => 'Home-screen widget';

  @override
  String get helpTopicWidgetBody =>
      'Add the \"Want to try\" widget from your home screen\'s widget picker to see a random pick from that list without opening the app.';

  @override
  String get helpTopicExportTitle => 'Exporting your data';

  @override
  String get helpTopicExportBody =>
      'In Settings → Data → Export my data, you can save a copy of everything you\'ve entered as a file, to back it up or move it to another device.';

  @override
  String get editTitleAdd => 'Add restaurant';

  @override
  String get editTitleEdit => 'Edit restaurant';

  @override
  String get editActionSave => 'Save';

  @override
  String get editSectionBasics => 'Basics';

  @override
  String get editSectionLinks => 'Links';

  @override
  String get editSectionTags => 'Tags';

  @override
  String get editActionAddPhoto => 'Add photo';

  @override
  String get editActionRemovePhoto => 'Remove photo';

  @override
  String get editPhotoPreviewDescription => 'Restaurant photo preview';

  @override
  String get editFieldName => 'Name';

  @override
  String get editFieldCuisine => 'Cuisine';

  @override
  String get editCuisinePlaceholder => 'Select a cuisine';

  @override
  String get editFieldAddress => 'Street address (optional)';

  @override
  String get editFieldCity => 'Town / city (optional)';

  @override
  String get editFieldRegion => 'Region (optional)';

  @override
  String get editFieldCountry => 'Country (optional)';

  @override
  String get editFieldPriceRange => 'Price range';

  @override
  String get editFieldWebsite => 'Website (optional)';

  @override
  String get editFieldInstagram => 'Instagram (optional)';

  @override
  String get editFieldTags => 'Add a tag';

  @override
  String editActionRemoveTag(String tag) {
    return 'Remove tag $tag';
  }

  @override
  String get editErrorNameRequired => 'Name is required';

  @override
  String get editErrorCuisineRequired => 'Choose a cuisine';

  @override
  String get editErrorWebsiteInvalid => 'Enter a valid http/https web address';

  @override
  String get editErrorInstagramInvalid => 'Enter a valid Instagram handle';

  @override
  String get importTitle => 'Import restaurants';

  @override
  String get importEmptyTitle => 'Nothing to import';

  @override
  String get importEmptyBody => 'This file doesn\'t contain any restaurants.';

  @override
  String get importErrorTitle => 'Can\'t open this file';

  @override
  String get importErrorTooLarge => 'This file is too large.';

  @override
  String get importErrorInvalid =>
      'This doesn\'t look like an EatApp restaurant file.';

  @override
  String get importErrorIo =>
      'Couldn\'t read this file. If you opened it straight from an email attachment, try downloading it first, then open it from your downloads.';

  @override
  String get importActionConfirm => 'Import';

  @override
  String get importDuplicateLabel => 'Already in your list';

  @override
  String get importDecisionAdd => 'Add';

  @override
  String get importDecisionSkip => 'Skip';

  @override
  String get importDecisionReplace => 'Replace';

  @override
  String importSkippedInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurants had invalid data and were skipped',
      one: '$count restaurant had invalid data and was skipped',
    );
    return '$_temp0';
  }

  @override
  String importDuplicatesHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already in your list',
      one: '$count already in your list',
    );
    return '$_temp0';
  }

  @override
  String get detailSectionOverview => 'Overview';

  @override
  String get detailSectionRating => 'Rating and price';

  @override
  String get detailSectionLinks => 'Links';

  @override
  String get detailPhotoDescription => 'Restaurant photo';

  @override
  String get detailLinkWebsite => 'Website';

  @override
  String get detailLinkInstagram => 'Instagram';

  @override
  String detailLinkHandleFormat(String handle) {
    return '@$handle';
  }

  @override
  String get detailLinkFailed => 'No app can open this link.';

  @override
  String get detailSectionVisits => 'Visits';

  @override
  String get detailSectionRatingTrend => 'Rating over time';

  @override
  String get detailVisitsEmptyTitle => 'Want to try, no visits yet';

  @override
  String get detailVisitsEmptyBody => 'Log a visit once you\'ve been.';

  @override
  String get detailActionLogVisit => 'Log a visit';

  @override
  String get visitCardPhotoDescription => 'Photo from this visit';

  @override
  String get logvisitTitle => 'Log a visit';

  @override
  String get logvisitActionSave => 'Save';

  @override
  String get logvisitFieldDate => 'Date';

  @override
  String get logvisitFieldRating => 'Rating';

  @override
  String get logvisitFieldPrice => 'Price range';

  @override
  String get logvisitFieldNotes => 'Notes (optional)';

  @override
  String get logvisitActionAddPhoto => 'Add photo';

  @override
  String get logvisitActionRemovePhoto => 'Remove photo';

  @override
  String get logvisitPhotoDescription => 'Visit photo';

  @override
  String get logvisitDatePickerConfirm => 'OK';

  @override
  String get logvisitDatePickerCancel => 'Cancel';

  @override
  String get cuisineMediterranean => 'Mediterranean';

  @override
  String get cuisineSpanish => 'Spanish';

  @override
  String get cuisineCatalan => 'Catalan';

  @override
  String get cuisineBasque => 'Basque';

  @override
  String get cuisineItalian => 'Italian';

  @override
  String get cuisineJapanese => 'Japanese';

  @override
  String get cuisineChinese => 'Chinese';

  @override
  String get cuisineAsian => 'Asian';

  @override
  String get cuisineIndian => 'Indian';

  @override
  String get cuisineMiddleEastern => 'Middle Eastern';

  @override
  String get cuisineAmerican => 'American';

  @override
  String get cuisineSeafood => 'Seafood';

  @override
  String get cuisineBar => 'Bar';

  @override
  String get cuisineBeerBar => 'Beer bar';

  @override
  String get cuisineWineBar => 'Wine bar';

  @override
  String get cuisineCafe => 'Cafe';

  @override
  String get cuisineBakery => 'Bakery';

  @override
  String get cuisineDessert => 'Dessert';

  @override
  String get cuisineBreakfast => 'Breakfast';

  @override
  String get cuisineBrunch => 'Brunch';

  @override
  String get cuisineGrill => 'Grill';

  @override
  String get cuisineFastFood => 'Fast food';

  @override
  String get cuisineFineDining => 'Fine dining';

  @override
  String get cuisineVegetarian => 'Vegetarian';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsTileTotal => 'Restaurants';

  @override
  String get statsTileVisited => 'Visited';

  @override
  String get statsTileWantToTry => 'Want to try';

  @override
  String get statsTileAverageRating => 'Avg. rating';

  @override
  String statsAverageRatingValue(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString';
  }

  @override
  String get statsAverageRatingNone => '–';

  @override
  String get statsSectionCuisines => 'Cuisines';

  @override
  String get statsSectionPrice => 'Price range';

  @override
  String get statsSectionVisitsPerMonth => 'Visits per month';

  @override
  String get statsSectionRatingTrend => 'Average rating over time';

  @override
  String get statsSectionTopTags => 'Top tags';

  @override
  String get statsPriceNotSet => 'Not set';

  @override
  String get statsEmptyTitle => 'Nothing to show yet';

  @override
  String get statsEmptyBody => 'Add a restaurant to see your stats here.';

  @override
  String get widgetLabel => 'EatApp · Want to try';

  @override
  String get widgetDescription =>
      'Shows a random restaurant you want to try, right on your home screen.';

  @override
  String get widgetEmptyBody =>
      'Mark a restaurant \"want to try\" to see it here.';

  @override
  String get widgetActionShuffle => 'Shuffle';
}
