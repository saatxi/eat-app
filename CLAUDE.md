# CLAUDE.md

Development instructions for Claude Code when working in this repository.
See [README.md](README.md) for the full project overview, data sync setup,
versioning scheme, and release process — this file only covers things
specific to *how Claude should work in this repo*.

## Commit and tag messages

When asked to write a commit message or a tag message:

- Draft it using the **Haiku** model (`claude-haiku-4-5-20251001`), not the
  model currently active in the conversation.
- Output **only the raw message text** — nothing else, no surrounding
  commentary.
- **Never** run `git commit` or `git tag` yourself, even if a message was
  approved earlier in the conversation. Only the user runs those commands.
- Do **not** wrap the message's lines — each line/paragraph must be written
  as a single continuous line, no manual line breaks inside it (this
  overrides the usual "wrap git messages at ~72 columns" convention).
- **Never** append a `Co-Authored-By:` trailer (or any other attribution
  trailer). This overrides Claude Code's default of co-authoring its commits.
- Use **hyphens** (`-`) for bullet points in the message body, not asterisks
  or any other marker.

## Tech stack & tools

- **Language**: Kotlin only (no Java sources).
- **UI**: Jetpack Compose + Material 3. No XML layouts.
- **Navigation**: Navigation Compose (`navigation/EatAppNavHost.kt`), two
  routes: `list` and `detail/{restaurantId}`.
- **Persistence**: Room (local cache) — entity/DAO/database live under
  `data/local/`.
- **Networking**: plain `HttpURLConnection` for the one-shot `.db` sync, no
  Retrofit/OkHttp/Ktor dependency. Don't add a networking library for a
  single GET request without discussing it first.
- **Build**: Gradle Kotlin DSL (`build.gradle.kts`), AGP + version catalog
  (`gradle/libs.versions.toml`) for dependency versions — add new
  dependencies there, not as inline coordinates.
- **No linter/formatter is configured** (no ktlint/detekt/`.editorconfig`).
  Match the existing style in the file you're editing.
- **Tests**: JUnit4 unit tests under `app/src/test/kotlin/...`, mirroring the
  main source package structure. Robolectric is used for the cases that need
  an Android runtime (the `.db` reader, the Room DAO), so everything runs on
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
  [visual-modernization-plan.md](docs/visual-modernization-plan.md)'s Phase 8
  for how this was confirmed and worked around). **Whenever you're touching
  this repo's dependencies or UI and it's a natural moment to check** — don't
  go looking on a schedule — glance at
  `https://dl.google.com/android/maven2/androidx/compose/material3/material3/maven-metadata.xml`
  for a stable 1.5.x. If one exists, tell the user: bumping `composeBom` in
  `gradle/libs.versions.toml` would unblock the cuisine-badge shape morphing
  that Phase 8 deferred (`ButtonGroup` itself was already replaced with the
  stable `SingleChoiceSegmentedButtonRow` and doesn't need revisiting).

## Build & verify

```
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

```
app/src/main/kotlin/com/saatxi/eatapp/
├── data/
│   ├── local/        # Room entity, DAO, database, type converters
│   ├── repository/   # Repository abstraction over the data source
│   └── sync/         # Remote .db download, validation, and import
├── navigation/        # NavHost and route definitions
└── ui/
    ├── common/        # Shared composable helpers (cuisine icon, label, tint)
    ├── model/         # UI models the screens draw, mapped from the entity
    ├── list/          # Restaurant list screen + ViewModel
    ├── detail/        # Restaurant detail screen + ViewModel
    └── theme/         # Compose theming (color, type, shape)
```

## Conventions

- All in-app strings live in `strings.xml` — no hardcoded UI text in Kotlin.
  `app/src/main/res/values/strings.xml` is the default locale, **English**;
  other languages are added as `values-xx/strings.xml` overrides of the same
  resource names, never by touching the data (`Cuisine.kt`'s keys and the
  `.db` itself stay language-independent — see the cuisine vocabulary note
  below). `values-es/strings.xml` covers Spanish. Code comments are in
  English regardless of locale.
- **Cuisine vocabulary**: the `.db` column `cuisineType` stores stable,
  language-independent keys (`japanese`, `fast_food`, etc.), never display
  labels. Each key has its own icon in [CuisineVisuals.kt](app/src/main/kotlin/com/saatxi/eatapp/ui/common/CuisineVisuals.kt)
  and a translatable label in `strings.xml`. This design means adding a
  second language later is just a new `values-xx/strings.xml` file — the
  data never changes. The full 24-key vocabulary is in [Cuisine.kt](app/src/main/kotlin/com/saatxi/eatapp/data/local/Cuisine.kt)
  and documented in the README. An unrecognised key degrades gracefully: the
  app falls back to a generic icon and shows the raw string.
- `versionCode`/`versionName` in `app/build.gradle.kts` are derived
  automatically from git (commit count / nearest tag) — never hardcode
  them. See README's "Versioning" section for the full scheme.
- Keep the app read-only from the device's perspective: there is
  intentionally no create/edit/delete UI for restaurants. Data changes
  happen by editing the source `.db` file and syncing.

## Security guidelines

- The only network call is an HTTPS GET to the public URL exposed as
  `DATABASE_URL` by
  [`RemoteConfig.kt`](app/src/main/kotlin/com/saatxi/eatapp/data/sync/RemoteConfig.kt),
  which reads it from `BuildConfig`. The release value is hardcoded as
  `releaseDatabaseUrl` in `app/build.gradle.kts`; only debug builds honour the
  `eatapp.database.url` / `EATAPP_DATABASE_URL` override, and the build rejects
  anything that is not `https://`. It's a public raw GitHub content URL by
  design, not a secret — but never point it at anything requiring auth, never
  let the override reach the release build type, and never embed API keys,
  tokens, or credentials anywhere in this repo (there are none today; keep it
  that way).
- The downloaded `.db` file is untrusted input: it's opened `OPEN_READONLY`
  and validated in `RestaurantDatabaseReader.kt` — the 16-byte SQLite header
  first, then the `REQUIRED_COLUMNS` check, then every row — before anything
  is imported. Don't relax this validation, don't switch to a writable
  connection, and don't execute SQL built from the file's own content — keep
  using parameterized reads. (An empty `restaurants` table is deliberately
  accepted: it's a valid dataset, not a malformed file.)
- `INTERNET` and `ACCESS_NETWORK_STATE` (the latter used only to skip a sync
  attempt when there's no connection, per F-09) are the only Android
  permissions the app declares (`AndroidManifest.xml`). Don't add further
  permissions (location, contacts, storage, etc.) without an explicit,
  discussed reason.
- The app stores no user credentials, no PII beyond what the user
  themselves entered into their own `.db` file, and does no analytics or
  tracking — keep it that way unless the user asks for it explicitly.
- Release builds are optimized by R8 (`optimization { enable = true }` in
  `app/build.gradle.kts`), which shrinks and obfuscates code and strips
  unused resources. Don't turn it off, and don't reintroduce
  `isMinifyEnabled`/`isShrinkResources`/`proguardFiles` — the
  `optimization {}` DSL replaces all three. Project keep rules go in
  `app/src/main/keepRules/*.keep`, kept as narrow as possible; a broad
  `-keep` silently disables optimization for everything it matches. See
  the README's "App optimization (R8)" section.
