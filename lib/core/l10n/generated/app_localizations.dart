import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('en'),
    Locale('es'),
  ];

  /// Brand name. Deliberately identical in every locale, the same way values/strings.xml marks it translatable="false".
  ///
  /// In en, this message translates to:
  /// **'EatApp'**
  String get appName;

  /// No description provided for @listTitle.
  ///
  /// In en, this message translates to:
  /// **'My Restaurants'**
  String get listTitle;

  /// No description provided for @listSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants'**
  String get listSearchPlaceholder;

  /// No description provided for @listSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get listSearchClear;

  /// No description provided for @listSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Try one of these'**
  String get listSuggestionsTitle;

  /// No description provided for @listSuggestionTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get listSuggestionTopRated;

  /// No description provided for @listFilterMinRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get listFilterMinRating;

  /// No description provided for @listFilterPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get listFilterPrice;

  /// No description provided for @listFilterCuisine.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get listFilterCuisine;

  /// No description provided for @listFilterVisitStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get listFilterVisitStatus;

  /// No description provided for @listFilterLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get listFilterLocation;

  /// No description provided for @listFilterCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get listFilterCity;

  /// No description provided for @listFilterRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get listFilterRegion;

  /// No description provided for @listFilterCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get listFilterCountry;

  /// No description provided for @listFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get listFilterAll;

  /// The Location chip's label once at least one of city/region/country is set; count is how many of the three.
  ///
  /// In en, this message translates to:
  /// **'Location · {count}'**
  String listFilterLocationActive(int count);

  /// No description provided for @listEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No restaurants yet'**
  String get listEmptyTitle;

  /// No description provided for @listEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first restaurant to get started.'**
  String get listEmptyBody;

  /// No description provided for @listEmptyNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get listEmptyNoResultsTitle;

  /// No description provided for @listEmptyNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get listEmptyNoResultsBody;

  /// No description provided for @listActionAddRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Add restaurant'**
  String get listActionAddRestaurant;

  /// No description provided for @listActionShareAll.
  ///
  /// In en, this message translates to:
  /// **'Share all restaurants'**
  String get listActionShareAll;

  /// No description provided for @listActionClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get listActionClearFilters;

  /// No description provided for @listSortName.
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get listSortName;

  /// No description provided for @listSortRating.
  ///
  /// In en, this message translates to:
  /// **'Rating (highest first)'**
  String get listSortRating;

  /// No description provided for @listSortNameShort.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get listSortNameShort;

  /// No description provided for @listSortRatingShort.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get listSortRatingShort;

  /// No description provided for @listFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get listFiltersTitle;

  /// No description provided for @listFiltersExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand filters'**
  String get listFiltersExpand;

  /// No description provided for @listFiltersCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse filters'**
  String get listFiltersCollapse;

  /// No description provided for @listFiltersActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} active filter} other{{count} active filters}}'**
  String listFiltersActiveCount(int count);

  /// No description provided for @listResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} restaurant} other{{count} restaurants}}'**
  String listResultCount(int count);

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get actionGoBack;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @detailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurant not found'**
  String get detailNotFoundTitle;

  /// No description provided for @detailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This restaurant was removed.'**
  String get detailNotFoundBody;

  /// No description provided for @detailActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get detailActionEdit;

  /// No description provided for @detailActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get detailActionShare;

  /// No description provided for @detailActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get detailActionDelete;

  /// No description provided for @detailActionMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get detailActionMore;

  /// No description provided for @detailDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this restaurant?'**
  String get detailDeleteConfirmTitle;

  /// No description provided for @detailDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get detailDeleteConfirmBody;

  /// No description provided for @detailPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a restaurant'**
  String get detailPlaceholderTitle;

  /// No description provided for @detailPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Choose one from the list to see its details here.'**
  String get detailPlaceholderBody;

  /// Shown for a dirty dev build, where the git revision is worth seeing.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build}, {revision})'**
  String aboutVersionTemplate(String version, int build, String revision);

  /// Shown for a clean build instead of aboutVersionTemplate; just the bare semantic version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersionTemplateClean(String version);

  /// No description provided for @ratingFormat.
  ///
  /// In en, this message translates to:
  /// **'{rating}/5'**
  String ratingFormat(int rating);

  /// No description provided for @visitStatusVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get visitStatusVisited;

  /// No description provided for @visitStatusWantToTry.
  ///
  /// In en, this message translates to:
  /// **'Want to try'**
  String get visitStatusWantToTry;

  /// Screen-reader phrasing for the star rating, which is drawn as stars.
  ///
  /// In en, this message translates to:
  /// **'Rated {rating} of 5'**
  String restaurantRatingDescription(int rating);

  /// Screen-reader phrasing for the price pill, which is drawn as a euro-range label.
  ///
  /// In en, this message translates to:
  /// **'Price range: {price}'**
  String restaurantPriceDescription(String price);

  /// No description provided for @priceRange1.
  ///
  /// In en, this message translates to:
  /// **'1-10 €'**
  String get priceRange1;

  /// No description provided for @priceRange2.
  ///
  /// In en, this message translates to:
  /// **'10-20 €'**
  String get priceRange2;

  /// No description provided for @priceRange3.
  ///
  /// In en, this message translates to:
  /// **'20-30 €'**
  String get priceRange3;

  /// No description provided for @priceRange4.
  ///
  /// In en, this message translates to:
  /// **'30-40 €'**
  String get priceRange4;

  /// No description provided for @priceRange5.
  ///
  /// In en, this message translates to:
  /// **'40-50 €'**
  String get priceRange5;

  /// No description provided for @priceRange6.
  ///
  /// In en, this message translates to:
  /// **'50 € or more'**
  String get priceRange6;

  /// No description provided for @navRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get navRestaurants;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navRoulette.
  ///
  /// In en, this message translates to:
  /// **'Roulette'**
  String get navRoulette;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a restaurant to keep it here.'**
  String get favoritesEmptyBody;

  /// No description provided for @actionAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get actionAddFavorite;

  /// No description provided for @actionRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get actionRemoveFavorite;

  /// No description provided for @rouletteTitle.
  ///
  /// In en, this message translates to:
  /// **'What to eat'**
  String get rouletteTitle;

  /// No description provided for @roulettePrompt.
  ///
  /// In en, this message translates to:
  /// **'Can\'t decide? Let the app pick.'**
  String get roulettePrompt;

  /// No description provided for @rouletteActionPick.
  ///
  /// In en, this message translates to:
  /// **'Pick one'**
  String get rouletteActionPick;

  /// No description provided for @rouletteActionAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rouletteActionAgain;

  /// No description provided for @rouletteOnlyFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get rouletteOnlyFavorites;

  /// No description provided for @rouletteFilterRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rouletteFilterRating;

  /// No description provided for @rouletteFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get rouletteFilterStatus;

  /// No description provided for @rouletteFilterPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get rouletteFilterPrice;

  /// No description provided for @rouletteEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pick from'**
  String get rouletteEmptyTitle;

  /// No description provided for @rouletteEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No restaurant matches these filters.'**
  String get rouletteEmptyBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsPalette.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get settingsPalette;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @paletteMercadoFresco.
  ///
  /// In en, this message translates to:
  /// **'Fresh Market'**
  String get paletteMercadoFresco;

  /// No description provided for @paletteGarden.
  ///
  /// In en, this message translates to:
  /// **'Garden'**
  String get paletteGarden;

  /// No description provided for @paletteIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get paletteIndigo;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsSectionData;

  /// No description provided for @settingsActionViewStatistics.
  ///
  /// In en, this message translates to:
  /// **'View statistics'**
  String get settingsActionViewStatistics;

  /// No description provided for @settingsActionExportData.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingsActionExportData;

  /// No description provided for @exportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export restaurants'**
  String get exportDialogTitle;

  /// No description provided for @exportDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Choose what to include in the exported file.'**
  String get exportDialogBody;

  /// No description provided for @exportDialogIncludeVisits.
  ///
  /// In en, this message translates to:
  /// **'Include visits'**
  String get exportDialogIncludeVisits;

  /// No description provided for @settingsActionDeleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all restaurants'**
  String get settingsActionDeleteAllData;

  /// No description provided for @settingsDeleteAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all restaurants?'**
  String get settingsDeleteAllConfirmTitle;

  /// No description provided for @settingsDeleteAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes every restaurant in the app. This can\'t be undone.'**
  String get settingsDeleteAllConfirmBody;

  /// No description provided for @settingsActionHelp.
  ///
  /// In en, this message translates to:
  /// **'How to use EatApp'**
  String get settingsActionHelp;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageCatalan.
  ///
  /// In en, this message translates to:
  /// **'Catalan'**
  String get languageCatalan;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the device language'**
  String get languageSystem;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'How to use EatApp'**
  String get helpTitle;

  /// No description provided for @helpIntro.
  ///
  /// In en, this message translates to:
  /// **'A quick guide to everything EatApp can do — tap a topic to open it.'**
  String get helpIntro;

  /// No description provided for @helpTopicAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Adding a restaurant'**
  String get helpTopicAddTitle;

  /// No description provided for @helpTopicAddBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button on the list screen. Fill in the name, cuisine and address — everything else is optional. It\'s saved straight to your device, no account needed.'**
  String get helpTopicAddBody;

  /// No description provided for @helpTopicFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites & want-to-try'**
  String get helpTopicFavoritesTitle;

  /// No description provided for @helpTopicFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a restaurant to mark it a favorite — a place you love. Tap the bookmark to add it to want-to-try — somewhere you\'re planning to visit. Both show up in their own tab at the bottom.'**
  String get helpTopicFavoritesBody;

  /// No description provided for @helpTopicRouletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Roulette: can\'t decide?'**
  String get helpTopicRouletteTitle;

  /// No description provided for @helpTopicRouletteBody.
  ///
  /// In en, this message translates to:
  /// **'Open the Roulette tab and spin — it picks a random restaurant from your want-to-try list. Filter by cuisine first if you\'re after something specific.'**
  String get helpTopicRouletteBody;

  /// No description provided for @helpTopicSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing a restaurant'**
  String get helpTopicSharingTitle;

  /// No description provided for @helpTopicSharingBody.
  ///
  /// In en, this message translates to:
  /// **'Open a restaurant\'s details and tap Share to send it to a friend who also has EatApp. When they open the file, they\'ll get a review screen to check the details before it\'s added to their own list.'**
  String get helpTopicSharingBody;

  /// No description provided for @helpTopicWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Home-screen widget'**
  String get helpTopicWidgetTitle;

  /// No description provided for @helpTopicWidgetBody.
  ///
  /// In en, this message translates to:
  /// **'Add the \"Want to try\" widget from your home screen\'s widget picker to see a random pick from that list without opening the app.'**
  String get helpTopicWidgetBody;

  /// No description provided for @helpTopicExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Exporting your data'**
  String get helpTopicExportTitle;

  /// No description provided for @helpTopicExportBody.
  ///
  /// In en, this message translates to:
  /// **'In Settings → Data → Export my data, you can save a copy of everything you\'ve entered as a file, to back it up or move it to another device.'**
  String get helpTopicExportBody;

  /// No description provided for @editTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add restaurant'**
  String get editTitleAdd;

  /// No description provided for @editTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit restaurant'**
  String get editTitleEdit;

  /// No description provided for @editActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editActionSave;

  /// No description provided for @editSectionBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get editSectionBasics;

  /// No description provided for @editSectionLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get editSectionLinks;

  /// No description provided for @editSectionTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get editSectionTags;

  /// No description provided for @editActionAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get editActionAddPhoto;

  /// No description provided for @editActionRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get editActionRemovePhoto;

  /// No description provided for @editPhotoPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Restaurant photo preview'**
  String get editPhotoPreviewDescription;

  /// No description provided for @editFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editFieldName;

  /// No description provided for @editFieldCuisine.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get editFieldCuisine;

  /// No description provided for @editCuisinePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select a cuisine'**
  String get editCuisinePlaceholder;

  /// No description provided for @editFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address (optional)'**
  String get editFieldAddress;

  /// No description provided for @editFieldCity.
  ///
  /// In en, this message translates to:
  /// **'Town / city (optional)'**
  String get editFieldCity;

  /// No description provided for @editFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Region (optional)'**
  String get editFieldRegion;

  /// No description provided for @editFieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country (optional)'**
  String get editFieldCountry;

  /// No description provided for @editFieldPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get editFieldPriceRange;

  /// No description provided for @editFieldWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website (optional)'**
  String get editFieldWebsite;

  /// No description provided for @editFieldInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram (optional)'**
  String get editFieldInstagram;

  /// No description provided for @editFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get editFieldTags;

  /// No description provided for @editActionRemoveTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {tag}'**
  String editActionRemoveTag(String tag);

  /// No description provided for @editErrorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get editErrorNameRequired;

  /// No description provided for @editErrorCuisineRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a cuisine'**
  String get editErrorCuisineRequired;

  /// No description provided for @editErrorWebsiteInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http/https web address'**
  String get editErrorWebsiteInvalid;

  /// No description provided for @editErrorInstagramInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Instagram handle'**
  String get editErrorInstagramInvalid;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import restaurants'**
  String get importTitle;

  /// No description provided for @importEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to import'**
  String get importEmptyTitle;

  /// No description provided for @importEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'This file doesn\'t contain any restaurants.'**
  String get importEmptyBody;

  /// No description provided for @importErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open this file'**
  String get importErrorTitle;

  /// No description provided for @importErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large.'**
  String get importErrorTooLarge;

  /// No description provided for @importErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like an EatApp restaurant file.'**
  String get importErrorInvalid;

  /// No description provided for @importErrorIo.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this file. If you opened it straight from an email attachment, try downloading it first, then open it from your downloads.'**
  String get importErrorIo;

  /// No description provided for @importActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importActionConfirm;

  /// No description provided for @importDuplicateLabel.
  ///
  /// In en, this message translates to:
  /// **'Already in your list'**
  String get importDuplicateLabel;

  /// No description provided for @importDecisionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get importDecisionAdd;

  /// No description provided for @importDecisionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get importDecisionSkip;

  /// No description provided for @importDecisionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get importDecisionReplace;

  /// No description provided for @importSkippedInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} restaurant had invalid data and was skipped} other{{count} restaurants had invalid data and were skipped}}'**
  String importSkippedInvalid(int count);

  /// No description provided for @importDuplicatesHeader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} already in your list} other{{count} already in your list}}'**
  String importDuplicatesHeader(int count);

  /// No description provided for @detailSectionOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get detailSectionOverview;

  /// No description provided for @detailSectionRating.
  ///
  /// In en, this message translates to:
  /// **'Rating and price'**
  String get detailSectionRating;

  /// No description provided for @detailSectionLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get detailSectionLinks;

  /// No description provided for @detailPhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Restaurant photo'**
  String get detailPhotoDescription;

  /// No description provided for @detailLinkWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get detailLinkWebsite;

  /// No description provided for @detailLinkInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get detailLinkInstagram;

  /// An Instagram handle rendered with its leading @.
  ///
  /// In en, this message translates to:
  /// **'@{handle}'**
  String detailLinkHandleFormat(String handle);

  /// No description provided for @detailLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'No app can open this link.'**
  String get detailLinkFailed;

  /// No description provided for @detailSectionVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get detailSectionVisits;

  /// No description provided for @detailSectionRatingTrend.
  ///
  /// In en, this message translates to:
  /// **'Rating over time'**
  String get detailSectionRatingTrend;

  /// No description provided for @detailVisitsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Want to try, no visits yet'**
  String get detailVisitsEmptyTitle;

  /// No description provided for @detailVisitsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Log a visit once you\'ve been.'**
  String get detailVisitsEmptyBody;

  /// No description provided for @detailActionLogVisit.
  ///
  /// In en, this message translates to:
  /// **'Log a visit'**
  String get detailActionLogVisit;

  /// No description provided for @visitCardPhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Photo from this visit'**
  String get visitCardPhotoDescription;

  /// No description provided for @logvisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Log a visit'**
  String get logvisitTitle;

  /// No description provided for @logvisitActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get logvisitActionSave;

  /// No description provided for @logvisitFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get logvisitFieldDate;

  /// No description provided for @logvisitFieldRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get logvisitFieldRating;

  /// No description provided for @logvisitFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get logvisitFieldPrice;

  /// No description provided for @logvisitFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get logvisitFieldNotes;

  /// No description provided for @logvisitActionAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get logvisitActionAddPhoto;

  /// No description provided for @logvisitActionRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get logvisitActionRemovePhoto;

  /// No description provided for @logvisitPhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Visit photo'**
  String get logvisitPhotoDescription;

  /// No description provided for @logvisitDatePickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get logvisitDatePickerConfirm;

  /// No description provided for @logvisitDatePickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get logvisitDatePickerCancel;

  /// No description provided for @cuisineMediterranean.
  ///
  /// In en, this message translates to:
  /// **'Mediterranean'**
  String get cuisineMediterranean;

  /// No description provided for @cuisineSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get cuisineSpanish;

  /// No description provided for @cuisineCatalan.
  ///
  /// In en, this message translates to:
  /// **'Catalan'**
  String get cuisineCatalan;

  /// No description provided for @cuisineBasque.
  ///
  /// In en, this message translates to:
  /// **'Basque'**
  String get cuisineBasque;

  /// No description provided for @cuisineItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get cuisineItalian;

  /// No description provided for @cuisineJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get cuisineJapanese;

  /// No description provided for @cuisineChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get cuisineChinese;

  /// No description provided for @cuisineAsian.
  ///
  /// In en, this message translates to:
  /// **'Asian'**
  String get cuisineAsian;

  /// No description provided for @cuisineIndian.
  ///
  /// In en, this message translates to:
  /// **'Indian'**
  String get cuisineIndian;

  /// No description provided for @cuisineMiddleEastern.
  ///
  /// In en, this message translates to:
  /// **'Middle Eastern'**
  String get cuisineMiddleEastern;

  /// No description provided for @cuisineAmerican.
  ///
  /// In en, this message translates to:
  /// **'American'**
  String get cuisineAmerican;

  /// No description provided for @cuisineSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get cuisineSeafood;

  /// No description provided for @cuisineBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get cuisineBar;

  /// No description provided for @cuisineBeerBar.
  ///
  /// In en, this message translates to:
  /// **'Beer bar'**
  String get cuisineBeerBar;

  /// No description provided for @cuisineWineBar.
  ///
  /// In en, this message translates to:
  /// **'Wine bar'**
  String get cuisineWineBar;

  /// No description provided for @cuisineCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get cuisineCafe;

  /// No description provided for @cuisineBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get cuisineBakery;

  /// No description provided for @cuisineDessert.
  ///
  /// In en, this message translates to:
  /// **'Dessert'**
  String get cuisineDessert;

  /// No description provided for @cuisineBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get cuisineBreakfast;

  /// No description provided for @cuisineBrunch.
  ///
  /// In en, this message translates to:
  /// **'Brunch'**
  String get cuisineBrunch;

  /// No description provided for @cuisineGrill.
  ///
  /// In en, this message translates to:
  /// **'Grill'**
  String get cuisineGrill;

  /// No description provided for @cuisineFastFood.
  ///
  /// In en, this message translates to:
  /// **'Fast food'**
  String get cuisineFastFood;

  /// No description provided for @cuisineFineDining.
  ///
  /// In en, this message translates to:
  /// **'Fine dining'**
  String get cuisineFineDining;

  /// No description provided for @cuisineVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get cuisineVegetarian;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsTileTotal.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get statsTileTotal;

  /// No description provided for @statsTileVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get statsTileVisited;

  /// No description provided for @statsTileWantToTry.
  ///
  /// In en, this message translates to:
  /// **'Want to try'**
  String get statsTileWantToTry;

  /// No description provided for @statsTileAverageRating.
  ///
  /// In en, this message translates to:
  /// **'Avg. rating'**
  String get statsTileAverageRating;

  /// An average rating shown to one decimal place.
  ///
  /// In en, this message translates to:
  /// **'{value}'**
  String statsAverageRatingValue(double value);

  /// No description provided for @statsAverageRatingNone.
  ///
  /// In en, this message translates to:
  /// **'–'**
  String get statsAverageRatingNone;

  /// No description provided for @statsSectionCuisines.
  ///
  /// In en, this message translates to:
  /// **'Cuisines'**
  String get statsSectionCuisines;

  /// No description provided for @statsSectionPrice.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get statsSectionPrice;

  /// No description provided for @statsSectionVisitsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Visits per month'**
  String get statsSectionVisitsPerMonth;

  /// No description provided for @statsSectionRatingTrend.
  ///
  /// In en, this message translates to:
  /// **'Average rating over time'**
  String get statsSectionRatingTrend;

  /// No description provided for @statsSectionTopTags.
  ///
  /// In en, this message translates to:
  /// **'Top tags'**
  String get statsSectionTopTags;

  /// No description provided for @statsPriceNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get statsPriceNotSet;

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a restaurant to see your stats here.'**
  String get statsEmptyBody;

  /// No description provided for @widgetLabel.
  ///
  /// In en, this message translates to:
  /// **'EatApp · Want to try'**
  String get widgetLabel;

  /// No description provided for @widgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows a random restaurant you want to try, right on your home screen.'**
  String get widgetDescription;

  /// No description provided for @widgetEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Mark a restaurant \"want to try\" to see it here.'**
  String get widgetEmptyBody;

  /// No description provided for @widgetActionShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get widgetActionShuffle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ca', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
