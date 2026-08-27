# EatApp

An Android app to browse restaurants you've visited — name, cuisine type,
address, rating, price range, notes, and visit date.

## Features

- List restaurants, searchable across name, cuisine, address and notes
  (accent- and case-insensitive), and filterable by minimum rating and
  cuisine type
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
- `cuisineType` must be one of the **cuisine keys** listed below — a stable,
  language-independent identifier such as `fast_food`, never a display label
  such as `Fast food`. The app maps the key to both an icon and a translated
  label, which is what makes adding a second language later a matter of adding
  `values-es/strings.xml` and nothing else: the data file never has to change.
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

### Cuisine keys

The valid values for `cuisineType`. Each one has its own icon in the app, and
the list screen offers a filter chip for every key present in your data.

| Key | Shown as | | Key | Shown as |
|---|---|---|---|---|
| `mediterranean` | Mediterranean | | `bar` | Bar |
| `spanish` | Spanish | | `beer_bar` | Beer bar |
| `italian` | Italian | | `wine_bar` | Wine bar |
| `japanese` | Japanese | | `cafe` | Cafe |
| `chinese` | Chinese | | `bakery` | Bakery |
| `asian` | Asian | | `dessert` | Dessert |
| `indian` | Indian | | `breakfast` | Breakfast |
| `middle_eastern` | Middle Eastern | | `brunch` | Brunch |
| `american` | American | | `grill` | Grill |
| `seafood` | Seafood | | `fast_food` | Fast food |
| | | | `fine_dining` | Fine dining |
| | | | `vegetarian` | Vegetarian |

An unrecognised value never breaks a sync: the app falls back to a generic
icon and displays the raw string as-is. That means a data file using a key
added in a newer release still works on an older build, and a typo costs you
an icon rather than a failed refresh.

The vocabulary is defined in
[`Cuisine.kt`](app/src/main/kotlin/com/albertferran/eatapp/data/local/Cuisine.kt) —
keep this table in sync with it when adding a key.

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

## Tests

```
./gradlew test
```

Unit tests live in `app/src/test/kotlin/`, mirroring the main package
structure. They run on the JVM with no emulator or device: the ones that need
an Android runtime — the `.db` reader and the Room DAO — use Robolectric, so a
single command covers everything.

What is covered:

- `SearchNormalizerTest` — the accent and case folding behind the search.
- `CuisineTest` — resolving `cuisineType` keys, including unknown ones.
- `RestaurantDatabaseReaderTest` — validation of the downloaded `.db`: missing
  columns, NULL and blank fields, out-of-range ratings and price ranges, and
  files that are not SQLite at all.
- `RestaurantDaoTest` — the filter query against an in-memory Room database.
- `RestaurantListViewModelTest` — how the three filter inputs combine into one
  query and one UI state.

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

## Signing releases

Release builds are signed with your own keystore. Neither the keystore nor its
passwords are ever committed — the build reads them from `local.properties`
(which is gitignored) or, for CI, from environment variables. `*.jks` and
`*.keystore` are gitignored too, so a keystore left in the project directory
cannot be committed by accident.

**Create a keystore once** (keep it somewhere safe and backed up — losing it
means you can never update the app on the Play Store again):

```
keytool -genkeypair -v -keystore eatapp-release.jks -alias eatapp \
  -keyalg RSA -keysize 2048 -validity 10000
```

**Point the build at it** by adding these to `local.properties`. A relative
path resolves against the repository root; an absolute path is used as is:

```
eatapp.keystore.file=../eatapp-release.jks
eatapp.keystore.password=<store password>
eatapp.key.alias=eatapp
eatapp.key.password=<key password>
```

The same four values can be supplied as environment variables instead, which
is what CI should use:

| `local.properties` | Environment variable |
| --- | --- |
| `eatapp.keystore.file` | `EATAPP_KEYSTORE_FILE` |
| `eatapp.keystore.password` | `EATAPP_KEYSTORE_PASSWORD` |
| `eatapp.key.alias` | `EATAPP_KEY_ALIAS` |
| `eatapp.key.password` | `EATAPP_KEY_PASSWORD` |

If none of this is configured, `assembleRelease` and `bundleRelease` still
succeed but produce an **unsigned** artifact that cannot be installed or
uploaded. The build prints a warning saying so, and the APK is named
`app-release-unsigned.apk` rather than `app-release.apk`.

To confirm a built APK really is signed:

```
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
```

## Releasing a new version

1. Make sure all changes for the release are committed (an uncommitted
   working tree produces a `-dirty` suffix in `versionName`).
2. Tag the release commit with an **annotated** tag following `vMAJOR.MINOR.PATCH`:
   ```
   git tag -a v1.1.0 -m "Describe what changed"
   git push origin v1.1.0
   ```
3. Make sure signing is configured (see **Signing releases** above) — without it
   the build succeeds but the artifact is unusable. Then build the release
   APK/AAB:
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
   Confirm it is signed too:
   ```
   apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
   ```
5. Distribute the APK/AAB (sideload, internal testing track, etc.) and
   confirm the version shown in the app's **About** dialog matches the tag.

If you need to publish a fix without bumping the version number, don't
retag an existing tag — always cut a new tag (e.g. `v1.1.1`) so
`versionCode` keeps increasing.
