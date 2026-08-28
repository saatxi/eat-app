# Visual modernization plan

In progress. This is the working plan for the redesign pass started on
2026-08-28: three selectable colour schemes, a bottom navigation bar, two new
destinations, optional link columns in the data file, and a performance pass.

Inspired by Compose Samples' **Now in Android** (bottom bar with filled/outline
icon pairs, colourful topic chips) and **Reply** (navigation suite that becomes
a rail on large screens, colourful per-item accents).

Large-screen two-pane layout is deliberately still out of scope; see
[tablet-adaptive-layout-idea.md](tablet-adaptive-layout-idea.md). The
`NavigationSuiteScaffold` in Phase 5 gives the rail for free, but not the
list/detail split.

## Status

| Phase | | |
|---|---|---|
| 1 | Theme foundations — palettes, accents, typography | **Done** |
| 2 | Preferences (DataStore) and Settings screen | **Done** |
| 3 | Favourites | Not started |
| 4 | Website and Instagram links | **Done** |
| 5 | Bottom navigation | Not started |
| 6 | "What to eat" picker | Not started |
| 7 | Performance | Partly done |
| 8 | Usability and M3 Expressive | Not started |

At the last checkpoint: `test`, `assembleDebug` and `lint` all green, 128 unit
tests passing (up from 101), still JVM-only with no emulator.

## Why

- **The old palette had a real accessibility bug.** The `onXContainer` roles
  reused their family's tone 40 because tones 10/20/30/90 were never generated.
  `Sage40 #5B7B4A` on `Sage80 #C9D4B8` is about 2.9:1, below the 4.5:1 WCAG AA
  needs for normal text — visible in the selected cuisine filter chips and in
  the badge behind every list row's icon. Nothing caught it because nothing was
  checking.
- **The app looked monotonous.** `cuisineTint` spread 24 cuisines over three
  container roles (`ordinal % 3`), so a screenful of rows cycled through the
  same trio instead of reading varied.
- **Only 5 of the ~15 M3 type styles were defined**, so `bodyMedium` (every
  row's secondary line) and `headlineMedium` (the detail screen's
  `LargeTopAppBar`) silently fell back to the Material baseline.
- **No bottom bar, because there was nowhere to navigate**: the graph had two
  destinations, `list` and `detail/{id}`.
- **The detail screen was thin** — cuisine, address, rating, price, and nothing
  else. No way to reach a restaurant's website or Instagram, because the data
  didn't carry them.
- **A concrete performance problem**: `RestaurantUiModel` held
  `stars: List<Boolean>`, which marked the class unstable for Compose and made
  every row unskippable — any state change recomposed the whole list.

## Decisions

| Topic | Decision |
|---|---|
| Tabs | Restaurants · Favorites · What to eat · Settings |
| Colour | Three complete palettes, user-selectable in Settings |
| Typography | Bundled variable font + full M3 scale |
| Scope | Performance + M3 Expressive + Baseline Profile |
| Data | Optional `website` / `instagram` columns in the `.db` |
| CLAUDE.md | The "no emulator is ever required" rule is relaxed for the Baseline Profile module |

---

## Phase 1 — Theme foundations · Done

### Three palettes with complete tonal ramps

[Color.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/Color.kt) now
holds only the shared error tones. Each palette lives in
`ui/theme/palette/`: [SaffronPalette.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/palette/SaffronPalette.kt),
[GardenPalette.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/palette/GardenPalette.kt),
[IndigoPalette.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/palette/IndigoPalette.kt),
declaring tones through the types in
[Tones.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/Tones.kt).

**Saffron** (default — saffron orange + teal + plum)

```
Primary    10 #3A0B00  20 #5D1900  30 #862E0C  40 #B4471B  80 #FFB59B  90 #FFDBCF  95 #FFEDE7
Secondary  10 #002022  20 #003739  30 #004F52  40 #00696D  80 #4DDADF  90 #A8F0F3  95 #D2F8FA
Tertiary   10 #2E0B33  20 #46204A  30 #603663  40 #7A4E7E  80 #EBB5EE  90 #FFD7FB  95 #FFEBFB
Neutral     4 #0F0B09   6 #140F0D  10 #1F1613  12 #241A17  17 #302521  20 #372B27  22 #3C2F2B
           24 #413430  87 #E5DBD6  90 #EDE3DE  92 #F2E8E3  94 #F8EEE9  95 #FAF1EC  96 #FCF4EF
           98 #FFF8F6 100 #FFFFFF
NeutralVar 30 #53433C  50 #85736A  60 #A08D83  80 #D8C7BE  90 #F5E3DA
```

