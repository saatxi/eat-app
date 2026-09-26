import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
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

/// The app's root: the four top-level sections, laid out for the window they are
/// given.
///
/// On a phone that is a bottom navigation bar over one section at a time. On a
/// tablet-width window it becomes a `NavigationRail` beside the sections, and
/// while a list section is showing, the selected restaurant's detail sits beside
/// the list rather than being pushed as a route.
///
/// The sections themselves are one `IndexedStack` in both shapes, so a screen's
/// state survives a tab switch and the window crossing the breakpoint. The
/// detail pane sits outside it, though, since it belongs to whichever list
/// section is on screen rather than to the stack.
///
/// Plain `Navigator` rather than a router package — the app has four tabs and a
/// handful of pushed screens, which is well inside what `Navigator` handles, and
/// adding `go_router` for that would buy nothing a personal notebook needs.
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

  /// The width at which the shell stops looking like a phone. Material's
  /// "expanded" window class, and comfortably above a phone in landscape.
  static const double twoPaneBreakpoint = 840;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Which restaurant the detail pane is showing, on a wide window only. Null
  /// draws the "nothing selected" placeholder; on a phone the selection is the
  /// pushed route instead and this stays null.
  String? _selectedRestaurantId;

  StreamSubscription<String>? _sharedFiles;
  StreamSubscription<Uri?>? _widgetClicks;

  /// Read from `MediaQuery` rather than a `LayoutBuilder` so the callbacks below
  /// can ask the same question the build method did.
  bool get _isTwoPane =>
      MediaQuery.sizeOf(context).width >= HomeShell.twoPaneBreakpoint;

  /// True for the two sections that are restaurant lists, and so the only ones
  /// the detail pane has anything to say about.
  bool get _isListSection => _index <= 1;

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

  void _selectTab(int index) => setState(() => _index = index);

  /// Opens a restaurant, in whichever way the current window wants: the detail
  /// pane beside the list when there is room for two, a pushed route when there
  /// isn't.
  void _openRestaurant(RestaurantUiModel restaurant) =>
      _openRestaurantById(restaurant.id);

  void _openRestaurantById(String restaurantId) {
    if (_isTwoPane) {
      setState(() => _selectedRestaurantId = restaurantId);
    } else {
      _pushDetailById(restaurantId);
    }
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

  /// Pushes the detail screen for [restaurantId] — the phone shape, where there
  /// is only room for one thing at a time.
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

  /// Opens the detail screen named by a home-screen widget tap. Anything that
  /// isn't one of our links — the shuffle URI, a link from another app — is
  /// ignored rather than pushed.
  void _openWidgetLink(Uri? uri) {
    final String? restaurantId = homeWidgetRestaurantId(uri);
    if (!mounted || restaurantId == null) {
      return;
    }
    _openRestaurantById(restaurantId);
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
    final bool twoPane = _isTwoPane;

    return Scaffold(
      body: twoPane ? _twoPanes(l10n) : _sections(l10n),
      bottomNavigationBar: twoPane ? null : _bottomBar(l10n),
    );
  }

  Widget _twoPanes(AppLocalizations l10n) {
    return HeroMode(
      // One route holds the list and the detail pane at once, so the selected
      // row and the detail header would carry the same Hero tag — which a flight
      // rejects. Nothing needs to fly between them anyway: both are already on
      // screen.
      enabled: false,
      child: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            labelType: NavigationRailLabelType.all,
            destinations: _railDestinations(l10n),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _sections(l10n)),
          if (_isListSection) ...<Widget>[
            const VerticalDivider(width: 1),
            Expanded(child: _detailPane()),
          ],
        ],
      ),
    );
  }

  /// The four sections, stacked so their state survives a tab switch — and a
  /// window crossing the two-pane breakpoint.
  Widget _sections(AppLocalizations l10n) {
    return IndexedStack(
      index: _index,
      children: <Widget>[
        RestaurantListScreen(
          onOpenRestaurant: _openRestaurant,
          onAddRestaurant: _pushEdit,
        ),
        RestaurantListScreen(
          favouritesOnly: true,
          onOpenRestaurant: _openRestaurant,
        ),
        RouletteScreen(onOpenRestaurant: _openRestaurant),
        SettingsScreen(onViewStatistics: _pushStatistics),
      ],
    );
  }

  Widget _detailPane() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? restaurantId = _selectedRestaurantId;
    if (restaurantId == null) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: l10n.detailSelectTitle,
        body: l10n.detailSelectBody,
      );
    }
    return RestaurantDetailScreen(
      // Keyed by id so picking another restaurant rebuilds the screen — and
      // therefore its controller — instead of leaving the previous one's state
      // on show.
      key: ValueKey<String>(restaurantId),
      restaurantId: restaurantId,
      embedded: true,
      onClose: () => setState(() => _selectedRestaurantId = null),
      onEdit: (String id) => _pushEdit(restaurantId: id),
      onLogVisit: _pushLogVisit,
    );
  }

  NavigationBar _bottomBar(AppLocalizations l10n) => NavigationBar(
    selectedIndex: _index,
    onDestinationSelected: _selectTab,
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
  );

  /// The rail's own copy of the same four destinations: a rail takes
  /// `NavigationRailDestination`s, which are a different type from the bottom
  /// bar's, so the icons and labels have to be listed twice.
  List<NavigationRailDestination> _railDestinations(AppLocalizations l10n) =>
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: const Icon(Icons.restaurant_menu),
          label: Text(l10n.navRestaurants),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          label: Text(l10n.navFavorites),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.casino_outlined),
          selectedIcon: const Icon(Icons.casino),
          label: Text(l10n.navRoulette),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(l10n.navSettings),
        ),
      ];
}
