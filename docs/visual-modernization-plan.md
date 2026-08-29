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
| 3 | Favourites | **Done** |
| 4 | Website and Instagram links | **Done** |
| 5 | Bottom navigation | **Done** |
| 6 | "What to eat" picker | **Done** |
| 7 | Performance | **Done** |
| 8 | Usability and M3 Expressive | In progress |

At the last checkpoint: `test`, `assembleDebug` and `lint` all green, 145 unit
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

[Color.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Color.kt) now
holds only the shared error tones. Each palette lives in
`ui/theme/palette/`: [SaffronPalette.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/palette/SaffronPalette.kt),
[GardenPalette.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/palette/GardenPalette.kt),
[IndigoPalette.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/palette/IndigoPalette.kt),
declaring tones through the types in
[Tones.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Tones.kt).

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
[PaletteSchemes.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/PaletteSchemes.kt),
rather than per scheme. That is what makes the old contrast bug
unreintroducible: an on-container is always the far end of its own ramp, stated
in one place. `onXContainer` is tone 10 in light and tone 90 in dark.

### Cuisine accents: 3 → 8

[CuisineAccents.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/CuisineAccents.kt)
defines `CuisineTint` and a `LocalCuisineAccents` static CompositionLocal
carrying eight accents, published by `EatAppTheme` for the active palette.
Light = container tone 90 / on tone 10; dark = container tone 30 / on tone 90.
`cuisineTint` in
[CuisineVisuals.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/CuisineVisuals.kt)
now indexes `ordinal % 8`; an unknown key still falls back to `surfaceVariant`,
so a newer data file never breaks an older app.

### Palette and mode selection

[Theme.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Theme.kt)
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
[Type.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Type.kt).

---

## Phase 2 — Preferences and Settings · Done

`androidx.datastore:datastore-preferences` and `androidx.core:core-splashscreen`
added to the version catalog;
[UserPreferencesRepository.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/prefs/UserPreferencesRepository.kt)
(interface + `UserPreferences`) and
[DataStoreUserPreferencesRepository.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/prefs/DataStoreUserPreferencesRepository.kt)
written and exposed as a third `by lazy` on
[EatApplication.kt](../app/src/main/kotlin/com/saatxi/eatapp/EatApplication.kt).
Every stored value is read back defensively: a renamed enum or a non-numeric id
degrades to the default rather than throwing, because the file outlives any one
version of the app. `formatRelativeTime` moved to
[ui/common/RelativeTime.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/RelativeTime.kt).

### Wiring `MainActivity`

[MainActivity.kt](../app/src/main/kotlin/com/saatxi/eatapp/MainActivity.kt)
calls `installSplashScreen()` before `super.onCreate`, reads
`UserPreferences?` into a `mutableStateOf` seeded `null`, and holds the splash
with `setKeepOnScreenCondition { preferences == null }` until the DataStore
flow's first emission — no `runBlocking`, so the startup metric Phase 7 will
measure stays honest. `EatAppTheme` is now called with the stored
palette/mode, falling back to `UserPreferences.Defaults` for the one frame
before that first emission (which the splash is covering anyway).

### `SettingsScreen` and `SettingsViewModel`

New `ui/settings/SettingsScreen.kt` +
[SettingsViewModel.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/settings/SettingsViewModel.kt).
The palette picker is three `Card`s, each built from `palette.tones.lightScheme()`
/ `darkScheme()` directly (not the currently-applied `MaterialTheme`, since two
of the three cards are never the active scheme) and resolved against the mode
actually in effect via the new `isDarkTheme(mode)` helper in
[Theme.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Theme.kt) —
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
[AppViewModelProvider.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/AppViewModelProvider.kt).

The overflow menu and the "About" `AlertDialog` are gone from
`RestaurantListScreen.kt`, along with the now-unused `list_action_more` /
`list_action_about` strings.

---

## Phase 3 — Favourites · Done

**Where they live: DataStore, not Room.** [EatAppDatabase.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/local/EatAppDatabase.kt)
uses `fallbackToDestructiveMigration(dropAllTables = true)` — right for a cache
of a re-downloadable file, wrong for user data. Favourites are a tiny
`Set<Long>`; putting them in the cache database would mean either abandoning
that policy or standing up a second database with real migrations, and the size
doesn't justify it. `UserPreferences.favoriteIds` already existed from Phase 2.