**Garden** (deep green + amber + blue-green)

```
Primary    10 #00210E  20 #00391C  30 #00522A  40 #226B3E  80 #8FD9A6  90 #ABF3C1  95 #C7FFD8
Secondary  10 #261A00  20 #402D00  30 #5C4200  40 #7A5900  80 #F3C03F  90 #FFDF95  95 #FFEFCE
Tertiary   10 #001F26  20 #00363F  30 #1E4D56  40 #38656E  80 #A0CFDA  90 #BCEBF6  95 #DDF6FB
Neutral     4 #060D08   6 #0A120C  10 #111811  12 #151C16  17 #202721  20 #252C26  22 #29302A
           24 #2E352F  87 #DCE4DC  90 #E4ECE3  92 #E9F1E8  94 #EFF6EE  95 #F2F9F0  96 #F4FBF2
           98 #F9FEF7 100 #FFFFFF
NeutralVar 30 #3F4A40  50 #6F7B70  60 #899589  80 #C0CCC0  90 #DCE8DB
```

**Indigo** (indigo + coral + sage)

```
Primary    10 #00105C  20 #182878  30 #313E90  40 #4A57A9  80 #B9C3FF  90 #DEE0FF  95 #F0EFFF
Secondary  10 #410004  20 #601A18  30 #7E2D2C  40 #9C4341  80 #FFB3AE  90 #FFDAD6  95 #FFEDEA
Tertiary   10 #092016  20 #1F352A  30 #354B40  40 #4C6357  80 #B2CCBD  90 #CEE9D8  95 #DCF7E6
Neutral     4 #08090E   6 #0D0E13  10 #121318  12 #16171C  17 #202126  20 #26272C  22 #2A2B30
           24 #2E2F35  87 #DCDCE3  90 #E4E4EB  92 #E9E9F0  94 #EFEFF6  95 #F2F1F9  96 #F5F4FB
           98 #FBF8FF 100 #FFFFFF
NeutralVar 30 #45464F  50 #767680  60 #90909A  80 #C6C6D0  90 #E2E1EC
```

The tone-to-role mapping is written **once** in
[PaletteSchemes.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/PaletteSchemes.kt),
rather than per scheme. That is what makes the old contrast bug
unreintroducible: an on-container is always the far end of its own ramp, stated
in one place. `onXContainer` is tone 10 in light and tone 90 in dark.

### Cuisine accents: 3 → 8

[CuisineAccents.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/CuisineAccents.kt)
defines `CuisineTint` and a `LocalCuisineAccents` static CompositionLocal
carrying eight accents, published by `EatAppTheme` for the active palette.
Light = container tone 90 / on tone 10; dark = container tone 30 / on tone 90.
`cuisineTint` in
[CuisineVisuals.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/common/CuisineVisuals.kt)
now indexes `ordinal % 8`; an unknown key still falls back to `surfaceVariant`,
so a newer data file never breaks an older app.

### Palette and mode selection

[Theme.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/Theme.kt)
exposes `AppPalette` (SAFFRON / GARDEN / INDIGO) and `ThemeMode`
(SYSTEM / LIGHT / DARK), with `EatAppTheme(palette, themeMode, content)`. Enum
names are what gets persisted, so they must not be renamed without a migration.
Both parameters default, so the existing `@Preview` composables were untouched.

### Typography

Outfit Variable (SIL OFL) bundled at `app/src/main/res/font/outfit.ttf`, ~110 KB,
licence in `app/licenses/OFL-Outfit.txt`. Weights come from
`FontVariation.Settings`, which needs API 26 — the project's `minSdk`.

Outfit carries display, headline and title; body and label stay on
`FontFamily.Default`. Deliberate: Outfit gives the app character at large
sizes, but at 12–16sp a system font the platform has already hinted for the
user's screen reads better. The full M3 scale is now spelled out in
[Type.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/Type.kt).

