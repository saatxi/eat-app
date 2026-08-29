# Idea: adaptive two-pane layout for large screens

Not implemented. This documents a future option raised while redesigning the
list and detail screens (inspired by Now in Android / Compose Samples), scoped
out of that pass to keep it phone-only.

## What it would look like

On a tablet, unfolded foldable, or Chromebook window, show the restaurant
list and the selected restaurant's detail side by side instead of navigating
between two full screens — the pattern Compose Samples' **Reply** app uses
for its email list/detail, and that Now in Android uses for its topic and
bookmark screens.

On a phone-width window, behavior stays exactly as it is today: list, then
navigate to detail, then back.

## What it would take

- **Width detection**: `androidx.compose.material3.windowsizeclass.WindowSizeClass`
  (or the newer `androidx.window.core.layout.WindowSizeClass`) to know whether
  the current window is compact, medium, or expanded.
- **New dependency**: `androidx.compose.material3.adaptive:adaptive` +
  `adaptive-layout` + `adaptive-navigation` (the `ListDetailPaneScaffold` /
  `NavigableListDetailPaneScaffold` APIs Reply is built on). Not currently a
  project dependency — would need discussion before adding, per this repo's
  "don't add a dependency without discussing it" convention.
- **Navigation** ([`EatAppNavHost.kt`](../app/src/main/kotlin/com/saatxi/eatapp/navigation/EatAppNavHost.kt)):
  the current two-route stack (`list`, `detail/{restaurantId}`) would need to
  become pane-aware — on expanded width, "navigating to detail" means
  selecting a restaurant in the list pane and rendering `RestaurantDetailScreen`
  in the adjacent detail pane, rather than pushing a new backstack entry.
- **ViewModels**: `RestaurantListViewModel` would need to track a "selected
  restaurant id" (nullable) instead of always deferring to navigation, so the
  detail pane can react to a selection without a route change.
  `RestaurantDetailScreen`/`RestaurantDetailViewModel` stay mostly as they are —
  they'd just be hosted inside the second pane instead of a full-screen
  destination.
- **Empty second pane**: on expanded width with nothing selected, the detail
  pane needs its own placeholder state (Reply and NiA both show a light
  "select an item" illustration/message here).

## Why it's not in this pass

The user asked to keep this redesign phone-only — EatApp is currently used as
a phone app, and adding a new dependency plus a real navigation-model change
is a bigger, separate decision than the visual/layout polish covered in the
rest of this UX pass. Worth revisiting if EatApp ever gets meaningful tablet
or Chromebook usage.
