import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../detail/restaurant_detail_screen.dart';
import '../edit/restaurant_edit_screen.dart';
import '../list/restaurant_list_screen.dart';
import '../list/restaurant_ui_model.dart';
import 'placeholder_screen.dart';

/// The app's root: a bottom navigation bar over the four top-level sections.
///
/// Plain `Navigator` rather than a router package — the app has four tabs and a
/// handful of pushed screens, which is well inside what `Navigator` handles, and
/// adding `go_router` for that would buy nothing a personal notebook needs. The
/// Android app's tablet `NavigationRail` / two-pane layout is left for the polish
/// block; this is the phone shape both share.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _push(String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlaceholderScreen(title: title),
      ),
    );
  }

  void _pushDetail(RestaurantUiModel restaurant) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RestaurantDetailScreen(
          restaurantId: restaurant.id,
          onEdit: (String id) => _pushEdit(restaurantId: id),
          // Logging a visit is its own block; until it lands this opens the
          // placeholder rather than doing nothing.
          onLogVisit: (String id) => _push(l10n.logvisitTitle),
        ),
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
          PlaceholderScreen(title: l10n.navFavorites),
          PlaceholderScreen(title: l10n.navRoulette),
          PlaceholderScreen(title: l10n.navSettings),
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
