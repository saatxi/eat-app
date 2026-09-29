import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/groups/invite_link.dart';
import '../../widget/home_widget_snapshot.dart';
import '../detail/restaurant_detail_screen.dart';
import '../edit/restaurant_edit_screen.dart';
import '../groups/groups_controller.dart';
import '../groups/groups_screen.dart';
import '../groups/join_screen.dart';
import '../import_export/import_screen.dart';
import '../list/journal_screen.dart';
import '../list/restaurant_ui_model.dart';
import '../log_visit/log_visit_screen.dart';
import '../roulette/roulette_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/statistics_screen.dart';

/// The app's root: the three top-level sections, laid out for the window they
/// are given.
///
/// On a phone that is a bottom navigation bar over one section at a time. On a
/// tablet-width window it becomes a `NavigationRail` beside the sections, and
/// while the Journal is showing, the selected restaurant's detail sits beside
/// the list rather than being pushed as a route.
///
/// Three sections, not four: Favorites folded into the Journal as a quick
/// segment, so the shell is Journal, Roulette and Settings. The sections are one
/// `IndexedStack` in both shapes, so a screen's state survives a tab switch and
/// the window crossing the breakpoint. The detail pane sits outside it, since it
/// belongs to the Journal rather than to the stack.
///
/// Plain `Navigator` rather than a router package — three tabs and a handful of
/// pushed screens is well inside what `Navigator` handles.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.initialSharedFilePath,
    this.sharedFileStream,
    this.initialWidgetUri,
    this.widgetClickStream,
    this.initialInviteUri,
    this.inviteLinkStream,
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

  /// Non-null only on the cold start that opened the app via an invitation
  /// link (`eatapp://join/<token>`). Resolved to a token, so a link that isn't
  /// ours is ignored rather than pushed.
  final Uri? initialInviteUri;

  /// The warm-start counterpart: an invitation link arriving while the app is
  /// already running.
  final Stream<Uri>? inviteLinkStream;

  /// The width at which the shell stops looking like a phone. Material's
  /// "expanded" window class, and comfortably above a phone in landscape.
  static const double twoPaneBreakpoint = 840;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  /// The one groups controller, read from [AppScope] once dependencies are
  /// established so the lifecycle and tab callbacks below can reach it without
  /// an inherited-widget lookup outside build.
  GroupsController? _groupsController;

  /// Which restaurant the detail pane is showing, on a wide window only. Null
  /// draws the "nothing selected" placeholder; on a phone the selection is the
  /// pushed route instead and this stays null.
  String? _selectedRestaurantId;

  StreamSubscription<String>? _sharedFiles;
  StreamSubscription<Uri?>? _widgetClicks;
  StreamSubscription<Uri>? _inviteLinks;

  /// Read from `MediaQuery` rather than a `LayoutBuilder` so the callbacks below
  /// can ask the same question the build method did.
  bool get _isTwoPane =>
      MediaQuery.sizeOf(context).width >= HomeShell.twoPaneBreakpoint;

  /// True only for the Journal, the one section the detail pane has anything to
  /// say about.
  bool get _showsDetailPane => _index == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groupsController = AppScope.of(context).groupsController;
  }

  @override
  void initState() {
    super.initState();
    // Coming back from the background is the moment the group's rows are most
    // likely stale: another member may have added a restaurant while we were
    // away. The observer turns that into a pull.
    WidgetsBinding.instance.addObserver(this);
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

    final Uri? initialInvite = widget.initialInviteUri;
    if (initialInvite != null) {
      // Same first-frame constraint as the cold-start import above.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openInviteLink(initialInvite),
      );
    }
    _inviteLinks = widget.inviteLinkStream?.listen(_openInviteLink);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharedFiles?.cancel();
    _widgetClicks?.cancel();
    _inviteLinks?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSelectedGroup();
    }
  }

  void _selectTab(int index) {
    if (index != _index) {
      setState(() => _index = index);
    }
    // Entering (or re-tapping) a scope-aware section refreshes the selected
    // group, so a restaurant another member added shows up without the user
    // having to do anything special. A no-op in Personal mode.
    if (_sectionReadsGroupScope(index)) {
      _syncSelectedGroup();
    }
  }

  /// The sections whose data the selected group scopes: the Journal and the
  /// Roulette. Groups and Settings read no group-scoped rows, so entering them
  /// triggers no pull.
  static bool _sectionReadsGroupScope(int index) => index == 0 || index == 1;

  /// Pulls the selected group's changes, if there is a group and a backend.
  /// [GroupsController.syncNow] owns the guard, so this is safe to fire on every
  /// tab change and every resume.
  void _syncSelectedGroup() {
    final GroupsController? groups = _groupsController;
    if (groups != null) {
      unawaited(groups.syncNow());
    }
  }

  /// Opens a restaurant, in whichever way the current window wants: the detail
  /// pane beside the Journal when there is room for two, a pushed route when
  /// there isn't.
  void _openRestaurant(RestaurantUiModel restaurant) =>
      _openRestaurantById(restaurant.id);

  void _openRestaurantById(String restaurantId) {
    if (_isTwoPane && _showsDetailPane) {
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
  /// Opens the join screen named by an invitation link. A link that isn't one of
  /// ours (or carries a malformed token) is ignored rather than pushed.
  void _openInviteLink(Uri? uri) {
    final String? token = uri == null ? null : inviteTokenFromUri(uri);
    if (!mounted || token == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => JoinScreen(initialToken: token),
      ),
    );
  }

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
      // card and the detail header would carry the same Hero tag — which a
      // flight rejects. Nothing needs to fly between them anyway: both are
      // already on screen.
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
          if (_showsDetailPane) ...<Widget>[
            const VerticalDivider(width: 1),
            Expanded(child: _detailPane()),
          ],
        ],
      ),
    );
  }

  /// Whether groups are available in this build (Supabase configured).
  bool get _canUseGroups => _groupsController?.canUseGroups ?? false;

  /// The four sections, stacked so their state survives a tab switch — and a
  /// window crossing the two-pane breakpoint.
  Widget _sections(AppLocalizations l10n) {
    // When groups are unavailable, skip that tab entirely.
    final List<Widget> sections = <Widget>[
      JournalScreen(
        onOpenRestaurant: _openRestaurant,
        onAddRestaurant: _pushEdit,
      ),
      RouletteScreen(onOpenRestaurant: _openRestaurant),
    ];
    if (_canUseGroups) {
      sections.add(const GroupsScreen());
    }
    sections.add(SettingsScreen(onViewStatistics: _pushStatistics));
    return IndexedStack(
      index: _index,
      children: sections,
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

  /// The phone shape's navigation bar. The destinations carry their label
  /// under the icon; the rail keeps its labels beside the icon. When groups are
  /// available there are four tabs; otherwise three.
  NavigationBar _bottomBar(AppLocalizations l10n) => NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: _navDestinations(l10n),
      );

  /// The rail's own copy of the same destinations — a rail takes a different type
  /// from the bottom bar, so the icons and labels have to be listed again.
  List<NavigationRailDestination> _railDestinations(AppLocalizations l10n) =>
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book_rounded),
          label: Text(l10n.navJournal),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.casino_outlined),
          selectedIcon: const Icon(Icons.casino_rounded),
          label: Text(l10n.navRoulette),
        ),
        if (_canUseGroups)
          NavigationRailDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: Text(l10n.navGroups),
          ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: Text(l10n.navSettings),
        ),
      ];

  /// The bottom-bar destinations. Groups is included when the backend is
  /// configured.
  List<NavigationDestination> _navDestinations(AppLocalizations l10n) =>
      <NavigationDestination>[
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book_rounded),
          label: l10n.navJournal,
        ),
        NavigationDestination(
          icon: const Icon(Icons.casino_outlined),
          selectedIcon: const Icon(Icons.casino_rounded),
          label: l10n.navRoulette,
        ),
        if (_canUseGroups)
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: l10n.navGroups,
          ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: l10n.navSettings,
        ),
      ];
}
