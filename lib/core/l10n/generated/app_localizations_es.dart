// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'EatApp';

  @override
  String get listTitle => 'Mis restaurantes';

  @override
  String get listSearchPlaceholder => 'Buscar restaurantes';

  @override
  String get listSearchClear => 'Borrar búsqueda';

  @override
  String get listSuggestionsTitle => 'Prueba una de estas';

  @override
  String get listSuggestionTopRated => 'Mejor valorados';

  @override
  String get listFilterMinRating => 'Puntuación';

  @override
  String get listFilterPrice => 'Precio';

  @override
  String get listFilterCuisine => 'Cocina';

  @override
  String get listFilterVisitStatus => 'Estado';

  @override
  String get listFilterLocation => 'Ubicación';

  @override
  String get listFilterCity => 'Ciudad';

  @override
  String get listFilterRegion => 'Región';

  @override
  String get listFilterCountry => 'País';

  @override
  String get listFilterAll => 'Todos';

  @override
  String listFilterLocationActive(int count) {
    return 'Ubicación · $count';
  }

  @override
  String get listEmptyTitle => 'Aún no hay restaurantes';

  @override
  String get listEmptyBody => 'Añade tu primer restaurante para empezar.';

  @override
  String get listEmptyNoResultsTitle => 'Sin resultados';

  @override
  String get listEmptyNoResultsBody => 'Prueba otra búsqueda o filtro.';

  @override
  String get listActionAddRestaurant => 'Añadir restaurante';

  @override
  String get listActionShareAll => 'Compartir todos los restaurantes';

  @override
  String get listActionClearFilters => 'Borrar filtros';

  @override
  String get listSortName => 'Nombre (A-Z)';

  @override
  String get listSortRating => 'Puntuación (de mayor a menor)';

  @override
  String get listSortNameShort => 'Nombre';

  @override
  String get listSortRatingShort => 'Puntuación';

  @override
  String get listFiltersTitle => 'Filtros';

  @override
  String get listFiltersExpand => 'Mostrar filtros';

  @override
  String get listFiltersCollapse => 'Ocultar filtros';

  @override
  String listFiltersActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtros activos',
      one: '$count filtro activo',
    );
    return '$_temp0';
  }

  @override
  String listResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurantes',
      one: '$count restaurante',
    );
    return '$_temp0';
  }

  @override
  String get actionBack => 'Atrás';

  @override
  String get actionGoBack => 'Volver';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionExport => 'Exportar';

  @override
  String get actionDone => 'Hecho';

  @override
  String get actionOk => 'Aceptar';

  @override
  String get detailNotFoundTitle => 'Restaurante no encontrado';

  @override
  String get detailNotFoundBody => 'Este restaurante se ha eliminado.';

  @override
  String get detailActionEdit => 'Editar';

  @override
  String get detailActionShare => 'Compartir';

  @override
  String get detailActionDelete => 'Eliminar';

  @override
  String get detailActionMore => 'Más opciones';

  @override
  String get detailDeleteConfirmTitle => '¿Eliminar este restaurante?';

  @override
  String get detailDeleteConfirmBody => 'Esta acción no se puede deshacer.';

  @override
  String get detailPlaceholderTitle => 'Selecciona un restaurante';

  @override
  String get detailPlaceholderBody =>
      'Elige uno de la lista para ver aquí sus detalles.';

  @override
  String aboutVersionTemplate(String version, int build, String revision) {
    return 'Versión $version (compilación $build, $revision)';
  }

  @override
  String aboutVersionTemplateClean(String version) {
    return 'Versión $version';
  }

  @override
  String ratingFormat(int rating) {
    return '$rating/5';
  }

  @override
  String get visitStatusVisited => 'Visitado';

  @override
  String get visitStatusWantToTry => 'Por probar';

  @override
  String restaurantRatingDescription(int rating) {
    return 'Puntuación $rating de 5';
  }

  @override
  String restaurantPriceDescription(String price) {
    return 'Rango de precio: $price';
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
  String get priceRange6 => '50 € o más';

  @override
  String get navRestaurants => 'Restaurantes';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navRoulette => 'Ruleta';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesEmptyTitle => 'Aún no hay favoritos';

  @override
  String get favoritesEmptyBody =>
      'Toca el corazón de un restaurante para guardarlo aquí.';

  @override
  String get actionAddFavorite => 'Añadir a favoritos';

  @override
  String get actionRemoveFavorite => 'Quitar de favoritos';

  @override
  String get rouletteTitle => 'Qué comemos';

  @override
  String get roulettePrompt => '¿No te decides? Deja que elija la app.';

  @override
  String get rouletteActionPick => 'Elegir uno';

  @override
  String get rouletteActionAgain => 'Otra vez';

  @override
  String get rouletteOnlyFavorites => 'Solo favoritos';

  @override
  String get rouletteFilterRating => 'Puntuación';

  @override
  String get rouletteFilterStatus => 'Estado';

  @override
  String get rouletteFilterPrice => 'Precio';

  @override
  String get rouletteEmptyTitle => 'Nada que elegir';

  @override
  String get rouletteEmptyBody =>
      'Ningún restaurante coincide con estos filtros.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsPalette => 'Esquema de color';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get themeModeLight => 'Claro';

  @override
  String get themeModeDark => 'Oscuro';

  @override
  String get paletteMercadoFresco => 'Mercado fresco';

  @override
  String get paletteGarden => 'Huerto';

  @override
  String get paletteIndigo => 'Índigo';

  @override
  String get settingsSectionData => 'Datos';

  @override
  String get settingsActionViewStatistics => 'Ver estadísticas';

  @override
  String get settingsActionExportData => 'Exportar mis datos';

  @override
  String get exportDialogTitle => 'Exportar restaurantes';

  @override
  String get exportDialogBody => 'Elige qué incluir en el archivo exportado.';

  @override
  String get exportDialogIncludeVisits => 'Incluir las visitas';

  @override
  String get settingsActionDeleteAllData => 'Eliminar todos los restaurantes';

  @override
  String get settingsDeleteAllConfirmTitle =>
      '¿Eliminar todos los restaurantes?';

  @override
  String get settingsDeleteAllConfirmBody =>
      'Esto elimina todos los restaurantes de la aplicación. Esta acción no se puede deshacer.';

  @override
  String get settingsActionHelp => 'Cómo usar EatApp';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsSectionLanguage => 'Idioma';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Catalán';

  @override
  String get languageSystem => 'Seguir el idioma del dispositivo';

  @override
  String get helpTitle => 'Cómo usar EatApp';

  @override
  String get helpIntro =>
      'Una guía rápida de todo lo que puede hacer EatApp — toca un tema para abrirlo.';

  @override
  String get helpTopicAddTitle => 'Añadir un restaurante';

  @override
  String get helpTopicAddBody =>
      'Toca el botón + en la pantalla de la lista. Rellena el nombre, la cocina y la dirección — el resto es opcional. Se guarda directamente en tu dispositivo, sin necesidad de cuenta.';

  @override
  String get helpTopicFavoritesTitle => 'Favoritos y quiero probar';

  @override
  String get helpTopicFavoritesBody =>
      'Toca el corazón de un restaurante para marcarlo como favorito — un sitio que te encanta. Toca el marcador para añadirlo a quiero probar — un sitio que planeas visitar. Ambos aparecen en su propia pestaña en la parte inferior.';

  @override
  String get helpTopicRouletteTitle => 'Ruleta: ¿no te decides?';

  @override
  String get helpTopicRouletteBody =>
      'Abre la pestaña Ruleta y gira — elige un restaurante al azar de tu lista de quiero probar. Filtra por cocina antes si buscas algo concreto.';

  @override
  String get helpTopicSharingTitle => 'Compartir un restaurante';

  @override
  String get helpTopicSharingBody =>
      'Abre los detalles de un restaurante y toca Compartir para enviarlo a un amigo que también tenga EatApp. Cuando abra el archivo, verá una pantalla de revisión para comprobar los detalles antes de añadirlo a su propia lista.';

  @override
  String get helpTopicWidgetTitle => 'Widget de pantalla de inicio';

  @override
  String get helpTopicWidgetBody =>
      'Añade el widget \"Quiero probar\" desde el selector de widgets de tu pantalla de inicio para ver una selección aleatoria de esa lista sin abrir la aplicación.';

  @override
  String get helpTopicExportTitle => 'Exportar tus datos';

  @override
  String get helpTopicExportBody =>
      'En Ajustes → Datos → Exportar mis datos, puedes guardar una copia de todo lo que has introducido como archivo, para hacer una copia de seguridad o moverlo a otro dispositivo.';

  @override
  String get editTitleAdd => 'Añadir restaurante';

  @override
  String get editTitleEdit => 'Editar restaurante';

  @override
  String get editActionSave => 'Guardar';

  @override
  String get editSectionBasics => 'Datos básicos';

  @override
  String get editSectionLinks => 'Enlaces';

  @override
  String get editSectionTags => 'Etiquetas';

  @override
  String get editActionAddPhoto => 'Añadir foto';

  @override
  String get editActionRemovePhoto => 'Quitar foto';

  @override
  String get editPhotoPreviewDescription =>
      'Vista previa de la foto del restaurante';

  @override
  String get editFieldName => 'Nombre';

  @override
  String get editFieldCuisine => 'Cocina';

  @override
  String get editCuisinePlaceholder => 'Selecciona una cocina';

  @override
  String get editFieldAddress => 'Dirección (calle, opcional)';

  @override
  String get editFieldCity => 'Ciudad (opcional)';

  @override
  String get editFieldRegion => 'Región (opcional)';

  @override
  String get editFieldCountry => 'País (opcional)';

  @override
  String get editFieldPriceRange => 'Rango de precio';

  @override
  String get editFieldWebsite => 'Web (opcional)';

  @override
  String get editFieldInstagram => 'Instagram (opcional)';

  @override
  String get editFieldTags => 'Añadir una etiqueta';

  @override
  String editActionRemoveTag(String tag) {
    return 'Quitar etiqueta $tag';
  }

  @override
  String get editErrorNameRequired => 'El nombre es obligatorio';

  @override
  String get editErrorCuisineRequired => 'Elige una cocina';

  @override
  String get editErrorWebsiteInvalid =>
      'Introduce una dirección web http/https válida';

  @override
  String get editErrorInstagramInvalid =>
      'Introduce un usuario de Instagram válido';

  @override
  String get importTitle => 'Importar restaurantes';

  @override
  String get importEmptyTitle => 'Nada que importar';

  @override
  String get importEmptyBody => 'Este archivo no contiene ningún restaurante.';

  @override
  String get importErrorTitle => 'No se puede abrir este archivo';

  @override
  String get importErrorTooLarge => 'Este archivo es demasiado grande.';

  @override
  String get importErrorInvalid =>
      'Esto no parece un archivo de restaurantes de EatApp.';

  @override
  String get importErrorIo =>
      'No se ha podido leer este archivo. Si lo has abierto directamente desde un adjunto de correo, prueba a descargarlo primero y ábrelo después desde las descargas.';

  @override
  String get importActionConfirm => 'Importar';

  @override
  String get importDuplicateLabel => 'Ya está en tu lista';

  @override
  String get importDecisionAdd => 'Añadir';

  @override
  String get importDecisionSkip => 'Omitir';

  @override
  String get importDecisionReplace => 'Reemplazar';

  @override
  String importSkippedInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurantes tenían datos no válidos y se han omitido',
      one: '$count restaurante tenía datos no válidos y se ha omitido',
    );
    return '$_temp0';
  }

  @override
  String importDuplicatesHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ya están en tu lista',
      one: '$count ya está en tu lista',
    );
    return '$_temp0';
  }

  @override
  String get detailSectionOverview => 'General';

  @override
  String get detailSectionRating => 'Puntuación y precio';

  @override
  String get detailSectionLinks => 'Enlaces';

  @override
  String get detailPhotoDescription => 'Foto del restaurante';

  @override
  String get detailLinkWebsite => 'Web';

  @override
  String get detailLinkInstagram => 'Instagram';

  @override
  String detailLinkHandleFormat(String handle) {
    return '@$handle';
  }

  @override
  String get detailLinkFailed => 'Ninguna app puede abrir este enlace.';

  @override
  String get detailSectionVisits => 'Visitas';

  @override
  String get detailSectionRatingTrend => 'Puntuación a lo largo del tiempo';

  @override
  String get detailVisitsEmptyTitle => 'Para probar, aún sin visitas';

  @override
  String get detailVisitsEmptyBody => 'Registra una visita cuando hayas ido.';

  @override
  String get detailActionLogVisit => 'Registrar visita';

  @override
  String get visitCardPhotoDescription => 'Foto de esta visita';

  @override
  String get logvisitTitle => 'Registrar visita';

  @override
  String get logvisitActionSave => 'Guardar';

  @override
  String get logvisitFieldDate => 'Fecha';

  @override
  String get logvisitFieldRating => 'Puntuación';

  @override
  String get logvisitFieldPrice => 'Rango de precio';

  @override
  String get logvisitFieldNotes => 'Notas (opcional)';

  @override
  String get logvisitActionAddPhoto => 'Añadir foto';

  @override
  String get logvisitActionRemovePhoto => 'Quitar foto';

  @override
  String get logvisitPhotoDescription => 'Foto de la visita';

  @override
  String get logvisitDatePickerConfirm => 'Aceptar';

  @override
  String get logvisitDatePickerCancel => 'Cancelar';

  @override
  String get cuisineMediterranean => 'Mediterránea';

  @override
  String get cuisineSpanish => 'Española';

  @override
  String get cuisineCatalan => 'Catalana';

  @override
  String get cuisineBasque => 'Vasca';

  @override
  String get cuisineItalian => 'Italiana';

  @override
  String get cuisineJapanese => 'Japonesa';

  @override
  String get cuisineChinese => 'China';

  @override
  String get cuisineAsian => 'Asiática';

  @override
  String get cuisineIndian => 'India';

  @override
  String get cuisineMiddleEastern => 'Oriente Medio';

  @override
  String get cuisineAmerican => 'Americana';

  @override
  String get cuisineSeafood => 'Marisco';

  @override
  String get cuisineBar => 'Bar';

  @override
  String get cuisineBeerBar => 'Cervecería';

  @override
  String get cuisineWineBar => 'Vinoteca';

  @override
  String get cuisineCafe => 'Café';

  @override
  String get cuisineBakery => 'Panadería';

  @override
  String get cuisineDessert => 'Postres';

  @override
  String get cuisineBreakfast => 'Desayuno';

  @override
  String get cuisineBrunch => 'Brunch';

  @override
  String get cuisineGrill => 'Parrilla';

  @override
  String get cuisineFastFood => 'Comida rápida';

  @override
  String get cuisineFineDining => 'Alta cocina';

  @override
  String get cuisineVegetarian => 'Vegetariana';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String get statsTileTotal => 'Restaurantes';

  @override
  String get statsTileVisited => 'Visitados';

  @override
  String get statsTileWantToTry => 'Por probar';

  @override
  String get statsTileAverageRating => 'Puntuación';

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
  String get statsSectionCuisines => 'Cocinas';

  @override
  String get statsSectionPrice => 'Rango de precio';

  @override
  String get statsSectionVisitsPerMonth => 'Visitas por mes';

  @override
  String get statsSectionRatingTrend =>
      'Puntuación media a lo largo del tiempo';

  @override
  String get statsSectionTopTags => 'Etiquetas más usadas';

  @override
  String get statsPriceNotSet => 'Sin definir';

  @override
  String get statsEmptyTitle => 'Todavía no hay nada que mostrar';

  @override
  String get statsEmptyBody =>
      'Añade un restaurante para ver aquí tus estadísticas.';

  @override
  String get widgetLabel => 'EatApp · Por probar';

  @override
  String get widgetDescription =>
      'Muestra un restaurante al azar de tu lista \"por probar\", en tu pantalla de inicio.';

  @override
  String get widgetEmptyBody =>
      'Marca un restaurante como \"por probar\" para verlo aquí.';

  @override
  String get widgetActionShuffle => 'Otro';
}
