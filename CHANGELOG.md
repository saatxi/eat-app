# Changelog

All notable changes to EatApp are documented here, one entry per release
tag, newest first. Loosely follows the spirit of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); entries are
derived from this repo's annotated git tag messages (`git tag -l -n99`)
rather than hand-maintained separately, so the wording matches what was
tagged at release time. Versioning follows the `vMAJOR.MINOR.PATCH` scheme
described in [README.md](README.md#versioning) — `versionName`/`versionCode`
are always derived from git, never hand-edited.

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
