# EatApp

An Android app to browse restaurants you've visited — name, cuisine type,
address, rating and price range.

## Features

- List restaurants, searchable across name, cuisine and address
  (accent- and case-insensitive), and filterable by minimum rating and
  cuisine type
- Sort the list by name or by rating (highest first), from the app bar
- Add, edit and delete your own restaurants from the phone, including links
  to the restaurant's website and Instagram when you provide them
- View the current app version from the overflow menu ("About")

## Managing your restaurants

The app installs with an empty list — there is no bundled or downloaded
dataset. Every restaurant is entered by hand, from the phone:

- Tap the **+** button on the list screen to add a restaurant: name, cuisine,
  address, rating, price range, and the two optional links below.
- Tap a restaurant's **Edit** action on its detail screen to change any of
  those fields, or **Delete** to remove it (with a confirmation prompt first).
- `cuisineType` is chosen from a closed, **stable, language-independent**
  vocabulary — a key such as `fast_food`, never a display label such as
  `Fast food`. The app maps the key to both an icon and a translated label,
  which is what makes adding a second language later a matter of adding
  `values-xx/strings.xml` and nothing else.

#### The optional links

Website and Instagram add a "Links" section to the restaurant detail screen.
Both are validated as you type, the same whitelist either way:

- **Website** must be a plain `http`/`https` web address. A bare host
  (`calferran.example`) is accepted and read as `https://`. Anything else
  (`javascript:`, `intent:`, `file:`, a custom scheme) is rejected with an
  inline error rather than saved — the app opens this value with an
  `ACTION_VIEW` intent, so this is what stops a link from choosing what the
  app launches.
- **Instagram** is the **handle**, not a URL: `cal_ferran` or `@cal_ferran`,
  up to 30 letters, digits, periods and underscores. The app builds
  `https://instagram.com/<handle>` itself, which is what makes the scheme
  impossible to influence from user input. Android deep-links that URL into
  the Instagram app when it's installed.

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

The add/edit form only ever writes a key from this closed list, so an
"unrecognised value" can only happen if a key is ever renamed or dropped from
[`Cuisine.kt`](app/src/main/kotlin/com/saatxi/eatapp/data/local/Cuisine.kt) —
in that case existing rows still using the old key degrade gracefully to a
generic icon and the raw string, rather than crashing.

Keep this table in sync with `Cuisine.kt` when adding a key.

## Tech stack

- Kotlin, Jetpack Compose, Material 3
- Navigation Compose for screen navigation
- Room for local persistence
- Kotlin Coroutines

## Project structure