Ids are stable: the reader preserves the source `.db`'s id verbatim
(`RestaurantDatabaseReader.kt`, `id = cursor.getLong(0)`), so a favourite
survives a sync. If the ids in the source file are ever renumbered, favourites
drift.

- `RestaurantListViewModel` gained a `UserPreferencesRepository` constructor
  parameter. A separate `restaurantsWithFavorites` flow combines the filtered
  restaurant stream with `preferences.map { it.favoriteIds }` before feeding
  the outer `uiState` combine — kept as its own `combine()` rather than adding
  a sixth flow to the existing one, which would have dropped it out of
  kotlinx.coroutines' typed 5-flow overload and into the untyped vararg one.
  `onFavoriteToggle(id)` writes through to the repository.
- `RestaurantRow` (`RestaurantListScreen.kt`) gained an `onFavoriteToggle`
  parameter and now draws the heart in a `Box` **alongside** the `Card`, not
  inside it: the card's `clearAndSetSemantics` collapses its whole subtree into
  one accessibility node, which would otherwise swallow the heart's own toggle
  semantics and leave it unreachable under TalkBack. The card's content row
  gained 44dp of extra end padding so the overlaid heart (top-end corner)
  doesn't sit on top of the rating/price column. `RestaurantRow` and
  `EmptyState` are now `internal` instead of `private`, so `FavoritesScreen`
  can reuse them.
- `RestaurantDetailViewModel` gained the same `UserPreferencesRepository`
  parameter and combines `observeById(id)` with `favoriteIds` the same way.
  `DetailTopBar` gained a leading `IconButton` favourite toggle ahead of the
  cuisine badge in its actions row.
- Both toggles perform `HapticFeedbackType.LongPress` — the one haptic type
  guaranteed present across Compose UI versions, rather than guessing at the
  newer `ToggleOn`/`ToggleOff` constants sight-unseen against a BOM this build
  couldn't inspect offline.
- New `ui/favorites/FavoritesScreen.kt` + `FavoritesViewModel.kt`. No new DAO
  query: `FavoritesViewModel` reuses `repository.observeFiltered(null, null,
  null)` unchanged and filters to `favoriteIds` in memory, the same "no new
  query" approach Roulette (Phase 6) uses for its own filters. Its own empty
  state (`favorites_empty_title` / `_body`) covers the no-favourites case.
- `AppViewModelProvider` wires all of the above through `EatApplication`,
  which already exposed both `repository` and `userPreferences`.

---

## Phase 4 — Website and Instagram links · Done

### Optional columns

`REQUIRED_COLUMNS` in
[RestaurantDatabaseReader.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/sync/RestaurantDatabaseReader.kt)
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
[LinkValidation.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/sync/LinkValidation.kt)
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

## Phase 5 — Bottom navigation · Done

New [navigation/TopLevelDestination.kt](../app/src/main/kotlin/com/saatxi/eatapp/navigation/TopLevelDestination.kt),
exactly as planned:

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
icon was already in `material-icons-extended`, and both that dependency and
`material3-adaptive-navigation-suite` turned out to already be wired into
`app/build.gradle.kts` from Phase 1 — no dependency changes needed.

[EatAppNavHost.kt](../app/src/main/kotlin/com/saatxi/eatapp/navigation/EatAppNavHost.kt)
restructured:

- The `NavHost` is now wrapped in **`NavigationSuiteScaffold`**: bottom bar on
  a phone, navigation rail on a tablet, with no extra code — its `layoutType`
  defaults to `NavigationSuiteScaffoldDefaults.calculateFromAdaptiveInfo(...)`,
  which the "hide on detail" branch below has to name explicitly rather than
  omit, since a Kotlin default-parameter expression can't be reused across two
  call sites without repeating it. `currentWindowAdaptiveInfoV2()` is used
  rather than the older `currentWindowAdaptiveInfo()` the IDE's own
  autocomplete reaches for first, which is deprecated in this BOM in favour of
  the V2 overload (L/XL window size class support).