---

## Phase 2 — Preferences and Settings · Done

`androidx.datastore:datastore-preferences` and `androidx.core:core-splashscreen`
added to the version catalog;
[UserPreferencesRepository.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/prefs/UserPreferencesRepository.kt)
(interface + `UserPreferences`) and
[DataStoreUserPreferencesRepository.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/prefs/DataStoreUserPreferencesRepository.kt)
written and exposed as a third `by lazy` on
[EatApplication.kt](../app/src/main/kotlin/com/albertferran/eatapp/EatApplication.kt).
Every stored value is read back defensively: a renamed enum or a non-numeric id
degrades to the default rather than throwing, because the file outlives any one
version of the app. `formatRelativeTime` moved to
[ui/common/RelativeTime.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/common/RelativeTime.kt).

### Wiring `MainActivity`

[MainActivity.kt](../app/src/main/kotlin/com/albertferran/eatapp/MainActivity.kt)
calls `installSplashScreen()` before `super.onCreate`, reads
`UserPreferences?` into a `mutableStateOf` seeded `null`, and holds the splash
with `setKeepOnScreenCondition { preferences == null }` until the DataStore
flow's first emission — no `runBlocking`, so the startup metric Phase 7 will
measure stays honest. `EatAppTheme` is now called with the stored
palette/mode, falling back to `UserPreferences.Defaults` for the one frame
before that first emission (which the splash is covering anyway).

### `SettingsScreen` and `SettingsViewModel`

New `ui/settings/SettingsScreen.kt` +
[SettingsViewModel.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/settings/SettingsViewModel.kt).
The palette picker is three `Card`s, each built from `palette.tones.lightScheme()`
/ `darkScheme()` directly (not the currently-applied `MaterialTheme`, since two
of the three cards are never the active scheme) and resolved against the mode
actually in effect via the new `isDarkTheme(mode)` helper in
[Theme.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/Theme.kt) —
shared with `EatAppTheme` itself so the preview can't drift from what
selecting a palette actually produces. Mode selection reuses
`SingleChoiceSegmentedButtonRow`. Sync feedback (last-sync time, a sync
button, and the same `SyncMessage`-driven snackbar the list screen uses,
reusing that sealed interface) replaces what used to be the list screen's
"About" dialog; `about_version_template` gained a third `%3$s` slot for
`BuildConfig.GIT_COMMIT` alongside version name and code.

Not yet wired into navigation — `EatAppNavHost` still only has `list` and
`detail/{id}`. `SettingsScreen` becomes reachable once Phase 5 restructures
the graph around `NavigationSuiteScaffold`; until then it's covered by its
ViewModel test and a `@Preview`.

`SettingsViewModel` added to
[AppViewModelProvider.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/AppViewModelProvider.kt).

The overflow menu and the "About" `AlertDialog` are gone from
`RestaurantListScreen.kt`, along with the now-unused `list_action_more` /
`list_action_about` strings.

---

## Phase 3 — Favourites · Not started

**Where they live: DataStore, not Room.** [EatAppDatabase.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/local/EatAppDatabase.kt)
uses `fallbackToDestructiveMigration(dropAllTables = true)` — right for a cache
of a re-downloadable file, wrong for user data. Favourites are a tiny
`Set<Long>`; putting them in the cache database would mean either abandoning
that policy or standing up a second database with real migrations, and the size
doesn't justify it. `UserPreferences.favoriteIds` already exists.

Ids are stable: the reader preserves the source `.db`'s id verbatim
(`RestaurantDatabaseReader.kt`, `id = cursor.getLong(0)`), so a favourite
survives a sync. If the ids in the source file are ever renumbered, favourites
drift.

- `RestaurantUiModel.isFavorite` already exists, and `toUiModel(isFavorite)`
  already takes it — only the wiring is missing.
- `RestaurantListViewModel` combines the repository flow with
  `preferences.map { it.favoriteIds }`.
- `RestaurantRow` gains an `IconToggleButton` heart with haptic feedback.
  **Careful**: the row is collapsed into one accessibility node with
  `clearAndSetSemantics`, so the heart must sit *outside* that node to stay
  actionable under TalkBack.
