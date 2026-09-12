# CLAUDE.md

Development instructions for Claude Code when working in this repository.
See [README.md](README.md) for the full project overview, the restaurant
sharing/import feature, versioning scheme, and release process — this file
only covers things specific to *how Claude should work in this repo*.

## Commit and tag messages

### When Claude may act on git history

- Claude **may** run `git commit` itself only when the user has explicitly
  asked for work to be committed as part of the current task (e.g. "commit
  after each phase"). This is the one exception to the general rule
  elsewhere in this file of not taking actions with lasting effects on
  shared state without asking each time. Outside of that kind of explicit,
  ongoing instruction, always ask before committing.
- Never run `git tag` without the user explicitly asking for a tag
  specifically.
- Never force-push, amend a commit the user didn't just make together with
  Claude in the same turn, or otherwise rewrite history without being
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

- **Language**: Kotlin only (no Java sources).
- **UI**: Jetpack Compose + Material 3. No XML layouts, with one narrow,
  unavoidable exception: the home-screen widget's AppWidget provider XML
  requires an `initialLayout` pointing at a real RemoteViews layout
  (`res/layout/widget_loading.xml`) — a framework requirement, not a
  regression. The widget's actual content (`widget/WantToTryWidget.kt`) is
  Glance, not a View-based layout.
- **Navigation**: Navigation Compose (`navigation/EatAppNavHost.kt`) — the
  four top-level tabs (`list`, `favorites`, `roulette`, `settings`) plus
  `detail/{restaurantId}`, `add`, `edit/{restaurantId}` and
  `import/{uri}`.
- **Persistence**: Room (local cache) — entity/DAO/database live under
  `data/local/`.
- **Dependency injection**: Hilt. `EatApplication` is `@HiltAndroidApp`;
  `MainActivity` is `@AndroidEntryPoint`; every screen ViewModel is
  `@HiltViewModel` with an `@Inject constructor` and obtained via
  `hiltViewModel()` from Compose Nav (`androidx.hilt:hilt-navigation-compose`).
  Modules live under `di/` (`AppModule` for `@Provides`, `BindsModule` for
  `@Binds` interface bindings, `EntryPoints` for the few call sites — the
  home-screen widget, and the two-pane list-detail layout's detail pane —
  that aren't themselves Hilt injection points). A screen ViewModel that
  needs a nav-supplied argument (`restaurantId`, the import screen's `uri`)
  reads it off an injected `SavedStateHandle` rather than an assisted-inject
  factory.
- **Networking**: none. The app makes no network calls — every restaurant is
  entered, edited and deleted on-device via Room. Don't add a networking
  library or a remote/file-based data source without discussing it first.
- **Build**: Gradle Kotlin DSL (`build.gradle.kts`), AGP + version catalog
  (`gradle/libs.versions.toml`) for dependency versions — add new
  dependencies there, not as inline coordinates.
- **No linter/formatter is configured** (no ktlint/detekt/`.editorconfig`).
  Match the existing style in the file you're editing.
- **Tests**: JUnit4 unit tests under `app/src/test/kotlin/...`, mirroring the
  main source package structure. Robolectric is used for the cases that need
  an Android runtime (the Room DAO), so everything runs on
  the JVM with `./gradlew test` and no emulator is ever required — that stays
  true and does not change. `app/src/androidTest` is still empty on purpose.
  Fakes are written by hand; there is no mocking library and adding one needs
  discussing first. What *is* allowed is instrumented tests in the
  `:baselineprofile` module (`com.android.test`, added for the Baseline
  Profile — see README), which run only on demand via
  `:baselineprofile:...AndroidTest` tasks (or the `:app:generateBaselineProfile`
  umbrella task) and never from `./gradlew test`.

## Known blockers to revisit

- **material3 stable version**: as of 2026-08-29, `androidx.compose.material3:material3`
  resolves to **1.4.0** under the current `composeBom` in
  `gradle/libs.versions.toml`, and the M3 Expressive `ButtonGroup` and
  `MaterialShapes` APIs don't exist in it — both only ship from
  `1.5.0-alpha01` onward, and 1.5.0 has no stable release yet (see
  [development-log.md](docs/development-log.md)'s Appendix A, Phase 8, for
  how this was confirmed and worked around). **Whenever you're touching
  this repo's dependencies or UI and it's a natural moment to check** — don't
  go looking on a schedule — glance at
  `https://dl.google.com/android/maven2/androidx/compose/material3/material3/maven-metadata.xml`
  for a stable 1.5.x — last checked 2026-09-12, still only alphas
  (`1.5.0-alpha28`). If one exists, tell the user: bumping `composeBom` in
  `gradle/libs.versions.toml` would unblock the cuisine-badge shape morphing
  that Phase 8 deferred (`ButtonGroup` itself was already replaced with the
  stable `SingleChoiceSegmentedButtonRow` and doesn't need revisiting).
  `material3Adaptive` (`1.3.0` in the same catalog, versioned independently)
  is worth re-checking at the same time — last checked 2026-09-12, still no
  stable release past `1.3.0` (latest overall is `1.4.0-alpha01`) — see
  [development-log.md](docs/development-log.md)'s F-73.
- ~~**Baseline Profile plugin pinned to a pre-release**~~ — resolved
  2026-09-12: `androidx.baselineprofile` (and `androidx.benchmark:benchmark-macro-junit4`)
  reached a stable `1.5.0`, so `baselineProfile` in
  `gradle/libs.versions.toml` now points at `1.5.0` instead of the
  `1.5.0-rc02` pre-release it used to need for AGP 9.3.2 compatibility (see
  [development-log.md](docs/development-log.md)'s Appendix A, Phase 7, and
  F-73 for the original blocker). Verified against this project's current
  AGP (9.4.0) with `:baselineprofile:tasks`, `./gradlew test` and
  `./gradlew assembleDebug` — all pass.

## Build & verify

```powershell
./gradlew assembleDebug            # debug APK
./gradlew assembleRelease          # release APK
./gradlew bundleRelease            # release AAB (Play Store)
./gradlew :app:printVersionInfo    # resolved versionName/versionCode, no build needed
./gradlew test                     # JVM unit tests (Robolectric, no emulator)
./gradlew lint                     # Android Lint
```

On Windows use `gradlew.bat`. Always run `test` and `assembleDebug` after a
code change before reporting it as done.

## Project structure

```text
app/src/main/kotlin/com/saatxi/eatapp/
├── data/
│   ├── local/         # Room entity, DAO, database, link validation
│   ├── repository/    # Repository abstraction over the data source
│   └── share/         # Export/import models, JSON (de)serialization, FileProvider writer
├── navigation/        # NavHost and route definitions
├── widget/            # Home-screen widget (Glance), not part of the nav graph
└── ui/
    ├── common/        # Shared composable helpers (cuisine icon/label/tint, sharing intent)
    ├── model/         # UI models the screens draw, mapped from the entity
    ├── list/          # Restaurant list screen + ViewModel
    ├── detail/        # Restaurant detail screen + ViewModel
    ├── edit/          # Add/edit restaurant form + ViewModel
    ├── importing/     # Received-file review/confirm screen + ViewModel
    └── theme/         # Compose theming (color, type, shape)
```

## Conventions

- All in-app strings live in `strings.xml` — no hardcoded UI text in Kotlin.
  `app/src/main/res/values/strings.xml` is the default locale, **English**;
  other languages are added as `values-xx/strings.xml` overrides of the same
  resource names, never by touching the data (`Cuisine.kt`'s keys stay
  language-independent — see the cuisine vocabulary note below).
  `values-es/strings.xml` covers Spanish, `values-ca/strings.xml` Catalan.
  Code comments are in English regardless of locale.
- **Cuisine vocabulary**: the `cuisineType` column stores stable,
  language-independent keys (`japanese`, `fast_food`, etc.), never display
  labels — the add/edit form's dropdown only ever writes a key from this
  closed list. Each key has its own icon in [CuisineVisuals.kt](app/src/main/kotlin/com/saatxi/eatapp/ui/common/CuisineVisuals.kt)
  and a translatable label in `strings.xml`. This design means adding a
  second language later is just a new `values-xx/strings.xml` file. The
  full 24-key vocabulary is in [Cuisine.kt](app/src/main/kotlin/com/saatxi/eatapp/data/local/Cuisine.kt)
  and documented in the README. An unrecognised key (only possible if a key
  is ever renamed or dropped, orphaning existing rows) degrades gracefully:
  the app falls back to a generic icon and shows the raw string.
- `versionCode`/`versionName` in `app/build.gradle.kts` are derived
  automatically from git (commit count / nearest tag) — never hardcode
  them. See README's "Versioning" section for the full scheme.
- The app is the source of truth for its own data: restaurants are created,
  edited and deleted entirely on-device, via the add/edit form
  (`ui/edit/`) and the detail screen's delete action. The one exception is
  importing a restaurant file shared by another EatApp user
  (`ui/importing/`), and even then nothing is written until the user reviews
  and confirms it on that screen.
- Markdown files (`README.md`, `CLAUDE.md`, `docs/*.md`) must satisfy
  markdownlint (`markdownlint-cli2`, already installed) — run it with no
  arguments; `.markdownlint-cli2.jsonc`'s `globs` already point it at just
  those files, and it `ignores` `.claude/` (third-party skill repos tracked
  as gitlinks, not this project's own docs). It also turns off MD013
  (line-length) for headings, tables and code blocks, since none of those
  can be rewrapped without either losing content or corrupting real code or
  data — everything else still runs the default rule set. A single
  otherwise-unfixable line (a benchmark output path in
  `docs/development-log.md` whose only whitespace falls past column 80) is
  suppressed individually with a `markdownlint-disable-next-line` comment
  rather than loosening a rule for the whole file. Check the editor's lint
  warnings on any Markdown file you touch and fix them before moving on,
  rather than leaving them for the next edit to trip over. A warning that's
  actually an established, repo-wide convention (e.g.
  `docs/development-log.md`'s "— Done" section headings dropping their
  trailing period so MD026 doesn't fire) is fine to keep as long as it's
  applied consistently — don't silently break that consistency
  in just the section you're touching.

## Security guidelines

- The app makes no network calls at all — every restaurant is entered,
  edited and deleted on-device. The only way data ever crosses into or out of
  the app is the restaurant-sharing feature (`data/share/`), which is local
  IPC (`Intent.ACTION_SEND`/`ACTION_VIEW` + a `FileProvider`), never a
  network request. Don't add a networking dependency or a remote data source
  without discussing it first.
- A file received through the sharing intent-filter (`MainActivity`'s second
  `<intent-filter>`, matching `application/json`) is untrusted input, the
  same way the old synced `.db` was: capped at `MAX_IMPORT_BYTES` before
  parsing (`data/share/ContentFiles.kt`), parsed with `kotlinx.serialization`
  rather than a reflection-based library, gated on the `format` tag in
  `RestaurantShareModels.kt`, and validated field-by-field
  (`RestaurantExport.toRestaurantOrNull`) before anything reaches Room — a
  row that fails validation is dropped rather than failing the whole file.
  The confirmation screen (`ui/importing/`) is the last line of defence nothing
  is written until the user reviews and confirms it. Don't relax any of this
  when touching the import path.
- The `FileProvider` (`res/xml/file_paths.xml`) only exposes
  `cacheDir/shared/`, the folder `RestaurantShareWriter.kt` writes to — never
  widen it to a broader path, and keep `android:exported="false"` on the
  `<provider>` entry.
- The home-screen widget's `<receiver>` (`widget/WantToTryWidgetReceiver.kt`)
  is `android:exported="false"`: the system delivers `APPWIDGET_UPDATE` (a
  protected, system-only broadcast) directly, so the launcher never needs to
  call it. It reads from Room and needs no permission; keep it that way.
- `AndroidManifest.xml` declares no permissions at all — `INTERNET` and
  `ACCESS_NETWORK_STATE`, left over from the removed remote sync feature,
  were removed along with it, and the sharing feature needs none either
  (`FileProvider` grants are per-Intent, not a permission). Don't add any
  permission (network, location, contacts, storage, etc.) without an
  explicit, discussed reason.
- The app stores no user credentials, no PII beyond what the user
  themselves enters for their own restaurants, and does no analytics or
  tracking — keep it that way unless the user asks for it explicitly.
- Release builds are optimized by R8 (`optimization { enable = true }` in
  `app/build.gradle.kts`), which shrinks and obfuscates code and strips
  unused resources. Don't turn it off, and don't reintroduce
  `isMinifyEnabled`/`isShrinkResources`/`proguardFiles` — the
  `optimization {}` DSL replaces all three. Project keep rules go in
  `app/src/main/keepRules/*.keep`, kept as narrow as possible; a broad
  `-keep` silently disables optimization for everything it matches. See
  the README's "App optimization (R8)" section.