```
app/src/main/kotlin/com/saatxi/eatapp/
├── data/
│   ├── local/          # Room entity, DAO, database, link validation
│   └── repository/     # Repository abstraction over the data source
├── navigation/         # NavHost and route definitions
└── ui/
    ├── list/           # Restaurant list screen + ViewModel
    ├── detail/         # Restaurant detail screen + ViewModel
    ├── edit/           # Add/edit restaurant form + ViewModel
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

The release buildType also sets `ndk { debugSymbolLevel = "FULL" }`, so
`bundleRelease` additionally writes
`app/build/outputs/native-debug-symbols/release/native-debug-symbols.zip`,
which AGP embeds directly into the `.aab` — Play Console extracts and uses it
automatically, no separate manual upload needed. The app has no C/C++ of its
own, but `androidx.graphics.shapes` and `androidx.datastore.preferences` each
bundle a prebuilt `.so`, and Play Console flags the bundle ("contains native
code but you haven't uploaded debug symbols") unless it's actually populated.
Same lifecycle as `mapping.txt`: gitignored, overwritten by the next build,
so archive it before then (`scripts/bundle.ps1` does this for you).

**This requires an installed NDK**, pinned as `ndkVersion` in
`app/build.gradle.kts` (currently `28.2.13676358`). Without it under
`<sdk>/ndk/<version>/`, AGP silently skips stripping those two libraries
("Unable to strip library ... due to missing strip tool") and
`native-debug-symbols.zip` ends up empty — the warning above is exactly what
that looks like from Play Console's side. Install it once via Android
Studio's SDK Manager (SDK Tools tab → NDK, side by side → check the pinned
version) or `sdkmanager --install "ndk;28.2.13676358"`, then rebuild and
re-upload; Gradle does not auto-download it for this step.

## Tests

```
./gradlew test
```

Unit tests live in `app/src/test/kotlin/`, mirroring the main package
structure. They run on the JVM with no emulator or device: the ones that need
an Android runtime — the Room DAO — use Robolectric, so a single command
covers everything.

What is covered:

- `SearchNormalizerTest` — the accent and case folding behind the search.
- `CuisineTest` — resolving `cuisineType` keys, including unknown ones.
- `LinkValidationTest` — the whitelist behind `website` and `instagram`,
  including every scheme the app refuses to open.
- `ColorSchemeContrastTest` — WCAG AA contrast for every on-colour of every
  palette, in both light and dark, plus all eight cuisine accents.
- `RestaurantDaoTest` — the filter query, both sort orders, and insert/update/
  delete, against an in-memory Room database.
- `RestaurantListViewModelTest` — how the filter and sort inputs combine into
  one query and one UI state.
- `RestaurantEditViewModelTest` — form validation (required name and cuisine,
  rejected website/Instagram values) and the insert-vs-update branch.
- `RestaurantDetailViewModelTest` — favourite toggling and deletion.
- `RestaurantUiModelTest` — the entity-to-UI-model mapping behind the price
  and address formatting, the link fields and the favourite flag.

## Baseline Profile

The `:baselineprofile` module (`com.android.test`, applying the
`androidx.baselineprofile` Gradle plugin) generates
`app/src/release/generated/baselineProfiles/baseline-prof.txt`: a list of
classes and methods ART should ahead-of-time compile at install time, rather
than waiting to JIT them from a cold start. Despite the `generated` in its
path, that file is a committed source-set output, not build output — the
project has no product flavors, so this is the plugin's real per-variant
destination for a plain `release` build type, not `app/src/main/`. (It sits
under `app/src/release/`, which `.gitignore`'s broad `**/release` rule would
otherwise swallow along with the real `app/release/` APK output dir; there's
an explicit `!app/src/release/` exception for that.) It's an instrumented test
module, not a unit test — it needs a connected device or emulator running
**API 28+** (a hard requirement of `BaselineProfileRule`, independent of the
app's own `minSdk` 26) and is never part of `./gradlew test`:

```
./gradlew :app:generateBaselineProfile
```

This runs `BaselineProfileGenerator` (cold start, a list scroll, opening a
restaurant's detail screen) against a non-minified release build of the app,
and writes/updates the profile above — commit that file once it changes.
`StartupBenchmark`, in the same module, measures cold startup time with and
without the profile applied
(`./gradlew :baselineprofile:connectedBenchmarkReleaseAndroidTest`), for a
before/after comparison.

The app depends on `androidx.profileinstaller` to install that profile at APK
install time; without it the file would sit unused until the OS's own
on-device profiling caught up after several real launches.

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
   [`scripts/bundle.ps1`](scripts/bundle.ps1) wraps the `bundleRelease`
   path above: it fails fast if signing isn't configured, warns if the
   working tree is dirty or HEAD isn't on a release tag, prints the
   resolved version, and archives `mapping.txt` and
   `native-debug-symbols.zip` next to the built `.aab` so a later build
   doesn't overwrite them before you've saved a copy.
   ```
   ./scripts/bundle.ps1
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
   filter, add/edit/delete a restaurant and open its detail screen — before
   handing it to anyone. Archive `app/build/outputs/mapping/release/mapping.txt` and
   `app/build/outputs/native-debug-symbols/release/native-debug-symbols.zip`
   alongside the artifact: without them, crash reports from that build are
   unreadable, and the next build overwrites both files (see **App
   optimization (R8)** and **Deobfuscating stack traces** above).
6. Distribute the APK/AAB (sideload, internal testing track, etc.) and
   confirm the version shown in the app's **About** dialog matches the tag.

If you need to publish a fix without bumping the version number, don't
retag an existing tag — always cut a new tag (e.g. `v1.1.1`) so
`versionCode` keeps increasing.
