// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appName => 'EatApp';

  @override
  String get listTitle => 'Els meus restaurants';

  @override
  String get listSearchPlaceholder => 'Cerca restaurants';

  @override
  String get listSearchClear => 'Esborra la cerca';

  @override
  String get listSuggestionsTitle => 'Prova\'n una';

  @override
  String get listSuggestionTopRated => 'Millor valorats';

  @override
  String get listFilterMinRating => 'Puntuació';

  @override
  String get listFilterPrice => 'Preu';

  @override
  String get listFilterCuisine => 'Cuina';

  @override
  String get listFilterVisitStatus => 'Estat';

  @override
  String get listFilterLocation => 'Ubicació';

  @override
  String get listFilterCity => 'Poble / ciutat';

  @override
  String get listFilterRegion => 'Regió';

  @override
  String get listFilterCountry => 'País';

  @override
  String get listFilterAll => 'Tots';

  @override
  String listFilterLocationActive(int count) {
    return 'Ubicació · $count';
  }

  @override
  String get listEmptyTitle => 'Encara no hi ha restaurants';

  @override
  String get listEmptyBody => 'Afegeix el teu primer restaurant per començar.';

  @override
  String get listEmptyNoResultsTitle => 'Sense resultats';

  @override
  String get listEmptyNoResultsBody =>
      'Prova una altra cerca o un altre filtre.';

  @override
  String get listActionAddRestaurant => 'Afegeix un restaurant';

  @override
  String get listActionShareAll => 'Comparteix tots els restaurants';

  @override
  String get listActionClearFilters => 'Esborra els filtres';

  @override
  String get listSortName => 'Nom (A-Z)';

  @override
  String get listSortRating => 'Puntuació (de més a menys)';

  @override
  String get listSortNameShort => 'Nom';

  @override
  String get listSortRatingShort => 'Puntuació';

  @override
  String get listFiltersTitle => 'Filtres';

  @override
  String get listFiltersExpand => 'Mostra els filtres';

  @override
  String get listFiltersCollapse => 'Amaga els filtres';

  @override
  String listFiltersActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtres actius',
      one: '$count filtre actiu',
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
  String get actionBack => 'Enrere';

  @override
  String get actionGoBack => 'Torna';

  @override
  String get actionRetry => 'Torna-ho a provar';

  @override
  String get actionCancel => 'Cancel·la';

  @override
  String get actionDelete => 'Elimina';

  @override
  String get actionExport => 'Exporta';

  @override
  String get actionDone => 'Fet';

  @override
  String get actionOk => 'D\'acord';

  @override
  String get detailNotFoundTitle => 'Restaurant no trobat';

  @override
  String get detailNotFoundBody => 'Aquest restaurant s\'ha eliminat.';

  @override
  String get detailActionEdit => 'Edita';

  @override
  String get detailActionShare => 'Comparteix';

  @override
  String get detailActionDelete => 'Elimina';

  @override
  String get detailActionMore => 'Més opcions';

  @override
  String get detailDeleteConfirmTitle => 'Vols eliminar aquest restaurant?';

  @override
  String get detailDeleteConfirmBody => 'Aquesta acció no es pot desfer.';

  @override
  String get detailPlaceholderTitle => 'Selecciona un restaurant';

  @override
  String get detailPlaceholderBody =>
      'Tria\'n un de la llista per veure\'n els detalls aquí.';

  @override
  String aboutVersionTemplate(String version, int build, String revision) {
    return 'Versió $version (compilació $build, $revision)';
  }

  @override
  String aboutVersionTemplateClean(String version) {
    return 'Versió $version';
  }

  @override
  String ratingFormat(int rating) {
    return '$rating/5';
  }

  @override
  String get visitStatusVisited => 'Visitat';

  @override
  String get visitStatusWantToTry => 'Per provar';

  @override
  String restaurantRatingDescription(int rating) {
    return 'Puntuat amb $rating de 5';
  }

  @override
  String restaurantPriceDescription(String price) {
    return 'Rang de preu: $price';
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
  String get priceRange6 => '50 € o més';

  @override
  String get navRestaurants => 'Restaurants';

  @override
  String get navFavorites => 'Preferits';

  @override
  String get navRoulette => 'Ruleta';

  @override
  String get navSettings => 'Configuració';

  @override
  String get favoritesTitle => 'Preferits';

  @override
  String get favoritesEmptyTitle => 'Encara no hi ha preferits';

  @override
  String get favoritesEmptyBody =>
      'Toca el cor d\'un restaurant per desar-lo aquí.';

  @override
  String get actionAddFavorite => 'Afegeix als preferits';

  @override
  String get actionRemoveFavorite => 'Elimina dels preferits';

  @override
  String get rouletteTitle => 'Què mengem';

  @override
  String get roulettePrompt => 'No et decideixes? Deixa que triï l\'app.';

  @override
  String get rouletteActionPick => 'Tria\'n un';

  @override
  String get rouletteActionAgain => 'Torna-ho a provar';

  @override
  String get rouletteOnlyFavorites => 'Només preferits';

  @override
  String get rouletteFilterRating => 'Puntuació';

  @override
  String get rouletteFilterStatus => 'Estat';

  @override
  String get rouletteFilterPrice => 'Preu';

  @override
  String get rouletteEmptyTitle => 'Res per triar';

  @override
  String get rouletteEmptyBody =>
      'Cap restaurant coincideix amb aquests filtres.';

  @override
  String get settingsTitle => 'Configuració';

  @override
  String get settingsSectionAppearance => 'Aparença';

  @override
  String get settingsPalette => 'Esquema de color';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get themeModeLight => 'Clar';

  @override
  String get themeModeDark => 'Fosc';

  @override
  String get paletteMercadoFresco => 'Mercat fresc';

  @override
  String get paletteGarden => 'Hort';

  @override
  String get paletteIndigo => 'Indi';

  @override
  String get settingsSectionData => 'Dades';

  @override
  String get settingsActionViewStatistics => 'Veure estadístiques';

  @override
  String get settingsActionExportData => 'Exporta les meves dades';

  @override
  String get exportDialogTitle => 'Exporta restaurants';

  @override
  String get exportDialogBody => 'Tria què vols incloure al fitxer exportat.';

  @override
  String get exportDialogIncludeVisits => 'Inclou les visites';

  @override
  String get settingsActionDeleteAllData => 'Elimina tots els restaurants';

  @override
  String get settingsDeleteAllConfirmTitle =>
      'Vols eliminar tots els restaurants?';

  @override
  String get settingsDeleteAllConfirmBody =>
      'Això elimina tots els restaurants de l\'aplicació. Aquesta acció no es pot desfer.';

  @override
  String get settingsActionHelp => 'Com s\'utilitza EatApp';

  @override
  String get settingsSectionAbout => 'Quant a';

  @override
  String get settingsSectionLanguage => 'Idioma';

  @override
  String get languageEnglish => 'Anglès';

  @override
  String get languageSpanish => 'Espanyol';

  @override
  String get languageCatalan => 'Català';

  @override
  String get helpTitle => 'Com s\'utilitza EatApp';

  @override
  String get helpIntro =>
      'Una guia ràpida de tot el que pot fer EatApp — toca un tema per obrir-lo.';

  @override
  String get helpTopicAddTitle => 'Afegir un restaurant';

  @override
  String get helpTopicAddBody =>
      'Toca el botó + a la pantalla de la llista. Omple el nom, la cuina i l\'adreça — la resta és opcional. Es desa directament al teu dispositiu, sense necessitat de compte.';

  @override
  String get helpTopicFavoritesTitle => 'Favorits i vull provar';

  @override
  String get helpTopicFavoritesBody =>
      'Toca el cor d\'un restaurant per marcar-lo com a favorit — un lloc que t\'encanta. Toca el marcador per afegir-lo a vull provar — un lloc que planeges visitar. Tots dos apareixen a la seva pròpia pestanya a la part inferior.';

  @override
  String get helpTopicRouletteTitle => 'Ruleta: no et decideixes?';

  @override
  String get helpTopicRouletteBody =>
      'Obre la pestanya Ruleta i gira — tria un restaurant a l\'atzar de la teva llista de vull provar. Filtra per cuina abans si busques alguna cosa concreta.';

  @override
  String get helpTopicSharingTitle => 'Compartir un restaurant';

  @override
  String get helpTopicSharingBody =>
      'Obre els detalls d\'un restaurant i toca Comparteix per enviar-lo a un amic que també tingui EatApp. Quan obri el fitxer, veurà una pantalla de revisió per comprovar els detalls abans d\'afegir-lo a la seva pròpia llista.';

  @override
  String get helpTopicWidgetTitle => 'Widget de pantalla d\'inici';

  @override
  String get helpTopicWidgetBody =>
      'Afegeix el widget \"Vull provar\" des del selector de widgets de la teva pantalla d\'inici per veure una selecció a l\'atzar d\'aquesta llista sense obrir l\'aplicació.';

  @override
  String get helpTopicExportTitle => 'Exportar les teves dades';

  @override
  String get helpTopicExportBody =>
      'A Configuració → Dades → Exporta les meves dades, pots desar una còpia de tot el que has introduït com a fitxer, per fer-ne una còpia de seguretat o moure-la a un altre dispositiu.';

  @override
  String get editTitleAdd => 'Afegeix un restaurant';

  @override
  String get editTitleEdit => 'Edita el restaurant';

  @override
  String get editActionSave => 'Desa';

  @override
  String get editSectionBasics => 'Dades bàsiques';

  @override
  String get editSectionLinks => 'Enllaços';

  @override
  String get editSectionTags => 'Etiquetes';

  @override
  String get editActionAddPhoto => 'Afegeix una foto';

  @override
  String get editActionRemovePhoto => 'Suprimeix la foto';

  @override
  String get editPhotoPreviewDescription =>
      'Previsualització de la foto del restaurant';

  @override
  String get editFieldName => 'Nom';

  @override
  String get editFieldCuisine => 'Cuina';

  @override
  String get editCuisinePlaceholder => 'Selecciona una cuina';

  @override
  String get editFieldAddress => 'Adreça (carrer, opcional)';

  @override
  String get editFieldCity => 'Poble / ciutat (opcional)';

  @override
  String get editFieldRegion => 'Regió (opcional)';

  @override
  String get editFieldCountry => 'País (opcional)';

  @override
  String get editFieldPriceRange => 'Rang de preu';

  @override
  String get editFieldWebsite => 'Web (opcional)';

  @override
  String get editFieldInstagram => 'Instagram (opcional)';

  @override
  String get editFieldTags => 'Afegeix una etiqueta';

  @override
  String editActionRemoveTag(String tag) {
    return 'Suprimeix l\'etiqueta $tag';
  }

  @override
  String get editErrorNameRequired => 'El nom és obligatori';

  @override
  String get editErrorCuisineRequired => 'Tria una cuina';

  @override
  String get editErrorWebsiteInvalid =>
      'Introdueix una adreça web http/https vàlida';

  @override
  String get editErrorInstagramInvalid =>
      'Introdueix un usuari d\'Instagram vàlid';

  @override
  String get importTitle => 'Importa restaurants';

  @override
  String get importEmptyTitle => 'Res per importar';

  @override
  String get importEmptyBody => 'Aquest fitxer no conté cap restaurant.';

  @override
  String get importErrorTitle => 'No es pot obrir aquest fitxer';

  @override
  String get importErrorTooLarge => 'Aquest fitxer és massa gran.';

  @override
  String get importErrorInvalid =>
      'Això no sembla un fitxer de restaurants d\'EatApp.';

  @override
  String get importErrorIo =>
      'No s\'ha pogut llegir aquest fitxer. Si l\'has obert directament des d\'un adjunt de correu, prova de descarregar-lo primer i obrir-lo després des de les descàrregues.';

  @override
  String get importActionConfirm => 'Importa';

  @override
  String get importDuplicateLabel => 'Ja hi és a la teva llista';

  @override
  String get importDecisionAdd => 'Afegeix';

  @override
  String get importDecisionSkip => 'Ometre';

  @override
  String get importDecisionReplace => 'Reemplaça';

  @override
  String importSkippedInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurants tenien dades no vàlides i s\'han omès',
      one: '$count restaurant tenia dades no vàlides i s\'ha omès',
    );
    return '$_temp0';
  }

  @override
  String importDuplicatesHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ja hi són a la teva llista',
      one: '$count ja hi és a la teva llista',
    );
    return '$_temp0';
  }

  @override
  String get detailSectionOverview => 'Resum';

  @override
  String get detailSectionRating => 'Puntuació i preu';

  @override
  String get detailSectionLinks => 'Enllaços';

  @override
  String get detailPhotoDescription => 'Foto del restaurant';

  @override
  String get detailLinkWebsite => 'Web';

  @override
  String get detailLinkInstagram => 'Instagram';

  @override
  String detailLinkHandleFormat(String handle) {
    return '@$handle';
  }

  @override
  String get detailLinkFailed => 'Cap aplicació pot obrir aquest enllaç.';

  @override
  String get detailSectionVisits => 'Visites';

  @override
  String get detailSectionRatingTrend => 'Puntuació al llarg del temps';

  @override
  String get detailVisitsEmptyTitle => 'Per provar, encara sense visites';

  @override
  String get detailVisitsEmptyBody => 'Registra una visita quan hi hagis anat.';

  @override
  String get detailActionLogVisit => 'Registrar visita';

  @override
  String get visitCardPhotoDescription => 'Foto d\'aquesta visita';

  @override
  String get logvisitTitle => 'Registrar visita';

  @override
  String get logvisitActionSave => 'Desar';

  @override
  String get logvisitFieldDate => 'Data';

  @override
  String get logvisitFieldRating => 'Puntuació';

  @override
  String get logvisitFieldPrice => 'Rang de preu';

  @override
  String get logvisitFieldNotes => 'Notes (opcional)';

  @override
  String get logvisitActionAddPhoto => 'Afegir foto';

  @override
  String get logvisitActionRemovePhoto => 'Treure foto';

  @override
  String get logvisitPhotoDescription => 'Foto de la visita';

  @override
  String get logvisitDatePickerConfirm => 'D\'acord';

  @override
  String get logvisitDatePickerCancel => 'Cancel·la';

  @override
  String get cuisineMediterranean => 'Mediterrània';

  @override
  String get cuisineSpanish => 'Espanyola';

  @override
  String get cuisineCatalan => 'Catalana';

  @override
  String get cuisineBasque => 'Basca';

  @override
  String get cuisineItalian => 'Italiana';

  @override
  String get cuisineJapanese => 'Japonesa';

  @override
  String get cuisineChinese => 'Xinesa';

  @override
  String get cuisineAsian => 'Asiàtica';

  @override
  String get cuisineIndian => 'Índia';

  @override
  String get cuisineMiddleEastern => 'Orient Mitjà';

  @override
  String get cuisineAmerican => 'Americana';

  @override
  String get cuisineSeafood => 'Marisc';

  @override
  String get cuisineBar => 'Bar';

  @override
  String get cuisineBeerBar => 'Cerveseria';

  @override
  String get cuisineWineBar => 'Vinoteca';

  @override
  String get cuisineCafe => 'Cafè';

  @override
  String get cuisineBakery => 'Fleca';

  @override
  String get cuisineDessert => 'Postres';

  @override
  String get cuisineBreakfast => 'Esmorzar';

  @override
  String get cuisineBrunch => 'Brunch';

  @override
  String get cuisineGrill => 'Graella';

  @override
  String get cuisineFastFood => 'Menjar ràpid';

  @override
  String get cuisineFineDining => 'Alta cuina';

  @override
  String get cuisineVegetarian => 'Vegetariana';

  @override
  String get statsTitle => 'Estadístiques';

  @override
  String get statsTileTotal => 'Restaurants';

  @override
  String get statsTileVisited => 'Visitats';

  @override
  String get statsTileWantToTry => 'Per provar';

  @override
  String get statsTileAverageRating => 'Puntuació';

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
  String get statsSectionCuisines => 'Cuines';

  @override
  String get statsSectionPrice => 'Rang de preu';

  @override
  String get statsSectionVisitsPerMonth => 'Visites per mes';

  @override
  String get statsSectionRatingTrend => 'Puntuació mitjana al llarg del temps';

  @override
  String get statsSectionTopTags => 'Etiquetes més usades';

  @override
  String get statsPriceNotSet => 'Sense definir';

  @override
  String get statsEmptyTitle => 'Encara no hi ha res a mostrar';

  @override
  String get statsEmptyBody =>
      'Afegeix un restaurant per veure aquí les teves estadístiques.';

  @override
  String get widgetLabel => 'EatApp · Per provar';

  @override
  String get widgetDescription =>
      'Mostra un restaurant a l\'atzar de la teva llista \"per provar\", a la pantalla d\'inici.';

  @override
  String get widgetEmptyBody =>
      'Marca un restaurant com a \"per provar\" per veure\'l aquí.';

  @override
  String get widgetActionShuffle => 'Un altre';
}
