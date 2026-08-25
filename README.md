# EatApp

An Android app to browse restaurants you've visited — name, cuisine type,
address, rating, price range, notes, and visit date.

## Features

- List restaurants, searchable by name and filterable by minimum rating
- View restaurant details (read-only)
- Refresh restaurant data on demand from a prebuilt SQLite file hosted on
  GitHub ("Actualizar datos")

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
  [`RemoteConfig.kt`](app/src/main/java/com/albertferran/eatapp/data/sync/RemoteConfig.kt)
  (`DATABASE_URL`, currently a placeholder that must be filled in).
- In the app, tap "Actualizar datos" on the list screen to download and apply
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
app/src/main/java/com/albertferran/eatapp/
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
