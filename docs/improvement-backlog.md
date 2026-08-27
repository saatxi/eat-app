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

1. **F-26, F-33, F-34** — the list screen's interaction rough edges.
2. **F-03, F-09** — what is left of hardening the sync, minutes each.
3. **F-45, F-46** — two XS presentation fixes lint already points at.
4. **F-47** — the dependency set is over a year stale.
5. **F-50** — CI, now that there is a test suite worth running on every push.

---

## B. Sync robustness

### F-03 · The download has no size limit — Medium / XS

`input.copyTo(output)` will happily write however many gigabytes the server
sends into `cacheDir`. The project's own security notes call this file
untrusted input.
**Where:** [RestaurantDatabaseSyncManager.kt:68](../app/src/main/kotlin/com/albertferran/eatapp/data/sync/RestaurantDatabaseSyncManager.kt#L68)
**Fix:** cap it (10 MB is generous for this data) and fail as `INVALID_FILE`
past the cap.

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

The list is always alphabetical. Sorting by rating is the obvious want.

### F-31 · No result count — Low / XS

"3 restaurants" is most useful precisely when a filter is active and you want
to know how much you've narrowed things down.

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
