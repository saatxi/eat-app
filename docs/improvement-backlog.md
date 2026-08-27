# EatApp improvement backlog

A single place to look up everything worth improving in this app, so ideas
don't get lost between sessions. It's a menu, not a plan — nothing here is
committed to, and items can be picked off in any order.

Every entry has a stable ID (`F-01`…`F-54`). Use those in commit messages and
when asking for something to be worked on; they never get renumbered, and
items that get done stay in the list marked **Done** rather than being
deleted, so the file keeps a record of what changed and why.

- **Impact** — High: a crash, data loss, or something visibly broken /
  Medium: a real annoyance / Low: polish.
- **Effort** — XS: minutes · S: under an hour · M: an afternoon · L: bigger.

Large-screen and tablet support is deliberately not covered here; see
[tablet-adaptive-layout-idea.md](tablet-adaptive-layout-idea.md).

## Where to start

If you only do a handful, these in this order:

1. **F-23** — still no tests; `readRestaurants` validation is the place to start.
2. **F-54** — the last two features left English text hardcoded in Kotlin.
3. **F-26, F-33, F-34** — the list screen's interaction rough edges.
4. **F-03, F-04, F-11** — what is left of hardening the sync, minutes each.
5. **F-37, F-45, F-46** — three XS presentation fixes lint already points at.
6. **F-47** — the dependency set is over a year stale, and F-50 (CI) is
   worth little until it builds something current.

---

## B. Sync robustness

### F-03 · The download has no size limit — Medium / XS