- `SharedTransitionLayout` stays **outside** the scaffold, so the list→detail
  badge transition keeps working.
- The bar hides on detail: `layoutType = NavigationSuiteType.None` when
  `currentBackStackEntryAsState().value?.destination?.route == Routes.DETAIL`.
- Tab navigation uses `launchSingleTop = true`, `restoreState = true` and
  `popUpTo(graph.findStartDestination().id) { saveState = true }`, so each tab
  keeps its own scroll position and filters across visits.
- `SettingsScreen` — built in Phase 2 but never reachable — is now the
  `SETTINGS` tab's destination.

---

## Phase 6 — "What to eat" · Done

New [ui/roulette/RouletteViewModel.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/roulette/RouletteViewModel.kt)
+ [RouletteScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/roulette/RouletteScreen.kt):

- Picks at random among the restaurants passing this screen's own filters,
  reusing `repository.observeFiltered(...)` unchanged — no new query. A
  favourites-only filter narrows the candidates in memory afterwards, the same
  approach Favourites (Phase 3) uses.
- `Random` is **injected via the constructor** (defaulting to `Random.Default`),
  so `RouletteViewModelTest` seeds it (`Random(42)`) and asserts two
  identically-seeded ViewModels against identical data land on the same pick.
- Its own light filters: minimum-rating chips (`2+`…`5+`, same reasoning as
  the list screen — every synced restaurant already rates at least 1) and a
  "favourites only" `FilterChip`.
- `RouletteUiState.pickCount` increments on every `pick()`, independent of
  whether the picked restaurant's identity actually changed — needed because
  chance can land on the same restaurant twice in a row, and the shuffle
  animation should still play. A `picked` that falls out of the candidate pool
  after a filter changes is cleared back to the "pick one" prompt rather than
  left showing a restaurant that no longer matches.
- A large `RouletteResultCard` (cuisine icon, name, cuisine label, star rating,
  price chip, address) with a shuffle effect: `AnimatedContent` cross-fades the
  card content on an actual pick change, while a separate `Animatable`-driven
  `Modifier.graphicsLayer { rotationY = ... }` spins the card a full turn on
  every `pick()` regardless — a face-on card flip that still reads as "shuffled"
  even when the outcome repeats. Haptic feedback (`HapticFeedbackType.LongPress`)
  fires when the pick button is pressed. Tapping the result card opens its
  detail screen.
- `roulette_empty_title` / `_body` empty state when the current filters match
  nothing.

---

## Phase 7 — Performance · Done

**Done**: `RestaurantUiModel` no longer holds `stars: List<Boolean>`. Every
property is a primitive or a String, so the class is stable and rows are
skippable; the stars are computed at draw time from `rating`, which was already
in the model.

**Also done**: Compose compiler metrics behind an optional Gradle property.
`app/build.gradle.kts` adds a `composeCompiler {}` block, gated on
`-Peatapp.composeMetrics=true`, that points `metricsDestination` and
`reportsDestination` at `build/compose_metrics/`. Verified the point-1 claim
rather than just assuming it: `gradlew.bat :app:compileDebugKotlin
-Peatapp.composeMetrics=true` produces `app-classes.txt` showing
`stable class ...ui.model.RestaurantUiModel` with every property `stable`, and
`app-composables.csv` showing `RestaurantRow` as `composable=1, skippable=1,
restartable=1`. The report only reflects files Kotlin actually recompiles in
that invocation, so a metrics run after an unrelated no-op build can come back
thin — force a real recompile (e.g. add `--rerun` on `compileDebugKotlin`) if
that happens.

**Also done**: `contentType` and `animateItem()` on both `LazyColumn`s
(`RestaurantListScreen.kt`'s list and `FavoritesScreen.kt`'s) — they already
had `key`. Each `item`/`items` call now tags a `contentType` (`"filters"`,
`"empty"`, `"header"`, `"restaurant"`) so the layout only recycles a
composed slot against another item of the same shape, and every item's root
composable carries `Modifier.animateItem()` so insertions, removals and
reorders (a filter narrowing the list, a favourite toggle removing a row from
`FavoritesScreen`) animate instead of jump-cutting. This needed two small
signature additions: `FilterSection` and `RestaurantRow` (`RestaurantRow` is
also called directly from `FavoritesScreen.kt`) neither took a `Modifier`
before — both now do, `modifier: Modifier = Modifier`, applied to each one's
outermost layout, which is what `animateItem()` needs a stable modifier chain
on to work at the call site rather than buried inside.

