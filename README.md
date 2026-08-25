# EatApp

An Android app to browse restaurants you've visited — name, cuisine type,
address, rating, price range, notes, and visit date.

## Features

- List restaurants, searchable by name and filterable by minimum rating
- View restaurant details (read-only)
- Refresh restaurant data on demand from a prebuilt SQLite file hosted on
  GitHub ("Refresh Data")
- View the current app version from the overflow menu ("About")

## Data source & updating restaurant data

The app is read-only: there is no way to add, edit, or delete restaurants
from the phone. Instead, the restaurant data comes from a SQLite `.db` file
you maintain on a PC and publish to a public GitHub repository.

- Edit the data with any SQLite client (e.g. [DB Browser for
  SQLite](https://sqlitebrowser.org/) or the `sqlite3` CLI) against a single
  table named `restaurants` with columns: `id`, `name`, `cuisineType`,
  `address`, `rating`, `priceRange`, `notes`, `visitDate`, `photoUri`,
  `createdAt`.
- `visitDate` must be stored as **epoch-day** (days since 1970-01-01), not as
  a date string or epoch-millis.
- `createdAt` is any long value (e.g. milliseconds since epoch at creation
  time).
- `photoUri` should be left `NULL` — it's not used by the read-only UI.
- No Room-specific bookkeeping (e.g. `room_master_table`) is required in the
  file; the app reads it with plain SQLite and imports the rows into its own
  local database.
- Publish the updated `.db` with `git add`/`commit`/`push` to the repo,
  branch, and path configured in
  [`RemoteConfig.kt`](app/src/main/kotlin/com/albertferran/eatapp/data/sync/RemoteConfig.kt)
  (`DATABASE_URL`, currently a placeholder that must be filled in).
- In the app, tap "Refresh Data" on the list screen to download and apply
  the latest published file. Sync is entirely manual — there's no
  version/freshness check, and every tap re-downloads and replaces the local
  data. A failed or invalid download leaves existing data untouched and shows
  an error.

## Tech stack

- Kotlin, Jetpack Compose, Material 3
- Navigation Compose for screen navigation
- Room for local persistence
- Kotlin Coroutines
- Plain `HttpURLConnection` for the one-shot data sync (no extra networking
  dependency)

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

## Requirements

- Android Studio (recent stable)
- JDK 17
- Min SDK 26, target/compile SDK 36

## Building

```
./gradlew assembleDebug
```

On Windows use `gradlew.bat assembleDebug`.

## Versioning

The app version is derived automatically from git — there is nothing to edit
by hand in `app/build.gradle.kts`:

- **`versionName`** comes from `git describe --tags`: `1.0.0` when `HEAD` is
  exactly on a `vX.Y.Z` tag, or `1.0.0-3-gabc1234` when 3 commits ahead of the
  last tag. If no tag exists yet it falls back to the short commit SHA.
- **`versionCode`** is the total number of commits on `HEAD`
  (`git rev-list --count HEAD`), which always increases and satisfies the
  Play Store's requirement that `versionCode` never decrease between
  releases.

The resolved version is shown in the app itself: open the three-dot menu on
the restaurant list screen → **About**.

To check what the current build will resolve to without building an APK:

```
./gradlew :app:printVersionInfo
```

## Releasing a new version

1. Make sure all changes for the release are committed (an uncommitted
   working tree produces a `-dirty` suffix in `versionName`).
2. Tag the release commit with an **annotated** tag following `vMAJOR.MINOR.PATCH`:
   ```
   git tag -a v1.1.0 -m "Describe what changed"
   git push origin v1.1.0
   ```
3. Build the release APK/AAB:
   ```
   ./gradlew assembleRelease
   ```
   or, for a Play Store upload:
   ```
   ./gradlew bundleRelease
   ```
4. Verify the packaged version before distributing:
   ```
   ./gradlew :app:printVersionInfo
   ```
   or inspect the built artifact directly:
   ```
   aapt dump badging app/build/outputs/apk/release/app-release.apk
   ```
5. Distribute the APK/AAB (sideload, internal testing track, etc.) and
   confirm the version shown in the app's **About** dialog matches the tag.

If you need to publish a fix without bumping the version number, don't
retag an existing tag — always cut a new tag (e.g. `v1.1.1`) so
`versionCode` keeps increasing.
