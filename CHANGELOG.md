# Changelog

All notable changes to EatApp are documented here, one entry per release
tag, newest first. Loosely follows the spirit of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); entries are
derived from this repo's annotated git tag messages (`git tag -l -n99`)
rather than hand-maintained separately, so the wording matches what was
tagged at release time. Versioning follows the `vMAJOR.MINOR.PATCH` scheme
described in [README.md](README.md#versioning) — `versionName`/`versionCode`
are always derived from git, never hand-edited.

## [3.5.1] - 2026-09-28

Fix the shared groups' rough edges and a handful of smaller issues

- Creating a group did nothing and said nothing, because a device that had
  already signed in never handed its stored session to the client; the stored
  session now seeds the client, and a failure reaches the screen as a message
  instead of silence
- Keep the create-group dialog's text controller alive until the dialog itself
  is torn down, rather than disposing it the moment the caller resumes, which
  the framework rejected as a build in the wrong scope during the exit
  transition
- No group's member list ever loaded: the roster embedded profiles in
  group_members, but both tables key off auth.users rather than each other, so
  PostgREST refused the embed — the two are now fetched separately and joined
- A fresh anonymous account has no display name, so the roster listed a bare
  user id; a member can now set their own name from their row, written to
  profiles.display_name
- The group scope was a chip row over the journal that could strand the user on
  Personal with no way back; it is now one labelled drop-down in the app bar of
  the journal, the roulette and the statistics, naming the scope in force and
  keeping every group reachable from wherever you are
- Group management — creating a group, joining one and seeing its members —
  moved out of the journal and into Settings, so the journal's app bar dropped
  its statistics and share actions, both already offered in Settings
- The launcher now shows EatApp rather than the package name it had been
  shipping as
- The detail header shows the restaurant's name where the cuisine badge used to
  sit, so a long name is no longer truncated beside it, and the roulette card
  shows a compact region-and-country line instead of the whole address
- Sharing a restaurant carries its favourite mark now, and importing restores it

## [3.5.0] - 2026-09-27

Add shared groups: a synced, group-scoped restaurant list with invitations

- Add the shared-groups backend — a Supabase schema with Row Level Security,
  the two Edge Functions that mint and redeem invitations, and the private
  Storage bucket photos travel through — wired so the whole feature stays
  dormant unless the build carries SUPABASE_URL and SUPABASE_ANON_KEY, leaving
  personal mode fully offline
- Bump the drift schema to 17 with real, purely additive migrations: 16 added
  the sync metadata (groupId, createdBy, updatedAt, deletedAt) to every shared
  table and 17 added the pending-change queue and the per-group pull cursor, so
  existing rows stay private without a backfill
- Add the sync layer: an anonymous Supabase identity, a queue of pending
  changes and per-group pull cursors, a SyncEngine over a transport abstraction
  with its Supabase implementation, soft deletes that travel as tombstones, and
  photo binaries carried through Storage
- Scope every read to the selected group behind a selector over the journal,
  so the list, the statistics, the roulette and the home-screen widget all
  follow the chosen group, and attribute every shared write to whoever made it
- Add group management: create a group, see its members, expel someone or
  leave, and follow the sync state from the journal
- Add invitations: an owner shows a QR drawn with qr_flutter, the joining side
  scans it with mobile_scanner or types the short code, and app_links delivers
  the eatapp://join/… deep link — the scanner is the app's only camera user and
  the manifest's single permission
- Harden the backend: rate-limit both minting and redeeming invitations, keep
  every non-empty group with at least one owner by refusing the last owner's
  leave and offering dissolution instead, verify every policy with the
  owner/member/stranger RLS test, and let a group's data be exported before it
  is left or dissolved
- Compile the backend configuration through the release build — bundle.ps1
  resolves SUPABASE_URL and SUPABASE_ANON_KEY like the signing keys — and add a
  gitignored dart_defines.json plus launch configurations so a debug run can
  switch the backend on without editing code

## [3.3.0] - 2026-09-27

Redesign the app as a warm humanist journal and drop the tag feature

- Rebuild the UI around a new terracotta, olive and berry palette that
  replaces the verd scheme, with its own radius and motion tokens and the
  Lora and Nunito fonts, and rebuild the theme assembly and every shared
  widget on top of it
- Make the journal the app's main surface under a Restaurants / Roulette /
  Settings bottom bar, with a prominent search, the visited / want-to-try /
  favourites segments folded into a dropdown chip, and the add action moved
  into the app bar
- Migrate every screen — restaurants, detail, add/edit, log-visit, roulette,
  statistics, settings and the import review — onto the new design system
- Give the restaurants filters a region and country dropdown, hide the
  location dimensions that have no values, and give the roulette the same
  filter set behind a collapsible Filtres header
- Re-skin the home-screen widget's Android resources and iOS extension to
  match the new palette
- Remove the tag feature end to end: drop the tags and restaurant_tags
  tables and bump the drift schema to 15 with a real migration, take tags
  out of the repository, the UI models, the share format and every screen,
  and drop the column from the CSV converter
- Tolerate a leading UTF-8 BOM when importing a share file, and space the
  rating apart from the price pill

## [3.2.0] - 2026-09-26

Redesign the app's appearance around a single verd colour scheme

- Replace the three selectable palettes and their picker with one hand-tuned
  verd scheme — a forest primary, a citrus secondary and a berry tertiary
  over leaf-tinted neutrals — so the app reads as a single identity rather
  than three variants of itself
- Keep only the light/dark toggle, drop the palette names from the ARB files
  and the pickers from Settings and the dev gallery, and treat a stale stored
  palette id as ignored rather than throwing so an upgrade from the previous
  build cannot crash on startup
- Add the redesign's motion: a spring press on the add button and the
  roulette reveal, a reveal that settles instead of popping, a count-up on
  the statistics tiles, and a leaf-to-citrus wash behind the list header
- Stand every new animation down when the platform asks for reduced motion,
  and keep each one-shot so it always settles rather than holding a frame
  source open
- Hold the accessibility line for the new scheme, with the light and dark
  on-colours and the eight cuisine accents clearing WCAG AA in
  color_contrast_test and the 2× dynamic-type and semantics tests kept green
- Add the Java null-analysis mode to the workspace's editor settings

## [3.1.0] - 2026-09-26

Add the home-screen widget, restore the app's own icon and splash, and fix
the screens' rough edges

- Add the home-screen widget on both platforms: a Kotlin AppWidgetProvider
  with its layout for Android, a WidgetKit extension for iOS, and the
  restaurant, the language and every string it shows decided in Dart
- Make the shell adapt at 840 logical pixels — a bottom bar below that, a
  NavigationRail with the detail beside the list above it — and add motion,
  empty states and paired hero images to the list and the detail
- Follow each platform's own behaviour instead of restating it (iOS keeps the
  framework's edge swipe-back) and support large system text rather than
  clamping it
- Restore the launcher icon and splash screen the rewrite had left as
  templates: one fork-and-knife artwork living in the Android vectors, with
  every raster Android below 26 and iOS need generated from them
- Show the app's own version in Settings again, read back off the platform so
  it cannot disagree with the build it is running in
- Fix the rough edges: a rating trend chart that painted nothing, a language
  picker that was a four-row list, a bottom bar carrying labels, a filter
  panel with no way to clear it, a visits action floating over the visits it
  was about, and a roulette reveal that was clipped — it is scaled to fit
  now, with its filters wrapping instead of running off the edge
- Widget-test the four screens that had none, cover the photo pipeline and
  the filter bundle, and drop the migration planning docs that had outlived
  their job

## [3.0.1] - 2026-09-26

Add sharing, importing and photos to the Flutter app

- Add the share sheet and the export options dialog, so one restaurant or the
  whole list can be sent as an .eatapp file
- Add the import review screen, which lists a shared file's restaurants,
  flags likely duplicates against the current list and writes nothing until
  the user confirms
- Add photo storage and picking: copy each picked image into the app's own
  store with its EXIF orientation baked in and its longest side bounded,
  delete the file whenever its row goes, and show the photo on the list,
  roulette, detail and edit screens
- Carry a visit's photos onto the log-visit form and the detail timeline
- Trim the release bundle by obfuscating Dart, dropping the x86_64 ABI and
  archiving the Dart symbols
- Fix the CSV helper's stale price scale and a dead Gradle path left over
  from the native build
- Remove the legacy native Android app and the last Claude Code-specific
  directory now that the Flutter rewrite is the only codebase
- Silence JEP 472 native-access warnings by setting GRADLE_OPTS

## [3.0.0] - 2026-09-25

Rewrite EatApp in Flutter

- Add a complete Flutter implementation at the repository root, keeping the
  same applicationId, git-derived versioning and release keystore as the app
  it replaces
- Port the data layer to drift (schema, DAOs and search helpers) and add a
  Room-to-drift importer so existing installs migrate their restaurants
- Rebuild the localization layer for English, Spanish and Catalan from ARB
  files with flutter gen-l10n
- Recreate the theme and design-token layer (palettes, typography, spacing,
  radii and cuisine accents) with the bundled Manrope and Newsreader fonts
- Port every screen: restaurant list with search and filters, add/edit form,
  detail with visit history, favourites, log-visit, statistics, roulette and
  settings
- Extract the shared presentation widgets and the list model, filters and
  controller those screens build on
- Re-implement the .eatapp share format, its reader and writer, and the
  on-device backup snapshot
- Move git-tag versioning and release signing into the Flutter Android module
  and make scripts/bundle.ps1 build the signed bundle with flutter build
  appbundle
- Pin local builds and the VS Code Java extension to Temurin 21, fix UTF-8
  reading of .eatapp files, and drop the CI workflow configuration

## [2.6.1] - 2026-09-24

Include visits in restaurant exports and fix the average-rating label
wrapping

- Add an "Include visits" switch to every export path (share from Detail,
  "share all" from List, "export my data" from Settings), backed by
  RestaurantRepository.exportRestaurants so all three agree on what a file
  contains; the detail screen's single share now carries the real visit
  history instead of only the latest visit
- Name a single restaurant's export file after the restaurant
  (cal-ferran-20260924_1246.eatapp) while bulk exports keep
  restaurants-YYYYMMDD_HHmm.eatapp
- Shorten the average-rating stat tile label so it no longer wraps onto two
  lines on narrow phones or larger font scales, keeping it level with the
  other tiles
- Bump the minor-and-patch dependency group with 10 updates

## [2.6.0] - 2026-09-13

Collapsible price range filtering and a clearer import review screen

- Revert the Google Maps share-link import added in v2.5.4: the
  redirect-resolution approach proved unreliable in practice
- Collapse already-imported restaurants into their own section on the import
  review screen instead of interleaving them with new ones
- Add a price range filter to the restaurant list and collapse the filter
  chips into dropdowns to make room for it
- Replace the "$"-tier price range with six euro-band tiers for finer-grained
  filtering and display

## [2.5.4] - 2026-09-13

Add importing a restaurant from a Google Maps share link

- Resolve a share.google/maps.app.goo.gl link's redirect chain to recover a
  place name, the app's one deliberate exception to its zero-network design,
  scoped to an allowlist of Google Maps hosts with no API key and silent
  fallback on failure
- Add a share-sheet entry point so EatApp can receive a shared Google Maps
  link directly, and an "Import from a link" button on the add-restaurant
  screen for pasting one manually

## [2.5.3] - 2026-09-13

Add an in-app help screen explaining how to use EatApp

- Add a "How to use EatApp" screen, reached from Settings, covering adding a
  restaurant, favorites vs. want-to-try, the roulette picker, sharing a
  restaurant, the home-screen widget, and exporting your data

## [2.5.2] - 2026-09-13

Fix restaurant import/export bugs found after the CSV converter release

- Always write the format field when exporting or backing up restaurants, so
  exported files show their actual on-disk format
- Retry reading a shared file's content Uri up to three times before giving
  up, so opening a Gmail attachment right after receiving it no longer fails
  with a false "can't read this file" error
- Don't let a missing street address block duplicate detection on import, so
  a restaurant already in the list is flagged instead of silently duplicated
- Timestamp the exported restaurant file's name
  (restaurants-YYYYMMDD_HHmm.eatapp) instead of reusing a fixed name
- Fix the three-way import decision buttons overflowing on long translations
  like "Reemplaça"

## [2.5.1] - 2026-09-12

Stop wiping user data on app updates with a schema version bump

- Fix destructive Room migrations silently wiping user data on schema version
  bumps; only a downgrade still falls back destructively
- Replace csv-to-eatapp.ps1 with a bidirectional eatapp/CSV converter matching
  the current v2 share schema

## [2.5.0] - 2026-09-12

Multi-visit restaurant model with photo carousel, rating trends, and a
visual refresh

- Split Restaurant into Restaurant/Visit/Photo with UUID ids, enabling
  multiple logged visits per restaurant
- Build the real visit-timeline UI and log-visit flow, and simplify Edit to
  place-level data
- Replace the single restaurant photo with a multi-photo carousel in Edit
- Add a per-visit price range and extract a shared PriceRangePicker
- Add a per-restaurant rating trend and a global average-rating trend to
  Statistics
- Replace the manual ViewModel factory with Hilt dependency injection
- Replace the default palette and type scale with the approved "mercado
  fresco" visual identity

## [2.4.1] - 2026-09-06

Remove the System theme option from Settings.

Settings' Theme picker now offers only Light and Dark — the System option
(which followed the device's own dark-mode setting) has been removed since
it wasn't intended to be a user-facing choice. Existing installs with a
saved "System" preference fall back to Light, the new default.

## [2.4.0] - 2026-09-06

Roulette visited filter and visual refresh for List, Detail, Settings and
Statistics.

- Add a want-to-try/visited filter to Roulette (`RouletteViewModel`, `RouletteScreen`).
- Visual refresh to List, Detail, Settings and Statistics — tonal header
  wash and recoloured price chip on List, borderless Overview/Rating and
  tinted Notes with an overflow menu on Detail, card-and-row layout on
  Settings, headline stat tile on Statistics.
- Fix flaky `RestaurantShareWriterTest` failures caused by `FileProvider`'s
  static `PathStrategy` cache surviving across Robolectric test methods.

## [2.3.0] - 2026-09-05

What's New in 2.3.0.

- Add restaurant visit status, photos, notes, free-form tags, and aggregate statistics.
- Add a home-screen widget showing a random "want to try" restaurant.
- Improve Favorites with search, sorting, filtering, and swipe actions.
- Add search suggestions and cuisine icons.
- Improve import compatibility and translated button layout.

## [2.2.2] - 2026-08-31

Add bulk deletion of all restaurants from Settings.

The Settings screen's Data section now includes a "Delete all restaurants"
button, giving users a quick way to clear their entire restaurant list and
reset the app without manually deleting restaurants one by one. The button
follows the existing safe-delete pattern with a confirmation dialog before
clearing the database, and the automatic on-device backup is updated to
reflect the now-empty state to keep data consistent across the app. The
feature is fully localized in English, Spanish, and Catalan.

## [2.2.1] - 2026-08-31

Add `.eatapp` file extension for restaurant export files.

Restaurant export files now use the `.eatapp` extension instead of `.json`,
giving EatApp's shared files a distinct, recognizable type. An additional
intent-filter matches the `.eatapp` extension directly, so files opened from
file managers and downloads folders are now reliably recognized and opened
by EatApp even when their MIME type isn't preserved, making the sharing
feature more dependable across more apps and contexts.

## [2.2.0] - 2026-08-30

Pivot to fully user-owned, offline restaurant data with sharing and backup.

EatApp is now a fully offline, user-owned restaurant tracker instead of a
synced and curated one. The entire remote database sync system has been
removed — no more server-side restaurant database, remote configuration, or
networking code of any kind. The `INTERNET` and `ACCESS_NETWORK_STATE`
permissions, carried over from the previous sync system, have been removed
entirely. The app now installs with an empty list and prompts users to add
their first restaurant through a new in-app form with validation, placing
complete control over their data in their hands.

Since there's no more central restaurant database, users can now share
their restaurants directly with each other: individual restaurants or the
full list can be exported as JSON through Android's native share sheet and
imported by friends. The import path is hardened for safety — files are
size-capped before parsing, validated field-by-field, and sent through a
review-and-confirm screen before any data touches the database. Incoming
restaurants are checked for duplicates by name and address, with per-row
choices to Add, Skip, or Replace.

With restaurants living only on-device and no server backup available,
automatic on-device backup has been added: a `backup.json` file is written
to the app's private storage after every change and protected by Android's
Auto Backup so phone restores and device transfers bring the data along.
Users can also manually export all their restaurant data from the Settings
screen whenever they want, for proactive backup or transfer to another
device.

## [2.1.4] - 2026-08-30

Add two-pane list-detail layout for tablet-width windows and rating filter
improvements.

Tablet users can now view restaurant lists and details side by side on
devices with adequate screen width (≥600dp). The List, Favorites, and
Roulette tabs now use a responsive `ListDetailPaneScaffold` that displays
both panes simultaneously on larger screens, providing a more immersive
browsing experience, while phones continue to navigate between full-screen
views as before. This involved refactoring the detail ViewModel to support
both navigation patterns and adding a pane-aware composition flow.

Also included are quality-of-life improvements for Roulette: the rating
filter range now starts at 1+ instead of 2+, giving users finer control
over suggestions, and the Roulette screen itself is more polished with the
result card now fully scrollable to prevent content clipping, and filter
chips wrapped across multiple lines on narrow screens instead of
horizontally scrolling off-screen.

## [2.1.3] - 2026-08-29

Pin NDK version for native debug symbols archiving.

v2.1.2 added native debug symbols archiving, but AGP requires an installed
NDK to extract symbols from dependencies' prebuilt `.so` files — without an
explicit version, the step was silently skipped and the archive remained
empty. This release pins `ndkVersion` to `28.2.13676358`, ensuring the NDK
is available so `native-debug-symbols.zip` is properly populated for Play
Console crash symbolication.

## [2.1.2] - 2026-08-29

Add native debug symbols archiving for Play Console crash symbolication.

The release build now archives native debug symbols for upload to Play
Console. While the app itself contains no native code, its dependencies may
ship prebuilt `.so` files, and archived symbols enable Play Console to
symbolicate native crashes and ANRs with full debugging information.

## [2.1.1] - 2026-08-29

Add runtime language selection and Catalan language support.

Users can now select their preferred language from Settings, choosing from
English, Spanish, and Catalan without relying on their device's system
language. This expands accessibility to Catalan-speaking users and gives
all users direct control over the app's language.

## [2.1.0] - 2026-08-29

Android package renamed to match saatxi GitHub organization.

With the project's GitHub repository moving to the saatxi organization, the
Android package name has been updated from `com.albertferran.eatapp` to
`com.saatxi.eatapp`. This aligns the app's identity with its new repository
home. Existing installations use the old package name and will need to
migrate to a new Google Play Console listing under the renamed package.

## [2.0.1] - 2026-08-29

PowerShell release-tooling improvements.

This patch release adds and fixes PowerShell scripts for automated release
Android App Bundle building on Windows, with no app behavior changes.

- Add `scripts/bundle.ps1`: new PowerShell script that automates building
  signed release Android App Bundles for Google Play upload, with
  verification of release signing configuration, optional working tree
  cleanliness and tag checks, and R8 `mapping.txt` archival alongside the
  built `.aab` file.
- Fix PowerShell 5.1 stderr redirection crash: both `bundle.ps1` and
  `release.ps1` now use `git tag --points-at HEAD` instead of
  `git describe --tags --exact-match` for handling the "not on a tag" case,
  and wrap `git rev-parse --show-toplevel` checks in try/catch blocks to
  prevent terminating `NativeCommandError` exceptions under strict error
  handling.

README.md is updated to document the new bundling script alongside existing
`gradlew bundleRelease` instructions.

## [2.0.0] - 2026-08-29

Theme customization, favorites, roulette, and adaptive navigation.

- Settings screen added with persistent user preferences; three Material 3
  color palettes (Garden, Indigo, Saffron) now selectable for app theming,
  plus dark/light mode control; Outfit typeface integrated throughout the
  interface.
- Restaurant favorites feature enables users to bookmark and manage
  favorite restaurants, accessible via a dedicated Favorites tab.
- "What to eat" roulette picker offers random restaurant suggestions
  through a new Roulette navigation tab.
- Adaptive bottom navigation and rail automatically adjust for larger
  screens and landscape orientation, optimizing the experience on tablets
  and foldable devices.
- Restaurant profiles now include website and Instagram link fields with
  comprehensive link validation to ensure only properly formatted URLs are
  stored and displayed.
- Phase 8 usability enhancements including predictive back gesture support,
  haptic feedback on interactions, collapsible filter controls, and
  segmented sort.
- Baseline Profile infrastructure scaffolded and generated on real devices
  to optimize app startup performance.
- Dependabot integration configured for automated Gradle and GitHub Actions
  dependency updates via pull requests.
- Unit test coverage expanded with new tests for link validation,
  favorites, roulette, settings, and color contrast verification;
  LazyColumn animations improved with `contentType` and `animateItem()` for
  smoother rendering and better list recycling.

## [1.4.0] - 2026-08-28

Search and sort, Material 3 design, dark mode, and Spanish support.

- Search bar refined with placeholder, clear button, and search icon;
  search now covers name, cuisine, and address.
- Restaurant sorting by name (default) or rating with stable ordering and
  tiebreaks; accessible via checkmark menu in the app bar.
- Material 3 design system completed with full tonal palette from
  terracotta seed covering all color families; dark mode window theme added
  to prevent white flash.
- Detail screen enhanced with `LargeTopAppBar` in cuisine color; shared
  element transition animates cuisine icon from list to detail with 320ms
  cross-fade.
- Spanish localization added with full plurals support; internationalization
  approach documented for future language additions.
- Accessibility enhancements with semantic descriptions on restaurant cards
  and ratings for improved screen reader support.
- Dependencies upgraded: Compose BOM to 2026.08.00, Kotlin to 2.4.10, KSP to
  2.3.11, and updates to lifecycle, activity-compose, navigation-compose,
  and coroutines; `compileSdk` bumped to 37.
- Build system migrated to AGP's built-in Kotlin compiler; `gradle.properties`
  flags cleaned; R8 minification validated.
- GitHub Actions CI workflow added to run tests, lint, and assemble on push
  and pull request.
- Compose preview composables added for list and detail screens supporting
  visual development without an emulator.

## [1.3.1] - 2026-08-27

UI polish, architecture refactoring, and release automation.

- Stabilized list refresh UI by replacing conditional swap between progress
  indicator and refresh button with always-present button disabled during
  sync, eliminating button disappearance and icon layout shift mid-refresh;
  `PullToRefreshBox`'s indicator is now the only spinner on screen (F-33).
- Introduced `RestaurantUiModel` as a dedicated UI model layer between Room
  entities and screens with `Restaurant.toUiModel()` mapper, moving
  formatting logic (price labels, star ratings, address normalization) from
  composables into the mapper; added `isInitialLoad` flag to
  `RestaurantListUiState` to prevent empty state flashing on cold start;
  expanded test suite to 93 tests (F-20, F-22).
- Added `scripts/release.ps1` to automate the release ceremony: validates
  X.Y.Z version format, prevents retagging existing releases locally or
  remotely, warns about uncommitted changes, opens editor for tag message
  composition, and pushes tags by default.

## [1.3.0] - 2026-08-27

Sync robustness improvements, search enhancements, and comprehensive
testing.

- Cap downloaded database size at 10 MB, implement ETag/If-None-Match
  support to skip re-imports of unchanged data, automatically sync on first
  launch when local database is empty, and pre-check connectivity to fail
  immediately offline (F-03, F-07, F-08, F-09).
- Escape SQL LIKE wildcards (`%` and `_`) to match literally in search, and
  add 250ms debounce on query input (F-15, F-16).
- Make searches accent- and case-insensitive, and establish Room migration
  strategy with `fallbackToDestructiveMigration` (F-14, F-17).
- Fix seven low-priority items: move sync result messages into UI state for
  config-change resilience, remove duplicated database singleton, fix "1+"
  rating filter that filtered nothing, show result count when filters are
  active, add Retry action to failed-sync snackbar, replace deprecated
  non-RTL-aware back arrow icon, fix sync-success message pluralization
  (F-21, F-24, F-27, F-31, F-34, F-45, F-46).
- Validate SQLite magic header of downloaded `.db` files before opening to
  prevent confusing errors from truncated downloads or HTML error pages
  (F-04).
- Harden sync plumbing: fix temporary file leaks on abnormal exit, stop
  rejecting legitimately empty synced datasets, make remote database URL
  configurable via `BuildConfig` (F-10, F-11, F-12).
- Add comprehensive JUnit4 test suite with 69 tests using Robolectric for
  Android runtime scenarios.
- Enable R8 code and resource optimization for release builds to
  substantially reduce APK size, and configure release signing via
  `local.properties` or environment variables.
- Extract remaining hardcoded UI strings to resources, expand cuisine
  vocabulary with Catalan and Basque, and fix launcher icon fork-and-knife
  rendering broken by zero-area subpaths.

## [1.2.0] - 2026-08-26

Add Maps integration, sync timestamp tracking, and improved search.

- Tap restaurant address to open in Maps with `geo:` intent (F-36).
- Track and display last successful sync timestamp in About dialog with
  relative time formatting (F-06).
- Expand search to cover cuisine type, address, and notes fields in
  addition to name (F-13).
- Prevent detail screen crashes and blank states: coerce price range and
  rating on import, validate data integrity, handle restaurant deletion
  gracefully with explicit loading/loaded/not-found states (F-01, F-02,
  F-19).
- Add comprehensive logging to all sync failures for on-device diagnostics
  (F-05).
- Cuisine vocabulary fully migrated to stable English keys with localized
  labels for future multi-language support.

## [1.1.0] - 2026-08-26

Material 3 UI redesign, git-tag-based versioning, and documentation
updates.

- Redesigned restaurant list and detail screens with Material 3 theming,
  cuisine-derived icon avatars, color-tinted cards, and improved layouts
  including pull-to-refresh and richer empty states.
- Added git-tag-based automatic versioning with version display UI.
- Extended Material 3 theme with custom rounded shapes and explicit
  container color roles for the terracotta/sage/cream palette.
- Updated README and added CLAUDE.md project instructions.

## [1.0.0] - 2026-08-25

Initial versioned release.