- Same on the detail screen, as a `LargeTopAppBar` action.
- New `ui/favorites/FavoritesScreen.kt` + ViewModel, reusing `RestaurantRow`
  and `EmptyState`, with its own empty state.

---

## Phase 4 — Website and Instagram links · Done

### Optional columns

`REQUIRED_COLUMNS` in
[RestaurantDatabaseReader.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/RestaurantDatabaseReader.kt)
was **not** touched. Had `website` and `instagram` gone in there, the already
published `.db` would have stopped validating and users would have opened the
app to an empty list. They live in a separate `OPTIONAL_COLUMNS` instead.

The `PRAGMA table_info(restaurants)` that already ran says which are present,
and the `SELECT` projection is composed from those names. This is not SQL built
from the file's content: the literals come from our own constant and only
*which* to include depends on the file, so the security rule in
[CLAUDE.md](../CLAUDE.md) holds. Indices are resolved with `getColumnIndex`,
which returns -1 for an absent column.

### Validation

Both values end up in an `Intent.ACTION_VIEW`, so a hand-edited or hostile file
could otherwise hand the system a `javascript:`, `intent:` or `file:` URI.
[LinkValidation.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/LinkValidation.kt)
is a whitelist, and deliberately free of Android imports so it can be tested as
plain Kotlin:

- **`website`** — only `http` and `https`. A value with no scheme is read as
  `https://`, since data files tend to hold bare hosts. Anything else → null.
- **`instagram`** — the **handle**, not a URL, matched against
  `^@?[A-Za-z0-9._]{1,30}$` with the `@` stripped. The URL is built by the app,
  which makes scheme injection structurally impossible.

An invalid value degrades to null with a logged warning; it does **not**
invalidate the file. Same graceful degradation an unrecognised cuisine key
gets — one bad cell shouldn't cost the user every restaurant.

### Propagation

`Restaurant` gained `website` / `instagram` (not part of `searchText`);
`EatAppDatabase` went to version 5, which the existing destructive migration
handles by itself. `RestaurantUiModel` carries both plus a `hasLinks`
convenience. The detail screen draws a "Links" card — omitted entirely when
both are null — reusing the existing clickable `InfoRow`, with
`Icons.Outlined.Language` and `Icons.Outlined.AlternateEmail`.

The `https` Instagram URL deep-links into the Instagram app on its own when
installed, so no `instagram://` scheme and no `<queries>` manifest entry are
needed.

**Also fixed here**: the address row's `geo:` intent was unguarded, so a device
with no maps app would have crashed the detail screen. Both it and the links
now go through one `Context.openUri` helper that catches
`ActivityNotFoundException` and shows a toast.