`input.copyTo(output)` will happily write however many gigabytes the server
sends into `cacheDir`. The project's own security notes call this file
untrusted input.
**Where:** [RestaurantDatabaseSyncManager.kt:68](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/RestaurantDatabaseSyncManager.kt#L68)
**Fix:** cap it (10 MB is generous for this data) and fail as `INVALID_FILE`
past the cap.

### F-04 · No magic-header check — Low / XS

Any downloaded bytes go straight to `SQLiteDatabase.openDatabase`. It's
contained — read-only, and `SQLiteException` is caught — but checking the
16-byte `SQLite format 3\0` header first is nearly free and turns "invalid
file" into an accurate diagnosis instead of a guess.

### F-07 · Every refresh re-downloads everything — Medium / S

No `ETag` or `If-Modified-Since`, so tapping refresh twice transfers the file
twice and wipes/reinserts every row for nothing.
**Fix:** keep the `ETag` from the previous response, send `If-None-Match`, and
treat `304` as "already up to date" — which also gives the user a more honest
message than "Data refreshed (3 restaurants)".

### F-08 · No automatic first sync — Medium / S

A fresh install shows an empty state and waits to be told to download.
**Fix:** sync automatically when the local database is empty. Optionally also
when the data is older than a day, which depends on F-06.

### F-09 · No connectivity pre-check — Medium / XS

Offline, the two 15-second timeouts mean up to 30 seconds of spinner before a
generic failure.
**Fix:** ask `ConnectivityManager` first and fail immediately with an accurate
"no connection" message.

### F-10 · Temp files leak on abnormal exit — Low / XS

`sync_<millis>.db` is removed in a `finally`, but a process death mid-sync
leaves it in `cacheDir` forever.
**Where:** [RestaurantDatabaseSyncManager.kt:34](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/RestaurantDatabaseSyncManager.kt#L34)
**Fix:** use a fixed filename, or sweep leftover `sync_*.db` at startup.

### F-11 · A legitimately empty dataset is rejected — Low / XS

An empty table is treated as `INVALID_FILE`, so you could never sync your way
back to zero restaurants.
**Where:** [RestaurantDatabaseSyncManager.kt:126](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/RestaurantDatabaseSyncManager.kt#L126)
**Fix:** accept it. It's a valid state; the `REQUIRED_COLUMNS` check already
catches genuinely malformed files.

### F-12 · `DATABASE_URL` is hardcoded — Low / S

Testing against a branch or a fork means editing source and rebuilding.
**Where:** [RemoteConfig.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/RemoteConfig.kt)
**Fix:** a debug-build override, or a `buildConfigField` per build type.
Keep the release value hardcoded.

---

## C. Query layer

### F-15 · `%` and `_` in the search box act as wildcards — Low / XS

They're passed into `LIKE` unescaped.
**Fix:** escape them and add an `ESCAPE` clause.

### F-16 · No search debounce — Low / XS

Every keystroke re-runs the query through `flatMapLatest`. Harmless at this
data size, worth a ~250 ms debounce if the list ever grows.

---

## D. State and architecture

### F-20 · Empty state flashes on cold start — Medium / XS

`RestaurantListUiState` starts with an empty list and no "still loading" flag,
so "No restaurants yet" paints for a frame before Room's first emission.
**Fix:** an `isInitialLoad` flag, cleared on the first emission.

### F-21 · Sync results are fragile across config changes — Low / S

`SyncEvent` goes through a `MutableSharedFlow` with no replay or buffer, so
delivery depends on a collector being attached at the right moment.
**Fix:** put the pending message in the UI state and have the screen mark it
consumed — the standard Compose event pattern.

### F-22 · The Room entity is used directly as the UI model — Low / M

Screens read `Restaurant` straight from the database, so formatting decisions
(price string, date format, rating text) live inside composables. Fine at this
size; worth splitting if the detail screen grows.

### F-23 · No tests at all — High / M

`app/src/test` and `app/src/androidTest` are both empty. The highest-value
targets, roughly in order: `readRestaurants` validation and its failure modes,
the DAO filter query, `Cuisine.fromKey`, and the ViewModel's filter
combination.

### F-24 · The database singleton is duplicated — Low / XS

`EatAppDatabase.getInstance` does double-checked locking, and `EatApplication`
then wraps it in `by lazy` — two singletons around one object.
**Fix:** drop the companion-object machinery and let the `Application`'s
`by lazy` own it.

---

## E. List screen UX

### F-26 · The search field is bare — Medium / S

No leading search icon, no clear button, not `singleLine` (so Enter inserts a
newline), no `ImeAction.Search`, and it uses `label` rather than `placeholder`
so the floating label permanently costs vertical space.
**Where:** [RestaurantListScreen.kt:138](../app/src/main/kotlin/com/albertferran/eatapp/ui/list/RestaurantListScreen.kt#L138)

### F-27 · The "1+" rating chip does nothing — Low / XS

Every restaurant has a rating of at least 1, so the chip filters nothing while
looking like it should.
**Fix:** start the range at 2, or switch to star icons where "1 star and up"
at least reads sensibly.

### F-29 · No sorting — Medium / M

The list is always alphabetical. Sorting by rating or by most recent visit is
the obvious want, and `visitDate` is already stored.

### F-31 · No result count — Low / XS

"3 restaurants" is most useful precisely when a filter is active and you want
to know how much you've narrowed things down.

### F-32 · `visitDate` isn't shown in the list — Low / XS

It only appears on the detail screen, though "when was I last there" is a
natural thing to scan for. Depends on F-37 for formatting.

### F-33 · Two progress indicators, and a disappearing button — Medium / S

During a pull-to-refresh, `PullToRefreshBox` shows its own indicator while the
app bar *replaces* the refresh button with a spinner — so you get two
spinners, and the button vanishes and shifts the icons next to it.
**Where:** [RestaurantListScreen.kt:109](../app/src/main/kotlin/com/albertferran/eatapp/ui/list/RestaurantListScreen.kt#L109)
**Fix:** keep the button in place and disabled, and let the pull-to-refresh
indicator be the only spinner.

### F-34 · No retry on the error snackbar — Low / XS

A failed refresh sends you back to hunt for the button. Add a "Retry" action;
pairs with F-05's "Details".

---

## F. Detail screen UX

### F-35 · The top app bar has no title — Medium / S

`title = { Text("") }` — literally empty. Once the hero scrolls off, nothing
on screen says which restaurant you're looking at.
**Where:** [RestaurantDetailScreen.kt:60](../app/src/main/kotlin/com/albertferran/eatapp/ui/detail/RestaurantDetailScreen.kt#L60)
**Fix:** a `LargeTopAppBar` whose title collapses into the bar as you scroll —
it replaces the hand-rolled hero rather than adding to it.

### F-37 · Dates are shown in ISO format — Medium / XS

`DateTimeFormatter.ISO_LOCAL_DATE` renders `2026-01-15`.
**Where:** [RestaurantDetailScreen.kt:180](../app/src/main/kotlin/com/albertferran/eatapp/ui/detail/RestaurantDetailScreen.kt#L180)
**Fix:** `ofLocalizedDate(FormatStyle.MEDIUM)` — "15 Jan 2026", and it follows
the device locale for free.

### F-38 · No transition between list and detail — Low / L

Tapping a card cuts straight to the detail screen. A shared-element container
transform from the card's cuisine icon into the detail hero is the standout
polish item, and Compose supports it natively now.

---

## G. Theming, i18n and accessibility

### F-41 · Half the colour scheme is still Material's default — Medium / S

Only 12 of the ~26 colour roles are overridden. `surface`, `background`,
`error`, `outline`, `surfaceVariant` and `onSurfaceVariant` all keep the
baseline purple-tinted defaults, which quietly fight the terracotta/sage brand
everywhere they show up — dividers, empty-state icons, secondary text.
**Where:** [Theme.kt](../app/src/main/kotlin/com/albertferran/eatapp/ui/theme/Theme.kt)
**Fix:** generate a full scheme from the terracotta seed and fill in the
remaining roles.

### F-42 · The window theme is light-only — Medium / XS

`themes.xml` inherits `android:Theme.Material.Light.NoActionBar`, so in dark
mode the window flashes white before Compose paints.
**Where:** [themes.xml](../app/src/main/res/values/themes.xml)
**Fix:** switch to a `DayNight` parent.

### F-44 · Screen readers get fragments — Medium / S

Every icon in a row is `contentDescription = null` and the texts are separate
nodes, so a row is announced as disconnected pieces. `"$$"` is read out as
"dollar dollar", and the star row on the detail screen is silent.
**Fix:** set one description on the whole `Card` describing the restaurant,
and give the price and rating real descriptions ("Price range 2 of 4").

### F-45 · `ArrowBack` is deprecated and not RTL-aware — Low / XS

`Icons.Default.ArrowBack` should be `Icons.AutoMirrored.Filled.ArrowBack`.
The manifest declares `supportsRtl="true"`, so the arrow currently points the
wrong way in a right-to-left locale.
**Where:** [RestaurantDetailScreen.kt:63](../app/src/main/kotlin/com/albertferran/eatapp/ui/detail/RestaurantDetailScreen.kt#L63)

### F-46 · The sync message should be a plural — Low / XS

"Data refreshed (1 restaurants)". Lint flags it as `PluralsCandidate`.
**Where:** [RestaurantListScreen.kt:91](../app/src/main/kotlin/com/albertferran/eatapp/ui/list/RestaurantListScreen.kt#L91)
**Fix:** a `<plurals>` resource read with `pluralStringResource`, which also
removes the `String.format` call that currently formats with the default
locale.

### F-53 · Multi-language support — Medium / M

Deferred deliberately when the data was migrated to English (F-43). The
groundwork is done: cuisines are stored as keys and resolved through
`strings.xml`, so a second language is now a matter of adding
`values-es/strings.xml` without touching the `.db`.

Note this would need the "all strings in English" rule in
[CLAUDE.md](../CLAUDE.md) relaxed to "English is the default locale", since
that rule currently forbids exactly this.

### F-54 · Recent features hardcoded English strings — Medium / XS

`CLAUDE.md` requires every in-app string to live in `strings.xml`, but the
detail screen's "not found" state (F-19) and the About dialog's "Last synced"
line (F-06) both went in as Kotlin string literals, and `formatRelativeTime`
builds its output ("2 days ago") in Kotlin too.

**Where:** [RestaurantDetailScreen.kt:107-118](../app/src/main/kotlin/com/albertferran/eatapp/ui/detail/RestaurantDetailScreen.kt#L107-L118),
[RestaurantListScreen.kt:220](../app/src/main/kotlin/com/albertferran/eatapp/ui/list/RestaurantListScreen.kt#L220)

**Fix:** move them to `strings.xml`; the relative time is a `<plurals>` job,
so it pairs with F-46. Blocks F-53 until done.

---

## H. Build, release and tooling

### F-47 · Dependencies are well over a year stale — Medium / M

From lint: Compose BOM `2024.12.01` → `2026.08.00`, Kotlin `2.2.10` →
`2.4.10`, lifecycle `2.8.7` → `2.11.0`, activity-compose `1.9.3` → `1.13.0`,
navigation-compose `2.8.5` → `2.9.8`, coroutines `1.9.0` → `1.11.0`, core-ktx
`1.15.0` → `1.19.0`, and `compileSdk` 36 → 37.
**Where:** [libs.versions.toml](../gradle/libs.versions.toml)
**Fix:** upgrade in two steps — the Compose BOM on its own first, then Kotlin
and KSP together, since those two must stay in lockstep.

### F-49 · Minification is off, so the whole icon set ships — Medium / S

`isMinifyEnabled = false` means `material-icons-extended` (1,932 icons) is
packaged in full for the ~25 actually used. This is by far the largest thing
in the APK.
**Fix:** either enable R8, or import the handful of icons directly from
`material-icons-core` and drop the extended dependency. The second option is
smaller and needs no ProGuard rules, but not every icon used here exists in
core. Note that `CLAUDE.md` records minification being off as a deliberate
choice, so this is a decision to make rather than a defect to fix.

### F-50 · No CI — Medium / M

Nothing builds this but a local machine. `app/build.gradle.kts` already
carries a warning that any future CI checkout must use `fetch-depth: 0` and
`fetch-tags: true`, or the git-derived version silently collapses to
`versionCode=1` and a bare SHA.
**Fix:** a workflow running `assembleDebug` and `lint` on push.

### F-51 · No `@Preview` composables — Medium / S

`ui-tooling-preview` is a dependency but there isn't a single preview, so
every UI tweak needs a full build and deploy to see.
**Fix:** previews for the restaurant row, both empty states, and the detail
screen, each in light and dark.

### F-52 · The launcher icon is still the template default — Low / S

The generic Android robot, plus two lint findings: `ic_launcher_round` is
unused, and there's no `<monochrome>` layer, so the icon can't take part in
themed icons on Android 13+.

---

## Done

Recorded here rather than deleted, so the numbering stays stable.

### Cuisine vocabulary pass

- **F-18 · Dead code — Done.** `observeAll()` had no callers and was removed
  with the repository change. Still outstanding: the `GIT_COMMIT`
  `buildConfigField` is generated but never read, and `photoUri` / `createdAt`
  are imported from the `.db` and never displayed.
- **F-25 · Filters ate the screen — Done.** The rating and cuisine rows moved
  inside the `LazyColumn` so they scroll away; only the search field stays
  pinned. Adding the cuisine row would otherwise have pushed the fixed header
  past ~210 dp on a phone.
- **F-28 · No way to clear filters — Done.** The "No matches" state now has a
  "Clear filters" button, and the filter chips themselves stay on screen when
  a filter matches nothing — previously the empty state replaced the entire
  list, taking the controls with it.
- **F-30 · No cuisine filter — Done.** Filter chips, each with its cuisine
  icon, listing only the cuisines actually present in the data via a new
  `DISTINCT` query.
- **F-39 · Cuisine icons never matched the data — Done.** `cuisineIcon`
  matched English keywords (`pizza`, `japan`, `bar`) against Spanish values
  (`Japonesa`, `Mediterránea`, `Frankfurt`), so *every* row fell back to the
  generic icon. Replaced with an exact match against the closed 22-key
  vocabulary in [Cuisine.kt](../app/src/main/kotlin/com/albertferran/eatapp/data/local/Cuisine.kt),
  each key with its own distinct icon.
- **F-40 · Arbitrary cuisine colours — Done.** `cuisineTint` keyed off
  `cuisineType.hashCode().mod(3)`; it now keys off the enum ordinal, which is
  stable across releases and spreads evenly over the three container roles.
- **F-43 · Data migrated to English — Done.** `cuisineType` values became
  vocabulary keys and `notes` were translated. Restaurant names and addresses
  were deliberately left alone — `Plaça Santa Anna, Mataró` is a real place,
  not a string to translate. Multi-language support is now tracked as F-53.

### Crash, sync and search pass

- **F-01 · Negative `priceRange` crashed the screen — Done.** Handled by
  rejecting rather than coercing: `readRestaurants` fails the whole import as
  `INVALID_FILE` when `rating` is outside 0–5 or `priceRange` outside 0–4, and
  names the offending row id. A typo in the source data is now a message you
  can act on instead of a silently clamped value.
- **F-02 · NULL text columns caused an NPE — Done.** Rows with a blank `name`,
  `cuisineType` or `notes` are rejected the same way. `address` and `photoUri`
  go through `cursor.isNull` and stay genuinely optional.
- **F-05 · Failure details were thrown away — Done (partly).** Every failure
  site now logs its `detail` under the `EatApp.Sync` tag, so `adb logcat` tells
  you why a refresh failed. Still outstanding: surfacing that detail in the app
  behind a "Details" action on the snackbar — folded into F-34.
- **F-06 · No "last synced" timestamp — Done.** Stored in SharedPreferences on
  success and read back through `RestaurantDatabaseSyncManager.getLastSyncTime`.
  It shows in the About dialog only; putting a relative time under the list
  title, as originally sketched, was not done.
- **F-13 · Search only looked at the name — Done.** Superseded by F-14, which
  covers the same four fields through the normalized column.
- **F-14 · Accented text never matched — Done.** `Restaurant` gained a
  `searchText` column holding an NFD-folded, accent-stripped, lowercased
  concatenation of `name`, `cuisineType`, `address` and `notes`. It is a
  constructor default derived from those fields, so it cannot drift from them
  and the sync importer needs no changes. The DAO's four `LIKE` clauses
  collapsed into one against `searchText`, and the repository folds the query
  with the same `normalizeForSearch` before it reaches Room.
- **F-17 · No Room migration strategy — Done.** Forced by F-14's schema change:
  the database is now `version = 2` with
  `fallbackToDestructiveMigration(dropAllTables = true)`. Correct for a pure
  cache, but it does mean existing installs come up empty once and have to be
  refreshed by hand — which makes F-08 (automatic first sync) worth more than
  it was.
- **F-19 · The detail screen could show nothing — Done.** `DetailUiState` now
  distinguishes `Loading`, `NotFound` and the loaded case; missing restaurants
  get an explanation and a back button instead of a blank screen. The strings
  went in hardcoded, though — see F-54.
- **F-36 · The address was dead text — Done (partly).** The address row fires
  `ACTION_VIEW` on a `geo:0,0?q=<address>` URI. The share action from the same
  entry was not added and is still worth having.

### Release signing pass

- **F-48 · Release builds were unsigned — Done.** `app/build.gradle.kts` gained
  a `release` signing config whose keystore path, store password, key alias and
  key password come from `local.properties` or, for CI, from the matching
  `EATAPP_*` environment variables — nothing secret is committed, and `*.jks` /
  `*.keystore` were added to `.gitignore` so a stray keystore cannot be
  committed by accident. When no keystore is configured the release build still
  succeeds but stays unsigned and now says so with an explicit warning, and only
  on release tasks so debug builds stay quiet. Verified end to end against a
  throwaway keystore: `assembleRelease` produced `app-release.apk` instead of
  `app-release-unsigned.apk` and `apksigner verify` confirmed the signature.
  README gained a "Signing releases" section and the release checklist now
  points at it.