**Also done**: `pluralStringResource` instead of `context.resources.getQuantityString`
for the sync-result snackbar text. The call site is a `LaunchedEffect`, whose
block is a plain suspend lambda rather than `@Composable`, so
`pluralStringResource` (like `stringResource`) can't be called from inside it
directly — the message text is now resolved in the composable body itself,
right before the effect, keyed the same way, and the effect reads the
already-resolved string. Turned out the identical pattern existed twice, not
once as the plan below assumed: `RestaurantListScreen.kt`'s sync snackbar and
`SettingsScreen.kt`'s (its "Same pattern as the list screen's sync feedback"
comment was correct about the code, just not about lint already catching
both copies). Both are fixed the same way; `SettingsScreen.kt` keeps its
`LocalContext.current` since `RestaurantDatabaseSyncManager.getLastSyncTime(context)`
elsewhere in that file still needs it. This clears the `LocalContextResourcesRead`
lint warning (`gradlew.bat lint` now reports zero occurrences, confirmed from
the SARIF output).

**Also done**: `EmptyState`'s (`RestaurantListScreen.kt`) `modifier` default
changed from `Modifier.fillMaxSize()` to a bare `Modifier`, which is what
`ModifierParameter` actually wants — an optional `Modifier` parameter should
default to the no-op `Modifier`, not bake in a specific layout behaviour the
caller might not want. All six call sites that had been relying on that
default now pass `modifier = Modifier.fillMaxSize()` explicitly instead, so
behaviour is unchanged: the two in `RestaurantListScreen.kt`'s screen body and
its two `@Preview`s, and one each in `FavoritesScreen.kt` and
`RouletteScreen.kt`. `gradlew.bat lint` confirms zero `ModifierParameter`
occurrences.

**Also done**: the `:baselineprofile` module (`com.android.test`,
`androidx.baselineprofile` plugin) — see the [README](../README.md#baseline-profile)
for how to run it — and the profile itself has now actually been generated on
a connected physical device (Gradle reported it as `CPH2557 - 15`) via
`gradlew.bat :app:generateBaselineProfile`, landing at
`app/src/release/generated/baselineProfiles/baseline-prof.txt` (~8,570 rules).
**Not** `app/src/main/baseline-prof.txt` as originally planned below and as
this doc first said — that was wrong, corrected once an actual run showed
where the plugin puts it for a project with no product flavors. The `Task
:app:copyReleaseBaselineProfileIntoSrc` log line names the real destination
directly.

That path tripped a second, unrelated latent bug: `.gitignore`'s `**/release`
rule (added for the real `app/release/` AGP APK-output directory) also
matched `app/src/release/`, silently swallowing the profile. Fixed with a
narrow `!app/src/release/` exception right after that rule — `app/release/`
stays ignored, `app/src/release/` doesn't.

The run also logged `No startup profile rules were generated ... because
there are no instrumentation test with baseline profile rule, which specify
includeInStartupProfile = true`. That's `BaselineProfileGenerator.collect()`'s
`includeInStartupProfile` parameter (default `false`) — an even more targeted
subset for just the startup path. Left off for now; worth an intentional
on/off decision later rather than defaulting it by accident.

`StartupBenchmark`'s two tests correctly `SKIPPED` during that run (they're
gated to the `benchmarkRelease` variant via the plugin's own manifest-injected
`enabledRules` flag; profile *collection* runs under `release`/`nonMinifiedRelease`)
— confirms the variant-gating both test classes rely on to safely coexist in
one module actually works, not just compiles.

