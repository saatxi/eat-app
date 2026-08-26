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
- **No test suite exists yet** (`app/src/test`, `app/src/androidTest` are
  both empty). If you add tests, use JUnit4 + the AndroidX test libraries
  already implied by the AGP template; put unit tests under
  `app/src/test/kotlin/...` mirroring the main source package structure.

## Build & verify

```
./gradlew assembleDebug            # debug APK
./gradlew assembleRelease          # release APK
./gradlew bundleRelease            # release AAB (Play Store)
./gradlew :app:printVersionInfo    # resolved versionName/versionCode, no build needed
./gradlew lint                     # Android Lint (only static check currently wired up)
```

On Windows use `gradlew.bat`. Always run `assembleDebug` (or `lint` for a
lighter check) after a code change before reporting it as done.

## Project structure

```
app/src/main/kotlin/com/albertferran/eatapp/
├── data/
│   ├── local/        # Room entity, DAO, database, type converters
│   ├── repository/   # Repository abstraction over the data source
│   └── sync/          # Remote .db download, validation, and import
├── navigation/        # NavHost and route definitions
└── ui/
    ├── list/          # Restaurant list screen + ViewModel
    ├── detail/         # Restaurant detail screen + ViewModel
    └── theme/          # Compose theming (color, type, shape)
```

## Conventions

- All in-app strings live in `app/src/main/res/values/strings.xml` and are
  in **English** — no hardcoded UI text in Kotlin, no other language.
  Code comments are in English too.
- **Cuisine vocabulary**: the `.db` column `cuisineType` stores stable,
  language-independent keys (`japanese`, `fast_food`, etc.), never display
  labels. Each key has its own icon in [CuisineVisuals.kt](app/src/main/kotlin/com/albertferran/eatapp/ui/common/CuisineVisuals.kt)
  and a translatable label in `strings.xml`. This design means adding a
  second language later is just a new `values-xx/strings.xml` file — the
  data never changes. The full 22-key vocabulary is in [Cuisine.kt](app/src/main/kotlin/com/albertferran/eatapp/data/local/Cuisine.kt)
  and documented in the README. An unrecognised key degrades gracefully: the
  app falls back to a generic icon and shows the raw string.
- `versionCode`/`versionName` in `app/build.gradle.kts` are derived
  automatically from git (commit count / nearest tag) — never hardcode
  them. See README's "Versioning" section for the full scheme.
- Keep the app read-only from the device's perspective: there is
  intentionally no create/edit/delete UI for restaurants. Data changes
  happen by editing the source `.db` file and syncing.

## Security guidelines

- The only network call is an HTTPS GET to the hardcoded public URL in
  [`RemoteConfig.kt`](app/src/main/kotlin/com/albertferran/eatapp/data/sync/RemoteConfig.kt)
  (`DATABASE_URL`). It's a public raw GitHub content URL by design, not a
  secret — but never point it at anything requiring auth, and never embed
  API keys, tokens, or credentials anywhere in this repo (there are none
  today; keep it that way).
- The downloaded `.db` file is untrusted input: it's opened
  `OPEN_READONLY` and validated (`REQUIRED_COLUMNS` check in
  `RestaurantDatabaseSyncManager.kt`) before any row is imported. Don't
  relax this validation, don't switch to a writable connection, and don't
  execute SQL built from the file's own content — keep using parameterized
  reads.
- `INTERNET` is the only Android permission the app declares
  (`AndroidManifest.xml`). Don't add permissions (location, contacts,
  storage, etc.) without an explicit, discussed reason.
- The app stores no user credentials, no PII beyond what the user
  themselves entered into their own `.db` file, and does no analytics or
  tracking — keep it that way unless the user asks for it explicitly.
- `isMinifyEnabled = false` for release builds today (see
  `app/build.gradle.kts`). That's a deliberate current state, not
  something to silently change.