Data authors: the two columns are documented in the
[README](../README.md#the-optional-link-columns), with the `ALTER TABLE` to add
them to an existing file.

---

## Phase 5 — Bottom navigation · Not started

New `navigation/TopLevelDestination.kt`:

```kotlin
enum class TopLevelDestination(
    val route: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector,
    @StringRes val labelRes: Int
) {
    LIST(     "list",      Icons.Filled.Restaurant, Icons.Outlined.Restaurant,     R.string.nav_restaurants),
    FAVORITES("favorites", Icons.Filled.Favorite,   Icons.Outlined.FavoriteBorder, R.string.nav_favorites),
    ROULETTE( "roulette",  Icons.Filled.Casino,     Icons.Outlined.Casino,         R.string.nav_roulette),
    SETTINGS( "settings",  Icons.Filled.Settings,   Icons.Outlined.Settings,       R.string.nav_settings)
}
```

The filled/outline pair by selection state is Now in Android's pattern. Every
icon is already in `material-icons-extended`.

Restructuring [EatAppNavHost.kt](../app/src/main/kotlin/com/albertferran/eatapp/navigation/EatAppNavHost.kt):

- Wrap the `NavHost` in **`NavigationSuiteScaffold`**
  (`androidx.compose.material3:material3-adaptive-navigation-suite`, already in
  the catalog) — bottom bar on a phone, navigation rail on a tablet, which is
  what Reply does, with no extra code.
- Keep `SharedTransitionLayout` **outside** the scaffold so the list→detail
  badge transition keeps working.
- Hide the bar on detail: `navigationSuiteType = NavigationSuiteType.None` when
  the route from `currentBackStackEntryAsState()` is the detail one.
- Tab navigation with `launchSingleTop = true`, `restoreState = true` and
  `popUpTo(graph.findStartDestination().id) { saveState = true }`, so each tab
  keeps its scroll position and filters.

---

## Phase 6 — "What to eat" · Not started

New `ui/roulette/RouletteScreen.kt` + `RouletteViewModel`:

- Picks at random among the restaurants passing the current filters, reusing
  `repository.observeFiltered(...)` unchanged — no new query.
- `Random` is **injected via the constructor** (defaulting to `Random.Default`)
  so the test can seed it and be deterministic.
- Its own light filters: minimum-rating chips and a "favourites only" toggle.
- A large card with the cuisine icon, a shuffle animation (`AnimatedContent` +
  `Modifier.graphicsLayer`), haptic feedback on landing, a "try again" button,
  and tap to open the detail screen.
- Empty state when nothing matches.

---

## Phase 7 — Performance · Partly done

**Done**: `RestaurantUiModel` no longer holds `stars: List<Boolean>`. Every
property is a primitive or a String, so the class is stable and rows are
skippable; the stars are computed at draw time from `rating`, which was already
in the model.

**Remaining**:

1. `contentType` and `animateItem()` on the `LazyColumn` items (they already
   have `key`).
2. `pluralStringResource` instead of `context.resources.getQuantityString`
   (`RestaurantListScreen.kt:140`) — also clears the pending
   `LocalContextResourcesRead` lint warning.
3. Give `EmptyState` (`RestaurantListScreen.kt:441`) a
   `modifier: Modifier = Modifier` first optional parameter — clears
   `ModifierParameter`.
4. Compose compiler metrics behind an optional Gradle property
   (`eatapp.composeMetrics=true`), so the stability claim in point 1 can be
   verified rather than assumed.
5. **Baseline Profile**: the `androidx.baselineprofile` plugin and a new
   `:baselineprofile` module (`com.android.test`) with a
   `BaselineProfileGenerator` (startup + list scroll + open detail) and a
   `StartupBenchmark`. The generated profile is committed at
   `app/src/main/baseline-prof.txt`.

### The CLAUDE.md change this needs

[CLAUDE.md](../CLAUDE.md) currently says no emulator is ever required and that
`app/src/androidTest` is empty on purpose. The rule becomes:

> Unit tests (`./gradlew test`) stay **100% JVM** — Robolectric, no emulator,
> and that does not change. What is now allowed are instrumented tests in the
> `:baselineprofile` module (`com.android.test`), which run only on demand via
> `:baselineprofile:...AndroidTest` and never from `./gradlew test`.

CI is unaffected: it runs `test`, `assembleDebug` and `lint`, none of which
pull in instrumented tests. Still worth confirming the workflow doesn't break
when the new module is configured.

---

## Phase 8 — Usability and M3 Expressive · Not started

- **Pinned filters.** `FilterSection` is currently the first `item` of the
  `LazyColumn` and scrolls away. Move it to a fixed, collapsible row under the
  search field, with a badge counting active filters (`hasActiveFilter` already
  exists on the ViewModel).
- **`ButtonGroup`** for the name/rating sort instead of the current
  `DropdownMenu` — one tap fewer.
- **Shape morphing** on the cuisine badge with `MaterialShapes` +
  `androidx.graphics:graphics-shapes` (already in the catalog): the circle
  morphs as it travels from row to detail header, over the `sharedBounds`
  already in
  [SharedTransition.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/common/SharedTransition.kt).
- **Predictive back**: `android:enableOnBackInvokedCallback="true"` in the
  manifest.
- **Haptics** on favouriting and on the roulette landing.

---

## Strings

All of these are already added, in both `values/` and `values-es/` (Spanish
plurals need the extra `many` quantity, as elsewhere). Lint reports them as
`UnusedResources` until the screens that consume them exist — expected.

`nav_restaurants` · `nav_favorites` · `nav_roulette` · `nav_settings` ·
`favorites_title` · `favorites_empty_title` · `favorites_empty_body` ·
`action_add_favorite` · `action_remove_favorite` · `roulette_title` ·
`roulette_prompt` · `roulette_action_pick` · `roulette_action_again` ·
`roulette_only_favorites` · `roulette_empty_title` · `roulette_empty_body` ·
`settings_title` · `settings_section_appearance` · `settings_palette` ·
`settings_theme_mode` · `theme_mode_system|light|dark` ·
`palette_saffron|garden|indigo` · `settings_section_data` ·
`settings_section_about` · `detail_section_links` · `detail_link_website` ·
`detail_link_instagram` · `detail_link_handle_format` · `detail_link_failed`

The 24 cuisine keys were not touched.

---

## Tests

Everything stays in `app/src/test/kotlin`, JUnit4 with hand-written fakes and no
mocking library.

**Written**:

- **`ColorSchemeContrastTest`** — the most valuable one. Walks all three
  palettes × light/dark and asserts ≥4.5:1 on every `onX`/`X` and
  `onXContainer`/`XContainer` pair, plus all eight accents and `onSurface` over
  each surface tier. This is what stops the old `onSecondaryContainer` bug from
  coming back. Pure maths on `Color` values — no Compose runtime, no
  Robolectric.
- **`LinkValidationTest`** — the whitelist, with the rejection cases weighted
  more heavily than the happy path.
- **`RestaurantDatabaseReaderTest`** (extended) — a `.db` *without* the new
  columns still reads (the regression protecting the published file), with them
  the values arrive, and an unsafe value nulls the field without failing the
  file.
- **`RestaurantUiModelTest`** (updated) — `stars` out; links, `hasLinks` and
  `isFavorite` in.
- **`SettingsViewModelTest`** — palette/mode changes write through to a fake
  `UserPreferencesRepository` and land back in `uiState`; `syncNow` against a
  fake `DatabaseSyncManager` for both the success and failure paths.

**Still to write**:

- `UserPreferencesRepositoryTest` — round-trip of palette, mode and favourite
  toggling.
- `FavoritesViewModelTest` — using `FakeRestaurantRepository`, which already
  exists inside `RestaurantListViewModelTest.kt`.
- `RouletteViewModelTest` — seeded `Random`, deterministic selection, filters
  respected, empty case.
- Update `RestaurantListViewModelTest` for the new state fields.
- Consider `androidx.compose.ui:ui-test-junit4` as a **`testImplementation`**:
  `createComposeRule()` runs under Robolectric on the JVM, so composable
  coverage is possible without an emulator and without touching `androidTest` —
  the bottom bar marking the right tab, hiding on detail, and the links card
  disappearing when both fields are null.

`CuisineTest` is untouched: no cuisine keys were added or removed.

## Verification

```
gradlew.bat test                 # JVM unit tests, no emulator
gradlew.bat assembleDebug
gradlew.bat lint
gradlew.bat :app:printVersionInfo
```

Beyond that:

1. **Previews** — add a list and detail preview per palette (3 × light/dark) to
   review all three schemes at a glance in Android Studio without installing
   anything.
2. **On device** — change palette and mode in Settings and confirm they survive
   killing the app; favourite something and sync to confirm it survives; rotate
   on a tablet and see the bottom bar become a rail; open detail and confirm the
   bar disappears and the badge transition is intact.
3. **Links** — sync against the **current `.db`, without the new columns**, and
   confirm the app still loads and no links card appears. Then, with a local
   file that has them, confirm the website and `@handle` open, and that a row
   with `website = 'javascript:alert(1)'` simply draws no link.
4. **Performance** — `eatapp.composeMetrics=true` to confirm
   `RestaurantUiModel` reports as `stable` and `RestaurantRow` as `skippable`;
   then the macrobenchmark on an emulator for before/after startup.

## Risks

- **`ButtonGroup` and `MaterialShapes`** are still experimental M3 Expressive
  APIs — they need `@OptIn` and can change signature when the BOM moves.
- **APK size** — Outfit adds ~110 KB. R8 already shrinks resources, and the
  font is the only heavy new one.
- **Baseline Profile** — needs an emulator to *generate* the profile; see
  Phase 7.
- **`.db` compatibility** — the new columns are optional on purpose, so the
  currently published file keeps validating untouched.
