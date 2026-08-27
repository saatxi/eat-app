# EatApp

An Android app to browse restaurants you've visited — name, cuisine type,
address, rating and price range.

## Features

- List restaurants, searchable across name, cuisine and address
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
  `address`, `rating`, `priceRange`.
- `cuisineType` must be one of the **cuisine keys** listed below — a stable,
  language-independent identifier such as `fast_food`, never a display label
  such as `Fast food`. The app maps the key to both an icon and a translated
  label, which is what makes adding a second language later a matter of adding
  `values-es/strings.xml` and nothing else: the data file never has to change.
- `address` is the only nullable column; every other one is `NOT NULL`. A row
  needs six values and nothing else.
- Extra columns are ignored rather than rejected, so a file that still carries
  the dropped `notes`, `createdAt`, `visitDate` or `photoUri` columns keeps
  importing unchanged.
- No Room-specific bookkeeping (e.g. `room_master_table`) is required in the
  file; the app reads it with plain SQLite and imports the rows into its own
  local database.
- Publish the updated `.db` with `git add`/`commit`/`push` to the repo, branch
  and path the build points at. The release URL is hardcoded as
  `releaseDatabaseUrl` in [`app/build.gradle.kts`](app/build.gradle.kts) and
  reaches the app as `BuildConfig.DATABASE_URL` through
  [`RemoteConfig.kt`](app/src/main/kotlin/com/albertferran/eatapp/data/sync/RemoteConfig.kt);
  a debug build can be pointed elsewhere without editing source, see
  [Pointing a debug build at other data](#pointing-a-debug-build-at-other-data).
- In the app, tap "Refresh Data" on the list screen to download and apply
  the latest published file. Sync is entirely manual — there's no
  version/freshness check, and every tap re-downloads and replaces the local
  data. A failed or invalid download leaves existing data untouched and shows
  an error. A file with zero rows is *not* an error: it is how you empty the
  list, so publishing one clears the app's data on the next refresh.

### Pointing a debug build at other data

Testing against a branch, a fork or a second data file doesn't need a source
edit. Set the URL in `local.properties` (gitignored):

```
eatapp.database.url=https://raw.githubusercontent.com/<you>/<fork>/<branch>/data/eatapp.db
```

or as an environment variable, which is what CI would use:

| `local.properties` | Environment variable |
| --- | --- |
| `eatapp.database.url` | `EATAPP_DATABASE_URL` |

Only **debug** builds read it — a release build always uses the hardcoded
release URL, so an override can't escape into a published APK. The value must
start with `https://`; anything else fails the build at configuration time,
since the app declares no cleartext traffic permission and would only fail
later with a confusing network error.

### Cuisine keys

The valid values for `cuisineType`. Each one has its own icon in the app, and
the list screen offers a filter chip for every key present in your data.

| Key | Shown as | | Key | Shown as |
|---|---|---|---|---|
| `mediterranean` | Mediterranean | | `bar` | Bar |
| `spanish` | Spanish | | `beer_bar` | Beer bar |
| `catalan` | Catalan | | `wine_bar` | Wine bar |
| `basque` | Basque | | `cafe` | Cafe |
| `italian` | Italian | | `bakery` | Bakery |
| `japanese` | Japanese | | `dessert` | Dessert |
| `chinese` | Chinese | | `breakfast` | Breakfast |
| `asian` | Asian | | `brunch` | Brunch |
| `indian` | Indian | | `grill` | Grill |
| `middle_eastern` | Middle Eastern | | `fast_food` | Fast food |
| `american` | American | | `fine_dining` | Fine dining |
| `seafood` | Seafood | | `vegetarian` | Vegetarian |

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

## App optimization (R8)

Release builds go through [R8](https://developer.android.com/topic/performance/app-optimization/enable-app-optimization),
which shrinks and obfuscates the code and strips unused resources. It is turned
on in `app/build.gradle.kts` with the AGP 9.3+ `optimization {}` DSL:

```kotlin
buildTypes {
    release {
        optimization {
            enable = true
        }
    }
}
```

One flag covers both halves — code shrinking and resource shrinking — and the
platform keep rules (the equivalent of `proguard-android-optimize.txt`) are
included automatically, so there is no `proguardFiles` line and no
`proguard-rules.pro` any more. R8 full mode is on, which is the AGP 8+ default.

The effect on the packaged APK is large, because most of what the app pulls in
from Compose, Material 3 and Room is never reached:

| Release APK | Size |
| --- | --- |
| Without optimization | ~11.2 MB |
| With optimization | ~1.3 MB |

Debug builds are deliberately left unoptimized so they stay fast to build and
easy to debug.

### Keep rules

Project keep rules live in `app/src/main/keepRules/*.keep` — the source-set
location AGP 9.3+ uses, not a `proguard-rules.pro` at the module root. That file
carries no actual rules on purpose: the app itself uses no reflection, and Room,
the one dependency that resolves generated classes by name, already ships its
own consumer keep rules.

If a release build ever misbehaves in a way the debug build does not, that is
the file to add a narrow `-keep` rule to. Keep such rules as specific as
possible — a broad `-keep` switches off optimization for everything it matches.
`app/build/outputs/mapping/release/configanalyzer.html` is R8's own report on
which rules are redundant or too wide.

### Deobfuscating stack traces

Every release build writes `app/build/outputs/mapping/release/mapping.txt`,
which maps the obfuscated names back to the original ones. Android Studio's
Logcat retraces stack traces automatically when it can find that file, so
**keep the `mapping.txt` of every release you actually distribute** — the build
directory is gitignored and the next build overwrites it.

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
   [`scripts/release.ps1`](scripts/release.ps1) does exactly that, with a few
   guard rails: it asks for the version as `X.Y.Z`, refuses a tag that already
   exists locally or on the remote, warns about an uncommitted working tree,
   opens your editor for the tag message and then pushes the tag.
   ```
   ./scripts/release.ps1                  # asks for the version
   ./scripts/release.ps1 -Version 1.1.0   # or pass it directly
   ```
   Add `-NoPush` to create the tag without pushing it.
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
5. Because release builds are optimized by R8 while debug builds are not, install
   the release artifact on a device and smoke-test it — open the list, search,
   filter, open a detail screen and run a data sync — before handing it to
   anyone. Archive `app/build/outputs/mapping/release/mapping.txt` alongside the
   artifact: without it, crash reports from that build are unreadable, and the
   next build overwrites the file (see **App optimization (R8)** above).
6. Distribute the APK/AAB (sideload, internal testing track, etc.) and
   confirm the version shown in the app's **About** dialog matches the tag.

If you need to publish a fix without bumping the version number, don't
retag an existing tag — always cut a new tag (e.g. `v1.1.1`) so
`versionCode` keeps increasing.
