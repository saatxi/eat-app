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

1. **F-47** — the dependency set is over a year stale.
2. **F-50** — CI, now that there is a test suite worth running on every push.
3. **F-35** — the detail screen still has no title once the hero scrolls off.

---

## F. Detail screen UX

### F-35 · The top app bar has no title — Medium / S

`title = { Text("") }` — literally empty. Once the hero scrolls off, nothing
on screen says which restaurant you're looking at.
**Where:** [RestaurantDetailScreen.kt:60](../app/src/main/kotlin/com/albertferran/eatapp/ui/detail/RestaurantDetailScreen.kt#L60)
**Fix:** a `LargeTopAppBar` whose title collapses into the bar as you scroll —
it replaces the hand-rolled hero rather than adding to it.

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

### F-53 · Multi-language support — Medium / M

Deferred deliberately when the data was migrated to English (F-43). The
groundwork is done: cuisines are stored as keys and resolved through
`strings.xml`, so a second language is now a matter of adding
`values-es/strings.xml` without touching the `.db`.

Note this would need the "all strings in English" rule in
[CLAUDE.md](../CLAUDE.md) relaxed to "English is the default locale", since
that rule currently forbids exactly this.

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

---

## Done

Recorded here rather than deleted, so the numbering stays stable.

### List screen search and sort pass

Section E in full, which retires the section along with F-33 before it.

- **F-26 · The search field is bare — Done.** The field gained a leading
  search icon, a trailing clear button that only appears once there is
  something to clear (`list_search_clear`), `singleLine = true` so Enter can
  no longer insert a newline into a search box, and `ImeAction.Search`, whose
  action just drops focus — results already follow every keystroke, so there
  is nothing left for it to submit. `label` became
  `placeholder`, which is what stops the floating label from permanently
  costing a row of height. The placeholder text went from "Search by name" to
  "Search restaurants" while it was being moved: search has covered name,
  cuisine and address since the unused-column pass, so the old wording
  undersold it.
- **F-29 · No sorting — Done.** A `RestaurantSort` enum (`NAME`, `RATING`)
  runs from a sort menu in the app bar — a check mark on the active order,
  no vertical space taken from the list — through `RestaurantListUiState.sort`
  and the ViewModel's `Filters` into the repository. The DAO takes a
  `sortByRating: Boolean` rather than the enum, so the ordering stays a bound
  parameter (`ORDER BY CASE WHEN :sortByRating THEN rating ELSE 0 END DESC,
  name COLLATE NOCASE ASC`) instead of SQL assembled from a value, and the
  name order remains the tiebreak within a rating so both orders are stable.
  Sorting is not a filter: it is excluded from `hasActiveFilter`, and
  `clearFilters()` deliberately preserves it, since that button is reached
  from the "No matches" state where the user wants their restaurants back,
  not their chosen order undone.
- Verified with `./gradlew test assembleDebug lint` — 101 tests green (four
  new DAO cases for the rating order, its name tiebreak and its interaction
  with the filters, plus four ViewModel cases for the sort input), lint
  unchanged.

### List refresh indicator pass

- **F-33 · Two progress indicators, and a disappearing button — Done.** The
  app bar no longer swaps its refresh button for a `CircularProgressIndicator`
  while a sync runs: the button stays where it is and is disabled instead
  (`enabled = !uiState.isSyncing`), so the overflow icon beside it stops
  shifting on every refresh and `PullToRefreshBox`'s indicator is the only
  spinner on screen. That holds for a sync started from the button rather than
  the gesture too, since the box's indicator follows `isRefreshing` and not the
  drag. The screen's one remaining `CircularProgressIndicator` is F-20's
  initial-load one, which shows before the pull-to-refresh box has anything to
  report.
- Verified with `./gradlew test assembleDebug` — 93 tests green.

### State and architecture pass

Section D in full: both of its entries.

- **F-20 · Empty state flashes on cold start — Done.** `RestaurantListUiState`
  gained an `isInitialLoad` flag: true in `stateIn`'s initial value, false in
  every state the `combine` block builds. Since `combine` produces nothing
  until all of its sources have emitted, "that block ran at all" is exactly
  the signal that the database's first emission arrived — no extra flow needed
  to track it. The list screen shows a centred spinner while the flag is set,
  so an empty list can no longer be mistaken for a loaded-but-empty database
  and "No restaurants yet" only paints once it really is one.
- **F-22 · The Room entity is used directly as the UI model — Done.** New
  `ui/model/RestaurantUiModel.kt` holds what the screens draw plus the
  `Restaurant.toUiModel()` mapper; both ViewModels map at their edge, so
  `RestaurantListUiState.restaurants` and `DetailUiState.Loaded` carry UI
  models and neither screen sees the entity any more. The formatting that used
  to sit inside composables moved into the mapper: `"$".repeat(priceRange)`
  became a ready-made `priceLabel` (clamped, so a hand-built row can't draw a
  runaway chip), the detail screen's `repeat(5) { index < rating }` became
  `stars: List<Boolean>`, and a blank address is normalised to null so the
  location row is skipped instead of drawn empty. Anything that needs a string
  resource stayed in the composables — the cuisine label and the "3/5" rating
  text can't be resolved without a Context — so the model carries the raw
  `cuisineKey` and `rating` and `CuisineVisuals` resolves them at draw time.
- Verified with `./gradlew test assembleDebug lint` — 93 tests green, among
  them a new `RestaurantUiModelTest` pinning the mapper and three new
  ViewModel tests for the flag and the mapping; the lint report is unchanged
  from the previous pass (`GradleDependency` / `NewerVersionAvailable`, i.e.
  F-47; `UseKtx`; `OldTargetApi`; `ObsoleteSdkInt`).

### Sync robustness pass

Section B in full: all four remaining sync-hardening items.

- **F-03 · The download had no size limit — Done.** `download()` now copies
  through a new `copyUpToLimit(input, output, limit)` instead of raw
  `input.copyTo(output)`; past 10 MB it stops and the sync fails as
  `INVALID_FILE` instead of writing an unbounded stream into `cacheDir`.
  `copyUpToLimit` is a plain function (no Android dependency), so it is
  covered directly without a network round trip.
- **F-07 · Every refresh re-downloaded everything — Done.** The manager now
  persists the response `ETag` alongside the existing last-synced timestamp
  and sends it back as `If-None-Match`. A `304` short-circuits straight to a
  new `DatabaseSyncResult.UpToDate` — no file read, no `repository.replaceAll`
  wiping and reinserting every row for nothing — and the snackbar says
  "Already up to date" (`list_sync_up_to_date`) instead of claiming a refresh
  that didn't happen.
- **F-08 · No automatic first sync — Done.** `RestaurantListViewModel` gained
  an `init` block that checks the new `RestaurantRepository.count()` /
  `RestaurantDao.count()` and calls `syncNow()` once when it's zero, so a
  fresh install fills itself in instead of waiting on the empty state's
  button. Making this testable without hitting the network on every
  ViewModel construction is what motivated pulling a `DatabaseSyncManager`
  interface out of `RestaurantDatabaseSyncManager` (a `fun interface` with
  just `sync()`); the ViewModel test now runs against a hand-written
  `FakeDatabaseSyncManager` instead of the real one, which is also why it no
  longer needs `RobolectricTestRunner` at all. The "older than a day" half of
  the original idea was left out — it depends on F-06 and wasn't asked for.
- **F-09 · No connectivity pre-check — Done.** `sync()` now asks
  `ConnectivityManager` before doing anything else and fails immediately (as
  `SyncFailureReason.NETWORK`, the same "Couldn't download. Check your
  connection." message a real timeout would have produced) instead of
  burning up to 30 seconds across the two connect/read timeouts first. Needs
  `ACCESS_NETWORK_STATE`, added to the manifest and to CLAUDE.md's permission
  list — the only other permission besides `INTERNET`.
- Verified with `./gradlew test assembleDebug lint` — 85 tests green, nothing
  new in the lint report beyond one more instance of the pre-existing
  `SharedPreferences.edit` `UseKtx` finding (the new `saveETag`, same pattern
  as the existing `recordSyncTimestamp`).

### Low/S cleanup pass

Every entry scored **Low / XS** or **Low / S** at the time, done in one pass.

- **F-21 · Sync results are fragile across config changes — Done.** `SyncEvent`
  and its `MutableSharedFlow` are gone; the pending message now lives in
  `RestaurantListUiState` as `pendingSyncMessage` (renamed `SyncMessage`, still
  `Success`/`Error`), fed into the same `combine(...)` that builds the rest of
  the state. The screen's `LaunchedEffect` is keyed on the message itself and
  calls the new `onSyncMessageShown()` once it has shown it, which resets the
  state to null — the standard Compose one-shot-event-via-state pattern. This
  also gave F-34 (retry) a natural home: see below.
- **F-24 · The database singleton is duplicated — Done.** `EatAppDatabase`
  lost its companion object and `getInstance`'s double-checked locking
  entirely; there is now a single top-level `buildEatAppDatabase(context)`
  function, and `EatApplication`'s existing `by lazy` is the only thing that
  ever calls it — one singleton instead of two stacked on each other.
- **F-27 · The "1+" rating chip did nothing — Done.** Every synced restaurant
  has a rating of at least 1, so that chip filtered nothing while looking like
  it should. The row now runs `2..5` instead of `1..5`.
- **F-31 · No result count — Done.** A `list_result_count` plural renders
  above the results, but only when a filter is active and the list isn't
  empty — exactly the moment "12 restaurants" is worth knowing, as opposed to
  restating the total on an unfiltered list.
- **F-34 · No retry on the error snackbar — Done.** Folded into F-21's fix:
  an `Error` message now carries a "Retry" (`action_retry`) snackbar action,
  and `SnackbarResult.ActionPerformed` calls `syncNow()` directly.
- **F-45 · `ArrowBack` was deprecated and not RTL-aware — Done.**
  `Icons.Default.ArrowBack` became `Icons.AutoMirrored.Filled.ArrowBack` on
  the detail screen's back button; lint's `NotificationActionIcon`/mirroring
  warning for it is gone from the report.
- **F-46 · The sync message wasn't a plural — Done.** `list_sync_success`
  became a `<plurals>` resource (`Data refreshed (%1$d restaurant/s)`), read
  via `Resources.getQuantityString` from inside the snackbar's
  `LaunchedEffect` (not `pluralStringResource`, since that call site isn't
  composable). Lint no longer flags `PluralsCandidate` for it.
- Verified with `./gradlew test assembleDebug lint` — all green, and the
  lint report's remaining findings are unrelated to this pass (`GradleDependency`
  / `NewerVersionAvailable`, i.e. F-47; `UseKtx`; `OldTargetApi`;
  `ObsoleteSdkInt`).

### Query layer pass

- **F-15 · `%` and `_` in the search box acted as wildcards — Done.** The
  query is now escaped with `escapeLikeWildcards` (folded in the same step as
  `normalizeForSearch`) and the DAO's `LIKE` clause gained an `ESCAPE '\'`
  clause to match. A search for a literal `%` or `_` now matches that
  character instead of the whole table.
- **F-16 · No search debounce — Done.** The query half of the filter pipeline
  now runs through `debounce`, 250 ms for a non-blank query and 0 ms
  (immediate) for a blank one — so clearing the field or loading the screen
  for the first time isn't held up waiting on a timer that exists for
  keystrokes. `minRating` and `cuisineType` are unaffected: only the text
  query is debounced, since those are discrete taps rather than a stream of
  keystrokes. The search box itself still updates every keystroke instantly;
  only the repository query is throttled, via a second `Filters` flow
  (`queryFilters`) that the UI state's `filters` flow does not go through.

### Unused-column pass

Four columns removed from the entity, the reader, the UI and `data/eatapp.db`.

- **`photoUri` — Dropped.** It was `NULL` in every row and had never been read
  by any composable: the entity field, the `REQUIRED_COLUMNS` entry, the
  `SELECT` and the `cursor.isNull` mapping are gone.
- **`visitDate` — Dropped.** Its only appearance was one `InfoRow` on the
  detail screen, whose card is now titled "Rating and price"
  (`detail_section_rating`). It was the last `LocalDate` in the schema, so
  `Converters` and the `@TypeConverters` annotation went with it. This closes
  F-32 and F-37, which existed only to improve how that one row looked.
- **`createdAt` — Dropped.** Never read by anything: no composable, no query,
  no ordering. It briefly gained a `DEFAULT (CAST(strftime('%s','now') AS
  INTEGER) * 1000)` so it would not have to be typed by hand, before being
  removed outright in the same pass.
- **`notes` — Dropped, and this one cost something.** Unlike the others it was
  live: a card on the detail screen, one of the four fields folded into
  `searchText`, and part of the non-blank check in the reader. Search now
  covers `name`, `cuisineType` and `address` only, the reader's blank check is
  down to `name` and `cuisineType`, and `detail_section_notes` is gone. The
  DAO's `matches on notes` test and the reader's `rejects a NULL note` test
  went with it; `combines all three filters` now carries its query term in
  `address` instead.
- The reader only ever asked that `REQUIRED_COLUMNS` be *present*, so a `.db`
  still carrying any of the four dropped columns keeps importing unchanged; a
  test pins that. The Room version went 2 → 4, which the existing
  `fallbackToDestructiveMigration` handles by re-syncing.
- What is left is the minimum the UI actually renders: `id`, `name`,
  `cuisineType`, `address`, `rating`, `priceRange`. Only `address` is nullable.

### Cuisine vocabulary pass

- **F-18 · Dead code — Done.** `observeAll()` had no callers and was removed
  with the repository change. Still outstanding: the `GIT_COMMIT`
  `buildConfigField` is generated but never read. (`photoUri` was dropped
  outright in the unused-column pass above.)
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
  `cuisineType` or `notes` are rejected the same way. `address` goes through
  `cursor.isNull` and stays genuinely optional. (`notes` has since been
  dropped; the check now covers `name` and `cuisineType`.)
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
  concatenation of `name`, `cuisineType`, `address` and `notes`. (`notes` was
  later dropped; the column now covers the remaining three.) It is a
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

### Test suite pass

- **F-23 · No tests at all — Done.** 69 JUnit4 unit tests under
  `app/src/test/kotlin/`, all four targets the entry named. Robolectric covers
  the two that need an Android runtime, so `./gradlew test` runs the whole
  suite on the JVM with no emulator. `readRestaurants` was extracted from
  `RestaurantDatabaseSyncManager` into `RestaurantDatabaseReader` so the
  validation could be exercised against a file without a network round trip.
  The tests found that **F-02 was only half fixed**: `cursor.getString` returns
  null for a NULL column, so `name.isBlank()` threw an NPE before the blank
  check could report anything, and the catch-all in `sync()` turned it into the
  same generic "Couldn't refresh the data" the entry complained about. Reading
  the three non-null text columns through `?: ""` makes the check do what it
  claimed to. Two tests deliberately pin behaviour the backlog calls wrong —
  F-11 (an empty table is rejected) and F-15 (`%` acts as a wildcard) — so
  fixing either has an obvious place to start.

### String resources pass

- **F-54 · Recent features hardcoded English strings — Done.** The detail
  screen's "not found" state and the About dialog's "Last synced" line now read
  from `strings.xml`, and `formatRelativeTime` became a `@Composable` that
  resolves its output through three `<plurals>` resources
  (`relative_time_minutes_ago` / `_hours_ago` / `_days_ago`) plus a
  `relative_time_just_now` string, replacing the hand-rolled `if (…) "s" else ""`
  pluralisation. F-53 is no longer blocked: every user-visible string in the app
  now lives in `values/strings.xml`. The `"$".repeat(priceRange)` price marks and
  the `"$rating+"` chip label are deliberately left as Kotlin — they are symbols
  and numbers, not prose; making them readable is F-44's and F-27's job.

### Launcher icon pass

- **F-52 · The launcher icon was still template-grade — Done.** The entry said
  "the generic Android robot"; what was actually there was a half-finished
  fork-and-knife. The knife drew, but the fork's tines, and its handle, were
  written as bare line segments (`M37,28 L37,44`, `M40,54 L40,84`) inside
  `fillColor` paths — zero-area subpaths, so they contributed nothing and the
  fork rendered as a solid blob. Both shapes also ran to `y=84`, outside the
  66dp safe circle a launcher mask is guaranteed to leave alone, so the
  bottoms were at the mercy of the device's mask. Redrawn as two closed filled
  outlines — a three-tined fork and a flat-spined knife, paired around the
  centre and scaled to fill the safe circle without touching it.
- The two lint findings the entry named are gone with it. `<monochrome>` now
  points at the same foreground drawable, which is all the themed-icon path
  needs since it only reads that layer's alpha — and it is why the shapes had
  to become real filled outlines rather than strokes. `ic_launcher_round.xml`
  was deleted: `android:roundIcon` already pointed at `@mipmap/ic_launcher`,
  so nothing referenced it, and the attribute itself went too — with
  `minSdk = 26` every device gets the adaptive icon and masks it round itself.
- `./gradlew lint` now reports neither `MonochromeLauncherIcon` nor the unused
  resource; what is left is unrelated (`GradleDependency` / `UseKtx` and
  friends, i.e. F-47 and F-45).

### Sync validation pass

- **F-04 · No magic-header check — Done.** `RestaurantDatabaseReader.read`
  now reads the first 16 bytes and compares them against `SQLite format 3\0`
  before the file reaches `SQLiteDatabase.openDatabase`, failing as
  `INVALID_FILE` with `"not a SQLite database: bad file header"`. Nothing was
  unsafe before — the file was already read-only and `SQLiteException` was
  caught — but a truncated download or an HTML error page saved as `.db` used
  to surface as whatever SQLite happened to say, or as "missing columns" when
  it opened an empty database anyway. A file shorter than the header (the
  empty file included) is rejected on the same path.

### Sync plumbing pass

- **F-10 · Temp files leak on abnormal exit — Done.** The download target is now
  a fixed `sync.db` rather than `sync_<millis>.db`, so a process death mid-sync
  leaves at most one file behind and the next download truncates it instead of
  adding another. Files left by earlier versions are swept at the start of every
  sync: anything in `cacheDir` matching the old `sync_*.db` shape is deleted.
- **F-11 · A legitimately empty dataset is rejected — Done.** The
  `restaurants.isEmpty()` branch is gone, so a `.db` with zero rows imports as
  zero rows and the list empties. It is the only way to sync back to nothing, and
  nothing is lost by allowing it: the header and `REQUIRED_COLUMNS` checks are
  what actually catch a malformed file. The test that pinned the old behaviour
  now asserts the new one.
- **F-12 · `DATABASE_URL` is hardcoded — Done.** The URL is now a
  `buildConfigField` set per build type, and `RemoteConfig.DATABASE_URL` reads
  `BuildConfig`. Release keeps the hardcoded `releaseDatabaseUrl` from
  `app/build.gradle.kts` and ignores any override, so nothing local can escape
  into a published APK; debug takes `eatapp.database.url` from
  `local.properties` or `EATAPP_DATABASE_URL` from the environment, defaulting to
  the same public URL. A non-`https://` override fails the build at configuration
  time rather than at runtime, since the app allows no cleartext traffic. The
  `signingSecret` helper became `localOrEnv`, shared with the signing config.