`StartupBenchmark` itself was then run with `gradlew.bat :baselineprofile:connectedBenchmarkReleaseAndroidTest`
(and, correspondingly, `BaselineProfileGenerator.generate` `SKIPPED` this
time — the same gating in reverse). First attempt failed with `ERRORS (not
suppressed): DEVICE-MIRRORING` — Android Studio's "Running Devices" panel was
mirroring the phone's screen, which adds rendering overhead the macrobenchmark
tooling refuses to measure through, by design (there's a
`suppressErrors`/`"DEVICE-MIRRORING"` instrumentation-runner argument to force
past it, deliberately not used here since the whole point is accurate
numbers, not a green checkmark). Stopping the mirroring session and rerunning
passed cleanly. Real numbers, OPPO CPH2557 / Android 15 (API 35), 5 iterations
each, `timeToInitialDisplayMs`:

| | No profile (`CompilationMode.None()`) | With profile (`CompilationMode.Partial()`) |
|---|---|---|
| Median | 753.8 ms | 654.1 ms |
| Min – max | 715.0 – 931.8 ms | 613.0 – 708.6 ms |

**~13% faster cold start** (99.7 ms off the median). Raw data:
`baselineprofile/build/outputs/connected_android_test_additional_output/benchmarkRelease/connected/CPH2557 - 15/com.saatxi.eatapp.baselineprofile-benchmarkData.json`
(gitignored build output, not committed).

