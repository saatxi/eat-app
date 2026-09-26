import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../widget/home_widget_snapshot.dart';
import '../detail/restaurant_detail_screen.dart';
import '../edit/restaurant_edit_screen.dart';
import '../import_export/import_screen.dart';
import '../list/restaurant_list_screen.dart';
import '../list/restaurant_ui_model.dart';
import '../log_visit/log_visit_screen.dart';
import '../roulette/roulette_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/statistics_screen.dart';

/// The app's root: a bottom navigation bar over the four top-level sections.
///
/// Plain `Navigator` rather than a router package — the app has four tabs and a
/// handful of pushed screens, which is well inside what `Navigator` handles, and
/// adding `go_router` for that would buy nothing a personal notebook needs. The
/// Android app's tablet `NavigationRail` / two-pane layout is left for the polish
/// block; this is the phone shape both share.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.initialSharedFilePath,
    this.sharedFileStream,
    this.initialWidgetUri,
    this.widgetClickStream,
  });

  /// Non-null only on the cold start that opened the app via "Open with
  /// EatApp" on a shared restaurant file.
  final String? initialSharedFilePath;

  /// The warm-start counterpart: a shared file arriving while the app is
  /// already running.
  final Stream<String>? sharedFileStream;

  /// Non-null only on the cold start that opened the app by tapping the
  /// home-screen widget. Resolved through `homeWidgetRestaurantId`, so a link
  /// that isn't ours is ignored rather than pushed.
  final Uri? initialWidgetUri;

  /// The warm-start counterpart: the widget tapped while the app is already
  /// running.
  final Stream<Uri?>? widgetClickStream;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  StreamSubscription<String>? _sharedFiles;
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialSharedFilePath;
    if (initial != null) {
      // The Navigator above this widget is not ready until the first frame,
      // so the cold-start import is pushed once it is.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openImport(initial));
    }
    _sharedFiles = widget.sharedFileStream?.listen(_openImport);

    final Uri? initialWidget = widget.initialWidgetUri;
    if (initialWidget != null) {
      // Same first-frame constraint as the cold-start import above.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openWidgetLink(initialWidget),
      );
    }
    _widgetClicks = widget.widgetClickStream?.listen(_openWidgetLink);
  }

  @override
  void dispose() {
    _sharedFiles?.cancel();
    _widgetClicks?.cancel();
    super.dispose();
  }

  void _pushDetail(RestaurantUiModel restaurant) =>
      _pushDetailById(restaurant.id);

  /// Pushes the detail screen for [restaurantId]. Split out from [_pushDetail]
  /// because the widget link names a restaurant by id, with no UI model to hand.
  void _pushDetailById(String restaurantId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RestaurantDetailScreen(
          restaurantId: restaurantId,
          onEdit: (String id) => _pushEdit(restaurantId: id),
          onLogVisit: _pushLogVisit,
        ),
      ),
    );
  }

  void _pushStatistics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const StatisticsScreen(),
      ),
    );
  }

  void _pushLogVisit(String restaurantId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            LogVisitScreen(restaurantId: restaurantId),
      ),
    );
  }

  void _pushEdit({String? restaurantId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            RestaurantEditScreen(restaurantId: restaurantId),
      ),
    );
  }

  /// Opens the detail screen named by a home-screen widget tap. Anything that
  /// isn't one of our links — the shuffle URI, a link from another app — is
  /// ignored rather than pushed.
  void _openWidgetLink(Uri? uri) {
    final String? restaurantId = homeWidgetRestaurantId(uri);
    if (!mounted || restaurantId == null) {
      return;
    }
    _pushDetailById(restaurantId);
  }

  /// Opens the review screen for a file handed over by another app. Pushed on
  /// top of whatever is showing, since "Open with" can arrive on any screen.
  void _openImport(String filePath) {
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ImportScreen(
          filePath: filePath,
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          RestaurantListScreen(
            onOpenRestaurant: _pushDetail,
            onAddRestaurant: _pushEdit,
          ),
          RestaurantListScreen(
            favouritesOnly: true,
            onOpenRestaurant: _pushDetail,
          ),
          RouletteScreen(onOpenRestaurant: _pushDetail),
          SettingsScreen(onViewStatistics: _pushStatistics),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) => setState(() => _index = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu),
            label: l10n.navRestaurants,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.navFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.casino_outlined),
            selectedIcon: const Icon(Icons.casino),
            label: l10n.navRoulette,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
