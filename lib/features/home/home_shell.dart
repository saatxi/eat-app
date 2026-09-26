import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
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
  });

  /// Non-null only on the cold start that opened the app via "Open with
  /// EatApp" on a shared restaurant file.
  final String? initialSharedFilePath;

  /// The warm-start counterpart: a shared file arriving while the app is
  /// already running.
  final Stream<String>? sharedFileStream;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  StreamSubscription<String>? _sharedFiles;

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
  }

  @override
  void dispose() {
    _sharedFiles?.cancel();
    super.dispose();
  }

  void _pushDetail(RestaurantUiModel restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RestaurantDetailScreen(
          restaurantId: restaurant.id,
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