What's in the module: [`BaselineProfileGenerator.kt`](../baselineprofile/src/main/kotlin/com/saatxi/eatapp/baselineprofile/BaselineProfileGenerator.kt)
(cold start, a list fling, opening a restaurant's detail, back) and
[`StartupBenchmark.kt`](../baselineprofile/src/main/kotlin/com/saatxi/eatapp/baselineprofile/StartupBenchmark.kt)
(cold-start `StartupTimingMetric`, once with `CompilationMode.None()` and once
with `CompilationMode.Partial()`, for the before/after). `app/build.gradle.kts`
gained the `androidx.baselineprofile` plugin, `implementation(libs.androidx.profileinstaller)`
(installs the shipped profile at APK-install time) and
`baselineProfile(project(":baselineprofile"))`.

Two surprises versus the original plan, both discovered by actually running
Gradle rather than assuming:

- **Plugin version**: `androidx.baselineprofile` 1.4.1 (the latest *stable*
  release at the time) fails applying to `:app` on this project's AGP 9.3.2
  with `Module :app is not a supported android module` — 1.4.1 predates AGP 9
  and can't recognize its extension types. `1.5.0-rc02` (the newest available,
  matching AGP 9.3.2's own recency) applies cleanly. Worth re-checking for a
  stable 1.5.x once one ships.
- **No manual "benchmark" build type needed**: older Baseline Profile
  tutorials have you hand-write a `benchmark` build type in both `:app` and
  `:baselineprofile` (`initWith(release)`, debuggable, `matchingFallbacks`).
  Doing that here produced a duplicated/ambiguous `assembleBenchmarkBenchmark`
  task — plugin 1.5.0-rc02 already auto-creates `benchmarkRelease` and
  `nonMinifiedRelease` variants on both modules by itself. The manual build
  type was removed; the plugin's defaults are what's committed.

Verified along the way: `gradlew.bat :baselineprofile:compileBenchmarkReleaseSources
:baselineprofile:compileNonMinifiedReleaseSources` (both generator and
benchmark classes compile, before a device was involved), and
`gradlew.bat test assembleDebug lint --no-daemon` — the exact command CI runs
— confirming the new module doesn't change CI's outcome:
`:baselineprofile:test` runs as a harmless no-op, and it has no `assembleDebug`
or `lint` task at all, so root-level invocation skips it silently, exactly as
planned below. `gradlew.bat :app:assembleRelease` was run twice: once before
the profile existed (accepted the plugin wiring, `compileReleaseArtProfile`
just produced an empty profile) and once after
(`app/build/intermediates/r8_art_profile/release/minifyReleaseWithR8/baseline-prof.txt`
now has 9,808 R8-remapped rules, and `app/release/baselineProfiles/{0,1}/`
carries the packaged `.dm` files) — confirming the real profile actually flows
through R8 and into the APK, not just that the plugin wiring compiles.

**Still outstanding**: commit `app/src/release/generated/baselineProfiles/baseline-prof.txt`
— currently untracked (`.gitignore`'s new exception unblocked it, but nothing
has staged/committed it yet). That's the only remaining step; the profile is
generated, verified end-to-end into a release APK, and its startup benefit is
measured.

### The CLAUDE.md change this needed

[CLAUDE.md](../CLAUDE.md) said no emulator is ever required and that
`app/src/androidTest` is empty on purpose. Applied, in the "Tests" bullet:
unit tests (`./gradlew test`) stay 100% JVM, unchanged; instrumented tests in
the `:baselineprofile` module are now allowed, running only on demand via
`:baselineprofile:...AndroidTest` tasks (or the `:app:generateBaselineProfile`
umbrella task), never from `./gradlew test`.

CI is unaffected, confirmed above by running its exact command locally: it
runs `test`, `assembleDebug` and `lint`, none of which pull in instrumented
tests.

---

## Phase 8 — Usability and M3 Expressive · In progress

### `ButtonGroup` and `MaterialShapes` don't exist yet on a stable BOM

Both were planned against material3's M3 Expressive surface. Checked before
writing any code: `androidx.compose.material3:material3` resolves to **1.4.0**
under `composeBom = "2026.08.00"` (confirmed via `gradlew.bat :app:dependencies
--configuration debugRuntimeClasspath`), and neither `ButtonGroup` nor
`MaterialShapes` exists in that jar — both only appear starting at
`1.5.0-alpha01` (checked against the actual `material3-android-1.4.0.aar`
classes, not just changelogs). Per Google's `maven-metadata.xml`, **1.5.0's
latest version is still `1.5.0-alpha27` — no stable release exists yet.** The
Risks section below already anticipated needing `@OptIn` for these and that
they "can change signature when the BOM moves," but not that today's stable
BOM wouldn't carry them at all.

Decision (user-confirmed): don't pull in an alpha `material3` override for
this. Substituted with stable-API equivalents that meet the same usability
goal instead of blocking the phase on it:

- **Sort** uses `SingleChoiceSegmentedButtonRow` + `SegmentedButton` — the
  same pattern `SettingsScreen.kt` already uses for theme mode — rather than
  `ButtonGroup`. Still "one tap fewer" than the `DropdownMenu` it replaces.
- **Shape morphing** on the cuisine badge is **not done**. Left out rather
  than faked with a non-`MaterialShapes` substitute; the badge stays a plain
  circle in both the row and the detail header, `sharedBounds` transition
  unchanged. Revisit once material3 ships a stable 1.5.x.

### Pinned, collapsible filters · Done

`FilterSection` no longer lives inside the `LazyColumn` (was its first
`item`, scrolling away with the list). It's now a fixed row between the
search field and the list, gated behind the same condition the list's own
empty states already use (`!isInitialLoad && (restaurants.isNotEmpty() ||
hasActiveFilter)`) so it doesn't appear over the loading spinner or the
first-sync empty state.

The row itself is a clickable header (`FilterList` icon + "Filters" label +
count `Badge` + a chevron that rotates via `animateFloatAsState`) toggling an
`AnimatedVisibility` around the existing `FilterSection` composable — chip
content unchanged, only its container moved. `activeFilterCount` is computed
inline from `minRating`/`cuisineType` (0–2); the `Badge` only shows when it's
nonzero, and carries its own `pluralStringResource`-driven content
description (`list_filters_active_count`) separately from the visible digit,
since a bare "2" read by TalkBack right after "Filters" is not self-explanatory.
`filtersExpanded` is `rememberSaveable`, so it survives rotation.

New strings: `list_filters_title`, `list_filters_expand`,
`list_filters_collapse`, `list_filters_active_count` (plural), in both
`values/` and `values-es/`.

### Sort via `SingleChoiceSegmentedButtonRow` · Done

Replaces the top app bar's sort `IconButton` + `DropdownMenu` entirely — the
segmented row sits fixed in the body, always visible, above the filters
header. One tap selects a sort order directly. `list_action_sort` (only ever
used as that icon's content description) is now unused and was removed from
both string files, the same way `list_action_more`/`list_action_about` were
dropped in Phase 2 when their UI went away.

### Predictive back · Done

`android:enableOnBackInvokedCallback="true"` added to `<application>` in
`AndroidManifest.xml`. Lint flags `UnusedAttribute` for it (`minSdk` 26 <
33) — expected and harmless: the attribute is simply ignored below API 33,
which is exactly the intended graceful degradation, not a real issue.

### Haptics · Done

Favouriting already had `HapticFeedbackType.LongPress` from Phase 3 (list and
detail toggles) — nothing to add there. Roulette had haptic feedback on the
pick *button press* (Phase 6) but not on the result actually landing,
which is what this item asked for: `RouletteScreen.kt`'s `LaunchedEffect`
now fires a second, distinct haptic once the card's flip animation
(`rotation.animateTo`) completes, marking the moment the pick settles rather
than the moment it was requested.

### Verification

`gradlew.bat test assembleDebug lint --no-daemon` — 145 tests passing
(unchanged from Phase 7, these are UI-only changes with no new ViewModel
logic), zero new lint warnings. Lint's `UnusedResources` dropped from 4 to 3
after removing `list_action_sort`; the remaining 3 (`action_ok`,
`detail_link_website`, `detail_link_instagram`) predate this phase and are
unrelated to it — not touched.

**Still to do**: shape morphing (blocked on a stable material3 1.5.x), and
the on-device pass (pinned filters expand/collapse and the badge count on a
real device, predictive back's system gesture actually working, both
haptics distinguishable from each other on hardware).

---

## Strings

All of these were already added, in both `values/` and `values-es/` (Spanish
plurals need the extra `many` quantity, as elsewhere), back when Phases 3/5/6
were still unstarted — `lint` flagged them `UnusedResources` until the screens
below consumed them. Now that Favourites, the bottom bar and Roulette all
exist, `lint` reports zero unused resources among this list.

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
- **`RestaurantListViewModelTest`** (updated) — a `FakeUserPreferencesRepository`
  joined the existing fakes; new cases cover `isFavorite` mapping onto the
  right restaurant and `onFavoriteToggle` writing through.
- **`RestaurantDetailViewModelTest`** (new) — loading/not-found/loaded states,
  `isFavorite` reflecting the stored ids, and `onFavoriteToggle` toggling this
  restaurant's own id specifically.
- **`FavoritesViewModelTest`** (new) — only favourited ids reach the state
  (each mapped with `isFavorite = true`), and un-favouriting removes a
  restaurant from the list immediately.
- **`RouletteViewModelTest`** (new) — two identically-seeded ViewModels
  (`Random(42)`) against identical data land on the same pick;  `pickCount`
  increments even when chance repeats the same restaurant; an empty candidate
  pool leaves `picked` null; `minRating` reaches the repository query;
  `favoritesOnly` narrows candidates to favourited ids; a pick that falls out
  of the pool after a filter change is cleared.

**Still to write**:

- `UserPreferencesRepositoryTest` — round-trip of palette, mode and favourite
  toggling against the real `DataStoreUserPreferencesRepository`, not just the
  in-memory fakes the ViewModel tests use.
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
4. **Performance** — `eatapp.composeMetrics=true` confirms `RestaurantUiModel`
   reports as `stable` and `RestaurantRow` as `skippable`; the Baseline Profile
   is generated, verified into a release APK, and measured at ~13% faster
   cold start on a real device (see Phase 7).

## Risks

- **`ButtonGroup` and `MaterialShapes`** turned out not to exist on any stable
  material3 release at all (latest stable is 1.4.0; both ship starting
  1.5.0-alpha01, and 1.5.0 has no stable release yet — see Phase 8). Sort was
  rebuilt on the stable `SingleChoiceSegmentedButtonRow` instead; shape
  morphing on the cuisine badge is deferred until 1.5.x stabilizes.
- **APK size** — Outfit adds ~110 KB. R8 already shrinks resources, and the
  font is the only heavy new one.
- **Baseline Profile** — generated, verified into a release APK, and its
  ~13% cold-start improvement measured on a real device. See Phase 7.
- **`.db` compatibility** — the new columns are optional on purpose, so the
  currently published file keeps validating untouched.
