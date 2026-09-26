# EatApp

A Flutter app (Android and iOS) to browse restaurants you've visited — name,
cuisine type, address (street, town, region and country), the visits you've
logged (each with its own date, rating, price band and note), an optional
photo, free-form tags and your own notes.

The app was rewritten from a native Android (Kotlin/Compose/Room) app. The
data model and the on-device database carry over, and an existing Android
install's data is imported automatically on first launch — see
[Migrating from the old Android app](#migrating-from-the-old-android-app).

## Features

- List restaurants, searchable across name, cuisine and every address field
  (accent- and case-insensitive), filterable by minimum rating, cuisine type,
  town/region/country, price range and visited/want-to-try, and sortable by
  name or rating.
- Add, edit and delete your own restaurants, including a photo, free-form
  tags, a note and optional website/Instagram links.
- Log visits, each with its own date, rating, price band and note.
- Favourites, plus a "what to eat" roulette that picks among your
  want-to-try restaurants.
- A statistics screen — totals, visited vs want-to-try, average rating,
  most-picked cuisines, price-tier spread and a monthly rating trend.
- A home-screen widget showing a random want-to-try restaurant, with a shuffle
  button and a tap that opens that restaurant.
- A tablet-width layout: a navigation rail, and the list beside the selected
  restaurant's detail instead of the detail replacing the list.
- Respects the system text size, and follows each platform's own gestures —
  pull-to-refresh, and the edge swipe-back on iOS.
- Share one restaurant, or your whole list, through the normal share sheet;
  opening a shared file shows a review screen before anything is saved.
- A single colour scheme, with a light/dark choice in Settings.
- English, Spanish and Catalan.
- No account, no server, no network calls.

## Managing your restaurants

The app installs with an empty list — there is no bundled or downloaded
dataset. Every restaurant is entered by hand, from the phone:

- Tap the **+** button on the list screen to add a restaurant: name, cuisine,
  street address, town, region and country (all optional), price range, an
  optional photo, free-form tags, a free-text note ("ask for the burrata",
  "go on a weekday"), and the two optional links below.
- The photo comes from the system photo picker. The app copies it into its
  own private storage and shows it on the list row, the roulette result and
  the detail screen; removing or replacing it deletes the old copy. Photos
  are deliberately not part of the share/import file (see below), so a
  restaurant you receive from someone else starts with no photo, the same as
  a brand-new one.
- Tap a restaurant's **Edit** action to change any of those fields, or
  **Delete** to remove it (with a confirmation prompt first).
- Log a **visit** from the detail screen. Each visit carries its own date,
  rating, price band and note, so the app can show a per-restaurant rating
  trend and the statistics screen can aggregate across all of them.
- `cuisineType` is chosen from a closed, **stable, language-independent**
  vocabulary — a key such as `fast_food`, never a display label such as
  `Fast food`. The app maps the key to both an icon and a translated label,
  which is what makes adding a second language a matter of adding an ARB
  file and nothing else.

### The optional links

Website and Instagram add a "Links" section to the restaurant detail screen.
Both are validated as you type, the same whitelist either way:

- **Website** must be a plain `http`/`https` web address. A bare host
  (`calferran.example`) is accepted and read as `https://`. Anything else
  (`javascript:`, `intent:`, `file:`, a custom scheme) is rejected with an
  inline error rather than saved — the app opens this value with the platform
  URL launcher, so this is what stops a link from choosing what the app
  launches.
- **Instagram** is the **handle**, not a URL: `cal_ferran` or `@cal_ferran`,
  up to 30 letters, digits, periods and underscores. The app builds
  `https://instagram.com/<handle>` itself, which is what makes the scheme
  impossible to influence from user input.

### Cuisine keys

The valid values for `cuisineType`. Each one has its own icon in the app, and
the list screen offers a filter chip for every key present in your data.

| Key | Shown as | | Key | Shown as |
| --- | --- | --- | --- | --- |
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
[`Cuisine`](lib/data/models/cuisine.dart) — in that case existing rows still
using the old key degrade gracefully to a generic icon and the raw string,
rather than crashing.

Keep this table in sync with `Cuisine` when adding a key.

## Sharing restaurants

Tap the share icon on the list screen to send your whole list, or on a
restaurant's detail screen to send just that one. Either opens the platform's
normal share sheet with a small JSON attachment (no account, no server). The
file carries the `eatapp.restaurants.v2` format tag, so a file that merely
happens to be JSON can't be mistaken for one of ours. Photos are deliberately
left out of it, on purpose: embedding one would blow well past the file's own
size cap for what's supposed to stay a small attachment, so a restaurant
received this way arrives with no photo and the receiving device's own owner
can add their own.

Receiving one works the same way in reverse: opening a restaurant file
someone sent you (from WhatsApp, Files, or wherever it landed) offers "Open
with EatApp", which shows a review screen before anything is saved. Each
restaurant in the file is shown individually, and:

- If it looks like something already in your list (same name and street
  address), it's flagged and defaults to **Skip**; you can still choose **Add
  anyway** or **Replace** the existing one.
- Otherwise it defaults to **Add**.
- Nothing is written to your list until you tap **Import** — closing the
  screen (or backing out) discards the whole review with no changes made.

The file is untrusted input: it's size-capped, parsed as JSON, gated on the
`format` tag, and every row is validated field-by-field (name/cuisine
present, rating 0-5, price range 0-6, the same website/Instagram whitelist as
the add/edit form) before it ever reaches the database — a row that fails is
dropped rather than failing the whole file. See
[`lib/data/share/`](lib/data/share) for the implementation.

## Backups and switching phones

Sharing (above) is the manual, explicit way to move data around, and
deliberately leaves photos out. Uninstalling the app, or moving to a new
phone, is different — and doesn't need the app to do anything, because it
goes through the platform's own backup (Android Auto Backup).

Because the Android app is written so the default full-data backup set
applies — the drift database, the `backup.json` snapshot the repository keeps
up to date after every write, the preference file, and restaurant photos,
since they live under the app's private files directory, not its cache — a
reinstall on the same phone, or setting up a new phone signed into the same
Google account, restores everything automatically. A direct phone-to-phone
transfer follows the same rules.

Auto Backup needs a Google account with device backup turned on (and Google
Play Services), and it runs roughly once a day while idle, charging and on
Wi-Fi — not immediately after every change, so a restaurant added seconds
before uninstalling might not have been backed up yet.

## The home-screen widget

Add the "Want to try" widget from your home screen's widget picker to keep a
random restaurant from your want-to-try list within reach. It shows the
restaurant's name and cuisine, offers a shuffle button that picks another one
without opening the app, and opens that restaurant's detail screen when the
card is tapped. When nothing is want-to-try it shows a prompt instead.

It is not a second copy of your data: the widget is redrawn from the same
on-device database the app uses, whenever a restaurant is added, edited or
deleted, and it follows the language you've chosen in Settings.

This is the one feature with native code on both platforms — an Android
`AppWidgetProvider` and an iOS WidgetKit extension, each a thin renderer
driven from Dart through the
[`home_widget`](https://pub.dev/packages/home_widget) plugin. The Android half
is committed under `android/` and builds with the app. The iOS half needs a
one-time Xcode step to create its widget extension target, which no tool
outside Xcode can do; see [docs/ios-widget.md](docs/ios-widget.md).

## Tech stack

- Flutter + Material 3 (Dart)
- [drift](https://drift.simonbinder.eu/) (SQLite) for local persistence
- `share_plus` and `receive_sharing_intent` for the share/import flows
- `url_launcher` for links and maps, `shared_preferences` for preferences
- `home_widget` for the home-screen widget's Android and iOS halves
- Localized with `flutter gen-l10n` (ARB files under `lib/core/l10n/`)

## Project structure

```text
lib/
├── main.dart          # opens the DB, runs the Room→drift import, runs the app
├── app/               # AppScope (the repositories, published to the tree)
├── core/
│   ├── l10n/          # ARB files + generated AppLocalizations
│   ├── theme/         # palette, tokens, ThemeData, gallery
│   ├── utils/         # pure helpers (link/tag validation, search, address)
│   └── widgets/       # shared presentational widgets
├── data/
│   ├── db/            # drift database, tables, DAOs
│   ├── migration/     # Room→drift importer
│   ├── models/        # Cuisine, sort, stats projections
│   ├── repositories/  # RestaurantRepository, UserPreferencesRepository
│   └── share/         # export/import models, JSON, file readers/writers
├── features/          # one folder per screen: state + controller + widgets
└── widget/            # the home-screen widget's Dart-side bridge
```

## Requirements

- Flutter (stable channel) with Dart `^3.13.4`
- Android: JDK 17 and the Android SDK (compile/target/min SDK come from the
  Flutter Gradle plugin, in `android/`)
- iOS: Xcode

## Building and running

```powershell
flutter pub get
flutter run                          # debug build on a connected device/emulator
flutter build apk --release          # release APK
flutter build appbundle --release    # release AAB (Play Store)
```

If you edit `lib/data/db/tables.dart` or a DAO, regenerate the drift code:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```powershell
flutter analyze
flutter test
```

Widget and unit tests live under `test/`, mirroring the `lib/` structure.
Database-backed tests run against an in-memory drift database
(`AppDatabase.memory()`), so the whole suite runs on the Dart VM with no
emulator or device.

## Versioning

The Android version is derived automatically from git in
`android/app/build.gradle.kts` — `pubspec.yaml`'s `version` is intentionally
ignored, so there is nothing to edit by hand:

- **`versionName`** comes from `git describe --tags`: `1.0.0` when `HEAD` is
  exactly on a `vX.Y.Z` tag, or `1.0.0-3-gabc1234` when 3 commits ahead of the
  last tag. If no tag exists yet it falls back to the short commit SHA.
- **`versionCode`** is the total number of commits on `HEAD`
  (`git rev-list --count HEAD`), which always increases and satisfies the
  Play Store's requirement that `versionCode` never decrease between
  releases.

## Migrating from the old Android app

The app was rewritten from a native Kotlin/Compose/Room app that shares this
app's `applicationId` and signing key, so upgrading in place is possible and
an existing install's data is preserved automatically:

- On first launch, `main()` runs the importer in
  [`lib/data/migration/room_to_drift_importer.dart`](lib/data/migration/room_to_drift_importer.dart)
  before the first frame. It locates the Room database file the old app left
  behind (in the private `databases/` directory), copies it to a `.bak` next
  to itself, and copies its rows into the drift database with
  `ATTACH DATABASE` + `INSERT ... SELECT` — entirely inside SQLite, matched by
  column name, so ids (and therefore favourites and stored photo paths)
  survive untouched.
- A preference flag keeps it from running twice; it is written only after a
  successful copy, so a failure part-way through simply retries on the next
  launch.
- The drift schema (`lib/data/db/app_database.dart`, `schemaVersion` 14) is
  Room's frozen baseline, which is what lets the import adopt the legacy file
  without a version bump.

A fresh install has no legacy file, so the importer is a quiet no-op there.

## The CSV helper

[`scripts/eatapp-csv-convert.ps1`](scripts/eatapp-csv-convert.ps1) converts
between an `.eatapp` share file and a CSV in either direction, so a batch of
restaurants can be entered or edited on a PC (e.g. in Excel) and imported
into the app in one go via "Open with EatApp", or exported from the app and
inspected as a spreadsheet:

```powershell
./scripts/eatapp-csv-convert.ps1 -Template              # write an example CSV
./scripts/eatapp-csv-convert.ps1 -InputPath restaurants.csv    # CSV -> .eatapp
./scripts/eatapp-csv-convert.ps1 -InputPath file.eatapp        # .eatapp -> CSV
```

## Signing releases

Release builds are signed with your own keystore. Neither the keystore nor its
passwords are ever committed — the build reads them from `local.properties`
(which is gitignored) or, for CI, from environment variables. `*.jks` and
`*.keystore` are gitignored too, so a keystore left in the project directory
cannot be committed by accident.

**Create a keystore once** (keep it somewhere safe and backed up — losing it
means you can never update the app on the Play Store again):

```powershell
keytool -genkeypair -v -keystore eatapp-release.jks -alias eatapp `
  -keyalg RSA -keysize 2048 -validity 10000
```

**Point the build at it** by adding these to `local.properties`. A relative
path resolves against the repository root; an absolute path is used as is:

```ini
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

If none of this is configured, a release build still succeeds but produces an
**unsigned** artifact that cannot be uploaded; the build prints a warning
saying so.

## Releasing a new version

1. Make sure all changes for the release are committed (an uncommitted
   working tree produces a `-dirty` suffix in `versionName`).
2. Tag the release commit with an **annotated** tag following
   `vMAJOR.MINOR.PATCH`. [`scripts/release.ps1`](scripts/release.ps1) does
   exactly that, with a few guard rails: it asks for the version as `X.Y.Z`,
   refuses a tag that already exists locally or on the remote, warns about an
   uncommitted working tree, opens your editor for the tag message and then
   pushes the tag.

   ```powershell
   ./scripts/release.ps1                  # asks for the version
   ./scripts/release.ps1 -Version 1.1.0   # or pass it directly
   ```

   Add `-NoPush` to create the tag without pushing it.
3. Make sure signing is configured (see **Signing releases** above), then
   build the release bundle with
   [`scripts/bundle.ps1`](scripts/bundle.ps1). It fails fast if signing isn't
   configured, warns if the working tree is dirty or `HEAD` isn't on a release
   tag, prints the resolved version, runs
   `flutter build appbundle --release`, and archives `mapping.txt` and
   `native-debug-symbols.zip` next to the built `.aab` so a later build
   doesn't overwrite them before you've saved a copy:

   ```powershell
   ./scripts/bundle.ps1
   ```

   Pass `-AllowUnsigned` to build anyway for a local inspection, or
   `-SkipCleanCheck` to bypass the clean-tree/tag prompts.
4. Because release builds are minified and shrunk while debug builds are not,
   install the release artifact on a device and smoke-test it — open the
   list, search, filter, add/edit/delete a restaurant, open its detail screen,
   log a visit, and share a restaurant to another app and reopen the resulting
   file with "Open with EatApp" — before handing it to anyone.
5. Distribute the APK/AAB (sideload, internal testing track, etc.).

If you need to publish a fix without bumping the version number, don't retag
an existing tag — always cut a new tag (e.g. `v1.1.1`) so `versionCode` keeps
increasing.
