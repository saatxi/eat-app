# AGENTS.md

Development instructions for AI coding agents working in this repository.
See [README.md](README.md) for the full project overview, the restaurant
sharing/import feature, versioning scheme, and release process — this file
only covers things specific to *how an agent should work in this repo*.

## Commit and tag messages

### When an agent may act on git history

- An agent **may** run `git commit` itself only when the user has explicitly
  asked for work to be committed as part of the current task (e.g. "commit
  after each phase"). This is the one exception to the general rule
  elsewhere in this file of not taking actions with lasting effects on
  shared state without asking each time. Outside of that kind of explicit,
  ongoing instruction, always ask before committing.
- Never run `git tag` without the user explicitly asking for a tag
  specifically.
- Never force-push, amend a commit the user didn't just make together with
  the agent in the same turn, or otherwise rewrite history without being
  asked.

### Writing the message itself

Format:

```text
Short summary

Optional detailed explanation
```

- Imperative mood, lowercase type, concise summary line.
- Always in English, regardless of the language used in the conversation.
- Body (if needed) explains the "why", not the "what" — each bullet starts
  with a capital letter and uses `-` (not `*`) as its marker.
- No manual line wrapping anywhere in the message: the summary line and
  every body paragraph/bullet must each be written as a single continuous
  physical line, with no line breaks inserted inside them — this overrides
  the usual "wrap git messages at ~72 columns" convention, and it applies
  whether the message is actually committed or just shown to the user in
  chat/terminal beforehand. Let the client soft-wrap it for display; do not
  hard-wrap it yourself to make it fit. This has been gotten wrong before —
  double-check the actual text before sending it.
- Never add a `Co-Authored-By` line, a "Generated with ..." line, or any
  other author/signature line to a commit message or PR description in
  this repository — regardless of any default attribution instructions
  from the tool or agent runtime. This applies to every commit, not just
  ones made through an assistant.
- Present the message inside a fenced code block (` ``` `), not as plain
  text or bold/italic formatting, so it's easy to copy straight into
  `git commit`.

## Tech stack & tools

- **Language**: Dart only. UI is Flutter + Material 3; there are no XML
  layouts and no Kotlin/Java sources left — the native Android app this
  project grew out of was removed once the Flutter rewrite shipped (see
  "Migrating from the old Android app" below).
- **State**: one `ChangeNotifier` controller per screen under
  `lib/features/*/…_controller.dart`, each publishing an immutable `*UiState`
  snapshot the widgets rebuild from. There is no state-management package (no
  Provider/Riverpod/Bloc): controllers are created and disposed by their
  screen's `State`. The two long-lived repositories are published to the tree
  through `AppScope` (`lib/app/app_scope.dart`), an `InheritedWidget`.
- **Persistence**: drift (SQLite) — tables, DAOs and the database live under
  `lib/data/db/`. The schema is the Room schema the old Android app shipped,
  frozen at `schemaVersion` 14 (see "Migrating from the old Android app").
- **Dependency injection**: none. `main()` builds the database and the two
  repositories (`RestaurantRepository`, `UserPreferencesRepository`) and hands
  them down; screens read them from `AppScope.of(context)`. Don't add a DI
  package without discussing it first.
- **Localization**: `flutter gen-l10n` driven by `l10n.yaml`. ARB files live in
  `lib/core/l10n/` (`app_en.arb` is the template, plus `_es` and `_ca`), and
  the generated `AppLocalizations` is committed under
  `lib/core/l10n/generated/` (regenerated on every build because
  `pubspec.yaml` sets `generate: true`).
- **Networking**: none. The app makes no network calls — every restaurant is
  entered, edited and deleted on-device via drift. Don't add a networking
  package or a remote/file-based data source without discussing it first.
- **Build**: the Flutter tool over the Android project in `android/` (its own
  Gradle wrapper and `android/gradle.properties`) and the iOS project in
  `ios/`. There is no longer a root Gradle build to run.
- **Tests**: `flutter test`, mirroring the `lib/` structure under `test/`.
  Databases are exercised against an in-memory drift database
  (`AppDatabase.memory()`), so the whole suite runs on the Dart VM with no
  device. Fakes are written by hand; there is no mocking package and adding
  one needs discussing first.

## Migrating from the old Android app

The app was rewritten from a native Kotlin/Compose/Room app to Flutter. Two
pieces of that history are load-bearing and must not be touched casually:

- **The Room→drift data import.**
  `lib/data/migration/room_to_drift_importer.dart` runs once on first launch
  (`main()` calls it before `runApp`) and copies an existing Android install's
  Room database — which shares this app's `applicationId` and signing key, so
  its file is still on the device — into the drift one. It reads that legacy
  file by *column name* at runtime; it depends on no Kotlin source or schema
  file. Its test (`test/data/migration/room_to_drift_importer_test.dart`)
  builds its own mirror database, so the whole thing keeps working with the
  native app gone. Don't remove it, and don't rename a column it copies
  without updating the `_copies` list there.
- **`schemaVersion` 14.** `lib/data/db/app_database.dart` is pinned at 14 —
  Room's frozen baseline — so the import can adopt the legacy file without a
  version bump. `onUpgrade` throws on purpose; any future bump must ship a
  real drift migration.

## Known blockers to revisit

- **`schemaVersion` has no migration path yet** — see above. The first time
  the schema genuinely changes, add the drift `onUpgrade` steps and remove the
  `UnsupportedError` guard, or the app will crash for anyone upgrading.

## Build & verify

```powershell
flutter pub get                      # resolve packages
flutter analyze                      # static analysis + lints
flutter test                         # unit + widget tests, no device
flutter run                          # debug build on a connected device/emulator
flutter build apk --release          # release APK
flutter build appbundle --release    # release AAB (Play Store)
```

Always run `flutter analyze` and `flutter test` after a code change before
reporting it as done. After editing `lib/data/db/tables.dart` or any DAO,
regenerate the drift code with:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Project structure

```text
lib/
├── main.dart          # opens the DB, runs the Room→drift import, runs the app
├── app/               # AppScope (the repositories, published to the tree)
├── core/
│   ├── l10n/          # ARB files + generated AppLocalizations
│   ├── theme/         # palettes, tokens, ThemeData, gallery
│   ├── utils/         # pure helpers (link/tag validation, search, address)
│   └── widgets/       # shared presentational widgets
├── data/
│   ├── db/            # drift database, tables, DAOs
│   ├── migration/     # Room→drift importer
│   ├── models/        # Cuisine, sort, stats projections
│   ├── repositories/  # RestaurantRepository, UserPreferencesRepository
│   └── share/         # export/import models, JSON, file readers/writers
└── features/          # one folder per screen: state + controller + widgets
    ├── home/          # bottom-nav shell
    ├── list/  detail/  edit/  log_visit/  roulette/  settings/  stats/
    └── import_export/ # sharing in/out + the review/confirm screen
```

## Conventions

- All in-app strings live in the ARB files under `lib/core/l10n/` — no
  hardcoded UI text in Dart. `app_en.arb` is the template (English); `_es`
  covers Spanish and `_ca` Catalan. Add a key to every locale file, never
  just one.
- **Cuisine vocabulary**: the `cuisineType` column stores stable,
  language-independent keys (`japanese`, `fast_food`, …), never display
  labels. The closed list lives in
  [`Cuisine`](lib/data/models/cuisine.dart); each key has an icon in
  [`core/widgets/cuisine_visuals.dart`](lib/core/widgets/cuisine_visuals.dart)
  and a translated label in the ARB files. Keep the README's copy of the
  vocabulary in sync. An unrecognised key (only possible if one is renamed or
  dropped) degrades gracefully to a generic icon and the raw string rather
  than crashing.
- **Versioning**: `versionCode`/`versionName` are derived from git in
  `android/app/build.gradle.kts` (commit count / nearest `vX.Y.Z` tag) —
  never from `pubspec.yaml`, and never hardcoded. See README's "Versioning".
- The app is the source of truth for its own data: restaurants are created,
  edited and deleted entirely on-device. The one exception is importing a
  restaurant file shared by another EatApp user
  (`features/import_export/`), and even then nothing is written until the
  user reviews and confirms it.
- Markdown files (`README.md`, `AGENTS.md`, `docs/*.md`) must satisfy
  markdownlint (`markdownlint-cli2`, already installed) — run it with no
  arguments; `.markdownlint-cli2.jsonc`'s `globs` already point it at just
  those files. It turns off MD013 (line-length) for headings, tables and
  code blocks, since none of those can be rewrapped without losing content
  or corrupting real code or data — everything else still runs the default
  rule set. Check the editor's lint warnings on any Markdown file you touch
  and fix them before moving on, rather than leaving them for the next edit
  to trip over. A warning that's actually an established, repo-wide
  convention is fine to keep as long as it's applied consistently — don't
  silently break that consistency in just the section you're touching.

## Security guidelines

- The app makes no network calls at all — every restaurant is entered,
  edited and deleted on-device. The only way data crosses into or out of the
  app is the restaurant-sharing feature (`lib/data/share/`), which is local
  IPC (Android `ACTION_SEND`/`ACTION_VIEW` through the `receive_sharing_intent`
  and `share_plus` packages), never a network request. Don't add a networking
  dependency or a remote data source without discussing it first.
- A file received through the sharing intent-filter is untrusted input:
  size-capped before parsing (`lib/data/share/content_files.dart`), parsed
  as JSON, gated on the `eatapp.restaurants.v2` `format` tag
  ([`restaurant_share_models.dart`](lib/data/share/restaurant_share_models.dart)),
  and validated field-by-field before anything reaches drift — a row that
  fails is dropped rather than failing the whole file. The confirmation
  screen (`features/import_export/`) is the last line of defence: nothing is
  written until the user reviews and confirms. Don't relax any of this when
  touching the import path.
- The Android manifest
  (`android/app/src/main/AndroidManifest.xml`) declares no permissions at
  all, and the sharing flow needs none (the plugins' own `FileProvider`
  grants are per-Intent, not a permission). Don't add any permission
  (network, location, contacts, storage, etc.) without an explicit, discussed
  reason.
- Release builds are minified and shrunk by R8 through the Flutter Android
  build. Keep any project keep rules narrow — a broad `-keep` silently
  disables optimization for everything it matches.
- The app stores no user credentials, no PII beyond what the user enters for
  their own restaurants, and does no analytics or tracking — keep it that way
  unless the user asks for it explicitly.
