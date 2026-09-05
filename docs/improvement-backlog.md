# EatApp improvement backlog

A single place to look up everything worth improving in this app, so ideas
don't get lost between sessions. It's a menu, not a plan — nothing here is
committed to, and items can be picked off in any order.

Every entry has a stable ID (`F-01`…`F-69`). Use those in commit messages and
when asking for something to be worked on; they never get renumbered, and
items that get done stay in the list marked **Done** rather than being
deleted, so the file keeps a record of what changed and why.

- **Impact** — High: a crash, data loss, or something visibly broken /
  Medium: a real annoyance / Low: polish.
- **Effort** — XS: minutes · S: under an hour · M: an afternoon · L: bigger.

Large-screen and tablet support is deliberately not covered here; see
[tablet-adaptive-layout-idea.md](tablet-adaptive-layout-idea.md).

## Where to start

The **Open** section below (F-56 onward) is the backlog side of a second
redesign pass, started 2026-09-04 with a UI/UX audit —
[visual-redesign-proposal.html](visual-redesign-proposal.html) — that found
the app's theming/navigation foundations solid (see
[visual-modernization-plan.md](visual-modernization-plan.md)) but its data
model and a few screens thin: no photos anywhere (F-63, now done), no notes
(F-56, now done) or tags, no visited/want-to-try status (F-55, now done), a
flat Settings screen and an ungrouped edit form (F-62, now done), and no
statistics screen (F-64, now done). F-59 (tags) is the largest item still
open in this pass; everything else left is Medium impact or smaller.

Active work on the *first* pass still lives in
[visual-modernization-plan.md](visual-modernization-plan.md): the redesign
pass started 2026-08-28 (three selectable colour schemes, bottom navigation,
favourites, a "what to eat" picker, optional link columns, and a performance
pass). Phases 1 and 4 are done; that file tracks the rest.

For what's deliberately out of scope in both, see
[tablet-adaptive-layout-idea.md](tablet-adaptive-layout-idea.md).

---

## Open

### F-59 · No free-form tags — Medium / M

"Terraza", "para grupos", "llevar niños" — recurring, user-invented labels
that don't fit the closed cuisine vocabulary and shouldn't. **Fix:** a `Tag`
entity plus a `RestaurantTag` join table, a chip-entry field in the edit form
(suggesting existing tags), and small pill badges under the cuisine label in
list/detail rows, reusing the `FilterChip` pattern already built for cuisine
filtering.

### F-58 · Rating-and-price markup is copy-pasted three times — Medium / S

The stars-plus-"N/5"-plus-price-pill block is hand-duplicated across
`RestaurantListScreen.RestaurantRow`, `RestaurantDetailScreen` and
`RouletteScreen.RouletteResultCard`, with the risk that a future tweak to one
copy silently drifts from the other two. **Fix:** extract one shared
`RatingAndPriceRow` composable and have all three call it.

### F-60 · Favorites has no search or filters — Medium / S

Favorites reuses `RestaurantRow` and `EmptyState` from the list screen but
has none of its search bar, sort control or filter chips, even though it
shows the same kind of list — an inconsistency between two screens with
near-identical content. **Fix:** lift the list screen's search/sort/filter
UI (and the matching `RestaurantListViewModel` filtering logic) into
`FavoritesViewModel`/`FavoritesScreen`, or extract a shared composable both
screens call.

### F-65 · No swipe actions on list rows — Medium / M

Every mutation (favorite, delete) requires either the row's heart icon or a
trip into the detail screen. **Fix:** wrap `RestaurantRow` in a
`SwipeToDismissBox` for a quick favorite-toggle or delete gesture — needs
care around the existing `clearAndSetSemantics` collapse and the heart
`IconToggleButton` overlaid outside the card (see F-44's accessibility
notes).

### F-66 · Empty search shows a blank box — Medium / S

There's no guidance before the user types anything. **Fix:** when the search
query is empty, show a short list of suggestions (e.g. top-rated, or a
frequently-filtered cuisine) instead of nothing.

---

## Done

Recorded here rather than deleted, so the numbering stays stable.

### F-69 · Segmented button text clips against the default checkmark — Done.

Found on a real device, not in the redesign audit: in a non-English locale
(reported in Catalan — "Per provar" — but the same risk exists everywhere a
`SegmentedButton` splits its row two or three ways), the label text got
clipped inside the selected segment. `SegmentedButton`'s own default `icon`
parameter draws a checkmark whenever `selected` is true, and that icon eats
into a segment's width — already tight, since `SingleChoiceSegmentedButtonRow`
divides the row evenly — on top of whatever text has to fit next to it.
Shorter English strings mostly got away with it; a longer translation didn't.

**Fix:** `icon = {}` on every `SegmentedButton` call in the app, all four of
them — the visit-status toggle
([RestaurantEditScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/edit/RestaurantEditScreen.kt)),
the list screen's sort control
([RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt)),
Settings' theme-mode picker
([SettingsScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/settings/SettingsScreen.kt)),
and the import screen's skip/add/replace row
([RestaurantImportScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/importing/RestaurantImportScreen.kt))
— rather than patching only the one the screenshot showed. The fill colour
difference between selected/unselected segments is already the primary
signal; losing the checkmark doesn't cost any clarity, and every one of
these rows already had at least one string long enough in Spanish or
Catalan to be at real risk of the same clipping.
- Verified with `./gradlew test assembleDebug lint` — 187 tests passing
  (unchanged; purely a UI change with no ViewModel logic), no new lint
  findings. Not verified: the actual fix on a real device in Catalan, only
  that it compiles and the previous, broken layout is gone from the code.

### F-68 · No home-screen widget — Done.

The entry itself said this needed "its own investigation" and offered two
contradictory contents (the latest roulette pick, or the next want-to-try
restaurant) — genuinely different implementations, not a detail to guess at.
Resolved with the user before writing any code:

- **Content: a random want-to-try restaurant**, re-picked each time the
  widget refreshes — not the actual last Roulette result, which only ever
  lives in `RouletteViewModel`'s in-memory state; persisting it just so a
  separate widget process could read it would mean a second source of
  truth for what both screens agree is disposable UI state. A new one-shot
  `RestaurantDao.getRandomWantToTry()` (`SELECT ... WHERE visited = 0 ORDER
  BY RANDOM() LIMIT 1`) backs it, exposed through `RestaurantRepository`.
- **Tap target: opens that restaurant's detail screen directly**, via an
  explicit intent naming `MainActivity` with a `EXTRA_RESTAURANT_ID` extra —
  `EatAppNavHost` gained a `startRestaurantId` parameter and a
  `LaunchedEffect` that navigates to it on cold start, mirroring the
  existing `startImportUri` mechanism exactly.
- New `androidx.glance:glance-appwidget:1.2.0` dependency (latest stable
  confirmed against maven-metadata.xml first) —
  [`WantToTryWidget.kt`](../app/src/main/kotlin/com/saatxi/eatapp/widget/WantToTryWidget.kt)
  (the `GlanceAppWidget` + its composable content + a `ShuffleAction` that
  re-picks and re-renders in place, without leaving the widget) and
  [`WantToTryWidgetReceiver.kt`](../app/src/main/kotlin/com/saatxi/eatapp/widget/WantToTryWidgetReceiver.kt).
  Refreshes every 4 hours on its own
  ([`want_to_try_widget_info.xml`](../app/src/main/res/xml/want_to_try_widget_info.xml))
  or on demand via its own shuffle button; an empty state covers having
  nothing marked want-to-try.
- **The one unavoidable XML layout** in an otherwise all-Compose app: the
  AppWidget framework requires `initialLayout` to name a real RemoteViews
  layout ([`widget_loading.xml`](../app/src/main/res/layout/widget_loading.xml)),
  shown for a frame before Glance's own content replaces it. `CLAUDE.md`'s
  "no XML layouts" rule now says so explicitly, as a narrow, framework-forced
  exception rather than a quiet regression.
- **Colours can't follow the in-app palette choice**: Glance's content
  colours don't have access to the app's Compose theme (`AppPalette`,
  dynamic light/dark), so the widget uses a fixed light/dark pair lifted
  from the default Saffron palette's tones
  ([`colors.xml`](../app/src/main/res/values/colors.xml) +
  `values-night/colors.xml`) rather than the user's actual selected palette
  — a deliberate, documented simplification, not an oversight.
- **A real, undocumented API gap hit along the way**: Glance 1.2.0's
  `ColorProvider(@ColorRes Int)` — the whole point of which is resolving a
  colour resource's own day/night qualifiers, exactly what's needed here —
  is flagged by lint as `RestrictedApi` (library-internal), and no public
  day/night-pair constructor exists in this version to use instead.
  Suppressed with `@Suppress("RestrictedApi")` and a comment explaining why,
  rather than worked around with fixed non-adaptive colours, which would
  have been a real dark-mode regression to dodge a lint false alarm.
- **The receiver is `android:exported="false"`**: `APPWIDGET_UPDATE` is a
  protected, system-only broadcast the OS delivers directly, so the
  launcher never calls this component itself. No new permission needed.
- **Known, accepted limitation**: tapping the widget while the app is
  already open pushes a second `MainActivity` instance on top (no
  `onNewIntent`/`singleTop` handling) — the same characteristic the
  existing "Open with EatApp" import flow already has and was never flagged
  as a bug, so this isn't a new regression, just the same shape of rough
  edge in a second place.
- Verified with `./gradlew test assembleDebug assembleRelease lint` — 187
  tests passing (2 new DAO cases for `getRandomWantToTry`), R8 still
  minifies cleanly with Glance added (`app-release.apk` ~3.3 MB, up from
  ~2.6 MB), lint clean after fixing a real (if trivial) `Overdraw` finding
  on the loading layout's redundant background and confirming the two new
  `UnusedAttribute` warnings (`targetCellWidth`/`targetCellHeight`, API 31+
  on a 26 min) are the same benign below-minSdk pattern already accepted
  for `enableOnBackInvokedCallback`/`localeConfig`. Not verified: actually
  placing the widget on a home screen, the shuffle action, or the detail
  deep-link — none of which run outside a real device or emulator.

### F-67 · Loading states are a single generic spinner — Done.

List and detail both showed one centred `CircularProgressIndicator` while
loading — exactly the scope the entry's `Fix` named (edit's own loading
spinner, mentioned only in the entry's problem statement and not its fix,
was left alone).

- New [`Shimmer.kt`](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/Shimmer.kt):
  `Modifier.shimmerPlaceholder()`/`.shimmerCircle()`, a plain
  `rememberInfiniteTransition` fading a tinted `onSurface`-alpha box in and
  out — no animation/shimmer library needed for something this simple.
- **List**: a new `RestaurantRowSkeleton`
  ([RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt))
  mirrors `RestaurantRow`'s exact shape — circular badge, two text lines,
  trailing rating/price column — six of them fill the initial-load state
  instead of a spinner.
- **Detail**: a new `RestaurantDetailSkeleton`
  ([RestaurantDetailScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/detail/RestaurantDetailScreen.kt))
  mirrors the Overview and Rating-and-price cards the loaded screen always
  shows; the optional photo/notes/links cards aren't guessed at, since
  whether they'll exist isn't known until the row actually loads.
- Favorites' own initial-load state (currently blank, not even a spinner)
  and Roulette/Settings weren't touched — outside the entry's stated scope,
  left for a follow-up if wanted.
- Verified with `./gradlew test assembleDebug assembleRelease lint` — 185
  tests passing (unchanged; this is a UI-only change with no ViewModel
  logic), lint report unchanged (`UnusedResources` still the same
  pre-existing 3). Each skeleton got its own light/dark `@Preview` pair.
  Not verified: how the pulse actually looks/feels on a real device.

### F-56 · No free-text notes per restaurant — Done.

Restaurants had nowhere to record "ask for the burrata" or "go on a
weekday" — exactly the kind of detail more useful than most of what was
already stored. Built as the entry's own `Fix` described, field for field:

- `Restaurant.notes: String?` (nullable, no default — a real
  `MIGRATION_7_8` adds the column, `EatAppDatabase` → version 8), with a
  KDoc note that it's deliberately **not** folded into `searchText`: the
  entry asked for a field to show back on the detail screen, not another
  thing to search by, and touching `buildSearchText`/the DAO's search query
  is a separate decision this entry didn't raise.
- **Edit form**: a multiline `OutlinedTextField` (`minLines = 3`) right
  after Address in the "Basics" card
  ([RestaurantEditScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/edit/RestaurantEditScreen.kt),
  the card F-62 built) — exactly the placement the entry asked for. No
  validation: an empty note is just no note, the same as a blank address.
- **Detail screen**: a new `NotesCard`, the same title-then-content `Card`
  shape every other section on that screen uses, body text rendered
  italic; omitted entirely when there's no note, the same
  omit-rather-than-empty treatment the Links card already gets.
- **`RestaurantExport`** gained `notes: String? = null` — defaults null so
  a share file written before this field existed still imports fine, just
  without a note, the exact backward-compatibility treatment F-55 used for
  `visited`. Both `toExport()` (two call sites: the repository's own and
  `RestaurantDetailScreen`'s single-restaurant share) and
  `toRestaurantOrNull()` (trims and treats a blank note as none, same as
  address) carry it through.
- `RestaurantUiModel` gained `notes`, blank-to-null in the mapper, the same
  treatment `address` gets.
- Verified with `./gradlew test assembleDebug assembleRelease lint` — 185
  unit tests passing (9 new: mapper carry-through, edit-form
  change/trim/default-empty cases, export/import backward-compatibility
  and trim/blank cases mirroring F-55's own `visited` tests, and a DAO
  round-trip), release build unaffected, lint report unchanged
  (`UnusedResources` still the same pre-existing 3).

### F-64 · No statistics screen — Done.

A new screen, reachable from Settings' Data section
(`settings_action_view_statistics`, a new `Routes.STATS` full-screen route in
[EatAppNavHost.kt](../app/src/main/kotlin/com/saatxi/eatapp/navigation/EatAppNavHost.kt)
— hides the bottom bar the same way detail/add/edit/import already do),
surfacing exactly the aggregate picture the entry asked for: total
restaurants, visited vs. want-to-try, average rating, most-picked cuisines,
price-tier spread. Everything is computed locally by Room; no network call,
no charting library.

- **Five small DAO queries** rather than one hand-assembled aggregate
  ([RestaurantDao.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/local/RestaurantDao.kt)):
  `observeTotalCount`, `observeVisitedCount`, `observeAverageRating`
  (`AVG(rating) WHERE rating > 0` — a want-to-try row's `rating = 0` doesn't
  count as a real rating, so it can't drag the average down), and two
  `GROUP BY` queries, `observeCuisineCounts`/`observePriceRangeCounts`,
  returning new small data classes `CuisineCount`/`PriceRangeCount`
  ([RestaurantStats.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/local/RestaurantStats.kt)).
  Exposed through `RestaurantRepository` as plain delegating methods.
- **`StatisticsViewModel`** combines all five with `combine()` — the typed
  5-flow overload, not the untyped vararg one (the same overload boundary
  F-3's history already ran into) — into one `StatisticsUiState`, with the
  same `isInitialLoad` flag the list/favorites screens use so the empty
  state can't flash before the real counts arrive. `wantToTryCount` is
  derived (`totalCount - visitedCount`), not a sixth query.
- **`StatisticsScreen`**: two rows of stat tiles (restaurants, visited,
  want-to-try, average rating), then a cuisines card and a price-range card,
  each row a small hand-drawn horizontal bar (`StatBar`, two nested `Box`es)
  sized by its share of the largest count in that group — no charting
  library, per the entry. Cuisine rows reuse the same tinted-circle badge
  (`cuisineTint`/`cuisineIcon`) as every other cuisine-aware row in the app.
  An empty state covers the "no restaurants yet" case.
- **Every `RestaurantRepository` fake in the test suite** (six of them,
  across the edit/list/detail/favorites/roulette/settings ViewModel tests)
  gained the five new methods as `NotImplementedError` stubs, since the
  interface itself grew — none of those ViewModels use the new methods, so
  nothing about their existing tests changed otherwise.
- Verified with `./gradlew test assembleDebug assembleRelease lint` — 176
  unit tests passing (9 new: DAO-level cases for the count/average/group-by
  queries including the unrated-row exclusion, and `StatisticsViewModelTest`
  covering the combine/derivation logic), release build with R8 still
  succeeds, lint report unchanged (`UnusedResources` still the same
  pre-existing 3). Not verified: what the tiles/bars actually look like on
  a real device or emulator, only that the screen compiles, its two
  `@Preview`s (populated and empty) are well-formed, and its logic is
  covered by the ViewModel/DAO tests above.

### F-61 · Import candidate rows have no cuisine badge — Done.

`ImportCandidateRow`
([RestaurantImportScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/importing/RestaurantImportScreen.kt))
was plain text — name, cuisine label, address — the one list-shaped screen
without the circular cuisine-icon badge every other one (list, favorites,
roulette) leads with. The row's name/cuisine/address block now sits in a
`Row` next to the same 48dp tinted-circle badge (`cuisineTint` +
`cuisineIcon`, sized and coloured exactly like `RestaurantRow`'s), with the
duplicate label and the skip/add/replace segmented row unchanged below it.
- Verified with `./gradlew test assembleDebug lint` — all green, no new
  lint findings.

### F-57 · The cuisine dropdown in the edit form has no icons — Done.

The list screen's cuisine filter chips each already showed the cuisine's
icon (`cuisineIcon(key)`); `CuisineDropdown`'s `DropdownMenuItem`s
([RestaurantEditScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/edit/RestaurantEditScreen.kt))
now do too — a `leadingIcon` calling the exact same `cuisineIcon` lookup,
one line per entry across the 24-key vocabulary. The closed field itself
(the `OutlinedTextField` showing the current selection) was left as
text-only, matching the narrow scope the entry actually asked for.
- Verified with `./gradlew test assembleDebug lint` — all green, no new
  lint findings.

### F-63 · No restaurant photos — Done.

The single biggest gap the visual redesign audit found — every restaurant
was a cuisine icon in a coloured circle everywhere it appeared. Built
mostly as the entry's own `Fix` described, with two deliberate deviations
(storage location, and where the detail screen's photo sits) explained below.

- **Picking**: the add/edit form gained a photo box at the top
  ([RestaurantEditScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/edit/RestaurantEditScreen.kt)'s
  new `PhotoPicker`), backed by `ActivityResultContracts.PickVisualMedia()` —
  the system Photo Picker, no storage permission needed on API 26+ through
  its own backport. Tapping it (with or without an existing photo) reopens
  the picker; a photo already showing gets a small remove button overlaid.
- **Storage, deliberately not "cache" as the entry said**: a picked photo is
  decoded, downsampled to a 1600px longest side, oriented upright from its
  EXIF tag (`androidx.exifinterface`, since `BitmapFactory` ignores
  orientation), re-encoded as an 85%-quality JPEG and written under this
  app's `filesDir/photos/`, never `cacheDir` — new
  [RestaurantPhotoStorage.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/photo/RestaurantPhotoStorage.kt).
  `cacheDir` is what the OS clears under storage pressure and what
  `res/xml/backup_rules.xml`'s default full-backup set does *not* cover
  ([BackupWriter.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/share/BackupWriter.kt)
  already draws exactly this distinction for `backup.json`); a restaurant's
  own photo is exactly the kind of durable user data that distinction says
  belongs in `filesDir`, which Auto Backup already covers for free. The copy
  is made lazily, only when the form is actually saved
  (`RestaurantEditViewModel.onSave`) rather than the moment it's picked, so
  backing out of an add/edit screen after picking a photo never leaves an
  orphaned file with nothing referencing it.
- **`RestaurantPhotoStorage` is an interface** (`AndroidRestaurantPhotoStorage`
  the real implementation), purely so `RestaurantEditViewModel` — which now
  takes it as a constructor parameter alongside the repository — stays unit
  testable against a fake instead of needing a real `ContentResolver`, the
  same reasoning the old `DatabaseSyncManager` interface existed for (see
  F-08). `RestaurantEditViewModelTest`'s existing fakes cover everything that
  doesn't need a real `Uri`; a new `RestaurantEditViewModelPhotoTest` (
  `@RunWith(RobolectricTestRunner::class)`) covers the three cases that do —
  `android.net.Uri` isn't usable from a plain JVM test (every method throws),
  the same reason `RestaurantDaoTest` already reaches for Robolectric.
- **A failed copy falls back to whatever photo was already there** rather
  than losing it — an unreadable or corrupt pick shouldn't cost the user
  their existing photo, the same graceful-degradation instinct the app
  already applies to a bad link column or an unrecognised cuisine key.
- **Cleanup**: `RoomRestaurantRepository.update`/`delete` now look up the
  row's previous `photoPath` (`RestaurantDao.getPhotoPath`, new) before
  writing, and delete the old file once it's no longer referenced;
  `deleteAll` wipes the whole `photos/` directory at once rather than
  looking up each row. Covered by four new `RestaurantDaoTest` cases against
  real files under Robolectric's `filesDir`.
- **Display**: `RestaurantUiModel` gained `photoPath`, carried through
  unchanged by the mapper. Shown via `coil3.compose.AsyncImage` (a new
  dependency, `io.coil-kt.coil3:coil-compose` — its own network-fetching
  support lives in a separate `coil-network-*` artifact that was *not*
  added, so it has no networking capability at all, consistent with this
  app making no network calls) in place of the cuisine icon in the list
  row's badge and the roulette result card's circle, and as a full-width
  cover image above the Overview card on the detail screen.
- **Detail screen deviation from the entry's wording**: the entry asked for
  the photo "behind the `LargeTopAppBar`". That bar's collapse behaviour and
  the list→detail shared-element transition it carries
  (`cuisineBadgeTransition`, see F-38) were both built and tuned carefully;
  layering an image behind a bar whose height animates every frame during
  scroll risked breaking either one in a way that could only really be
  caught on a real device, which wasn't available to verify against. Used a
  plain cover-image card above the existing Overview card instead — same
  visual payoff (the photo is the first thing seen), none of that risk. The
  app bar itself, its cuisine-tint colouring, and the shared transition are
  completely unchanged.
- **Export/import**: exactly what the entry suggested — photos are not part
  of `RestaurantExport`/`RestaurantShareFile` at all, so a shared or
  imported restaurant simply starts with no photo (`Restaurant.photoPath`
  already defaults to null). README's "Sharing restaurants" section now
  says so explicitly, along with the new photo capability in "Features" and
  "Managing your restaurants".
- New dependencies, both local-only (see above for Coil):
  `io.coil-kt.coil3:coil-compose:3.6.2` and
  `androidx.exifinterface:exifinterface:1.4.2`, both stable releases
  confirmed against their maven-metadata.xml before adding.
- `EatAppDatabase` went to version 7 with a real `MIGRATION_6_7` (adds the
  nullable `photoPath` column) — not a destructive fallback, matching the
  precedent F-55's `MIGRATION_5_6` set now that restaurants are user data
  the app is the source of truth for.
- Verified with `./gradlew test assembleDebug assembleRelease lint` — 167
  unit tests passing, R8 still minifies the release build cleanly with the
  two new dependencies (`app-release.apk` ~2.6 MB, up from ~1.46 MB — Coil
  and ExifInterface are the entire difference), lint report unchanged
  (`UnusedResources` still the same pre-existing 3). Not verified: the
  Photo Picker itself, the decoded photo's actual on-screen appearance, and
  the detail screen's cover image alongside the collapsing app bar, none of
  which run outside a real device or emulator.

### F-62 · Edit/add form is one long ungrouped column — Done.

[RestaurantEditScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/edit/RestaurantEditScreen.kt)'s
eight fields were one flat `Column` with no sectioning, unlike the detail
screen's card-grouped layout right next to it in the navigation graph. Split
into the three cards the entry named, each built from a new private
`EditSectionCard(title, content)` helper — a `Card` with a `titleMedium`
heading followed by its fields, `verticalArrangement = Arrangement.spacedBy(16.dp)`
inside — which is the same title-then-content shape
`RestaurantDetailScreen`'s Overview / Rating and price / Links cards already
use, so the form now reads as the same kind of document as the screen that
shows it back:

- **Basics** — name, cuisine dropdown, address.
- **Status and rating** — the visited/want-to-try segmented row, the star
  rating picker, the price-range picker. Unchanged from the detail screen's
  own grouping is that this pairs status with rating/price rather than with
  Basics, matching the entry's own split rather than the detail screen's
  (which folds visited status into Overview instead) — the two screens don't
  need to group identically, just to both read as sectioned.
- **Links** — website, Instagram handle.

No field's own behaviour, validation or error text changed — this was purely
`RestaurantEditContent`'s layout. Three new strings
(`edit_section_basics`/`_status_rating`/`_links`) added to `values/`,
`values-es/` and `values-ca/`, alongside the other `edit_*` strings.
- Verified with `./gradlew test assembleDebug lint` — all green, no new lint
  findings (`UnusedResources` still at 3, the same pre-existing set
  `action_ok`/`detail_link_website`/`detail_link_instagram` the F-51 entry
  already named — the three new section-title strings are consumed
  immediately by the cards that use them).

### F-55 · No visited / want-to-try status — Done.

First entry closed out of the second redesign pass (see "Where to start"
above and [visual-redesign-proposal.html](visual-redesign-proposal.html)).
Every restaurant used to be stored as if it had already been eaten at; there
was no way to note down a place worth trying without pretending a visit
already happened.

- `Restaurant` gained a `visited: Boolean` column (default `true`, so a
  hand-built entity keeps today's implicit behaviour). A real
  `MIGRATION_5_6` in
  [EatAppDatabase.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/local/EatAppDatabase.kt)
  adds the column and backfills it — `UPDATE restaurants SET visited = 0
  WHERE rating = 0` — treating an unrated row as more likely a wishlist entry
  than a forgotten review, rather than falling back to the destructive
  migration the file's own comment warns against.
- `RestaurantDao.observeFiltered` gained a fifth, nullable `visited`
  parameter, following the same `:param IS NULL OR column = :param` pattern
  already used for `minRating`/`cuisineType`, threaded through
  `RestaurantRepository`/`RoomRestaurantRepository` and into
  `RestaurantListViewModel`'s `Filters`.
- The edit form gained a two-way `SingleChoiceSegmentedButtonRow` ("Quiero
  ir" / "Ya he ido"), the list screen a matching filter-chip pair plus a
  small "Por probar" pill on unvisited rows (reusing the price-pill's
  `Surface`/`RoundedCornerShape(percent = 50)` styling), and the detail
  screen an extra `InfoRow` in the Overview card when the restaurant hasn't
  been visited yet. Favorites inherits the badge for free through the shared
  `RestaurantRow`.
- `RestaurantExport`/`RestaurantShareFile` gained a `visited` field
  defaulting to `true`, so a share file written before this change still
  imports as "visited" rather than silently becoming a wishlist entry no one
  asked for.
- English, Spanish and Catalan strings added (`visit_status_visited`,
  `visit_status_want_to_try`, `list_filter_visit_status`,
  `edit_field_visit_status`).
- Verified with `./gradlew test assembleDebug` — new DAO cases for the
  `visited` filter (no filter / true / false), export/import round-trip and
  backward-compatibility cases, a UI-model carry-through case, and edit/list
  ViewModel cases for the new toggle and filter; every other ViewModel's fake
  repository updated to the new `observeFiltered` signature to keep
  compiling. Not covered: a dedicated `MigrationTestHelper` test for
  `MIGRATION_5_6` itself, since that needs a new `androidx.room:room-testing`
  test dependency not yet in
  [libs.versions.toml](../gradle/libs.versions.toml) — worth adding next time
  a migration test is needed, rather than for this one change alone.

### F-51 · No `@Preview` composables — Done.

Section H in full, which retires the section: F-51 was its last item.

Four preview subjects, each in light and dark via two stacked `@Preview`
annotations (one plain, one with `uiMode = Configuration.UI_MODE_NIGHT_YES`) —
`isSystemInDarkTheme()` inside `EatAppTheme` reads the preview's configuration
the same way it would a real device, so no separate dark/light branching was
needed beyond that.
- **The restaurant row and both empty states**
  ([RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt)):
  `RestaurantRowPreview` against a hand-built `RestaurantUiModel`, and
  `EmptyStateFirstSyncPreview` / `EmptyStateNoResultsPreview` against the same
  private `EmptyState` composable the screen itself uses for its two empty
  states — a Kotlin file-private function is visible to a `@Preview` in the
  same file, so no visibility had to widen for this.
- **The detail screen**
  ([RestaurantDetailScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/detail/RestaurantDetailScreen.kt))
  couldn't be previewed as directly: its entry point takes a
  `RestaurantDetailViewModel` from `viewModel(factory = AppViewModelProvider.Factory)`,
  which needs a real Android runtime to construct. The fix was to split it in
  two — `RestaurantDetailScreen` now just collects `uiState` and hands it to a
  new private `RestaurantDetailContent(uiState, onBack)`, which carries
  everything the old function's body did. `RestaurantDetailScreenPreview`
  calls `RestaurantDetailContent` directly with a hand-built
  `DetailUiState.Loaded`, sidestepping the ViewModel entirely. `Loading` and
  `NotFound` were left unpreviewed — the entry asked for "the detail screen",
  and the loaded state is what that screen actually looks like; both other
  states are a single centred icon-and-text block shared with the list's
  empty states, already covered there.
- Verified with `./gradlew test assembleDebug lint` — 101 tests green, lint
  report unchanged from before this pass. No Android Studio instance was
  available to actually render the previews, only to confirm the file
  compiles and the preview functions are well-formed; rendering them is
  worth a manual check next time the project is open in the IDE.

### F-50 · No CI — Done.

A new [ci.yml](../.github/workflows/ci.yml) workflow runs on every push and
pull request: checkout, JDK 17, then `./gradlew test assembleDebug lint` in
one invocation. `test` was added alongside the two the entry's `Fix` line
named, since the "Where to start" note framing this entry was explicit that
CI matters "now that there is a test suite worth running on every push" —
leaving it out would have missed the actual point.
- The checkout step sets `fetch-depth: 0` and `fetch-tags: true`, exactly the
  warning already sitting in
  [build.gradle.kts](../app/build.gradle.kts) about the git-derived
  `versionCode`/`versionName` collapsing to `1` / a bare SHA otherwise.
- One real obstacle surfaced testing this: the committed
  [gradle.properties](../gradle.properties) pins
  `org.gradle.java.home=C:\Program Files\Android\Android Studio\jbr` for
  local Windows development, which doesn't exist on a CI runner and would
  fail every build. Rather than touch that (it's a legitimate local dev
  setting, not something to rip out for CI's sake), the workflow writes its
  own `GRADLE_USER_HOME/gradle.properties` pointing `org.gradle.java.home` at
  the JDK `setup-java` just installed — Gradle resolves a user-level
  `gradle.properties` ahead of the project's, so this overrides the pinned
  path for CI without changing anything a local build sees.
- Runs on `ubuntu-latest`: nothing in the test suite needs an emulator or
  Windows (CLAUDE.md already says as much — Robolectric covers the two cases
  that need an Android runtime, entirely on the JVM), so there's no reason to
  pay for a Windows or macOS runner.
- Test and lint HTML reports upload as a build artifact on every run
  (`if: always()`), so a CI failure is diagnosable from the Actions tab
  without reproducing it locally.
- Debug builds need no secrets: `DATABASE_URL` falls back to the same public
  hardcoded URL release uses when `EATAPP_DATABASE_URL` isn't set, and
  `assembleDebug` needs no signing config.
- Verified locally rather than by watching an actual Actions run: confirmed
  `git ls-files` shows `gradle.properties` is committed (so the JDK-path
  problem is real and not local-machine noise), and that
  `./gradlew test assembleDebug lint` — the same command the workflow
  runs — passes on this machine. The workflow YAML itself is unverified
  against a live GitHub Actions run.

### F-49 · Minification was off, so the whole icon set shipped — Done.

Already fixed by an earlier commit (`b178fd6`, "Enable R8 app optimization
for release builds") that this backlog entry was never updated to reflect —
a bookkeeping gap, not new work. `isMinifyEnabled = false` /
`proguard-rules.pro` became the AGP 9.3+ `optimization { enable = true }` DSL
in [build.gradle.kts](../app/build.gradle.kts), which turns on code
shrinking/obfuscation and resource shrinking together and pulls in the
platform's keep rules automatically; project-specific rules live in
[eat-app.keep](../app/src/main/keepRules/eat-app.keep), which stays empty of
custom rules since the app has no reflection of its own and Room ships its
own consumer keep rules for its generated `*_Impl` classes. This took the
first of the two fixes the entry offered (enable R8) rather than dropping
`material-icons-extended` for `material-icons-core`, so all ~25 icons the app
actually draws stay available without checking each one exists in the
smaller artifact. `CLAUDE.md`'s security guidelines section already
documents this as the current, permanent state ("Don't turn it off, and
don't reintroduce `isMinifyEnabled`/`isShrinkResources`/`proguardFiles`").
- Verified at the time with `./gradlew test assembleDebug assembleRelease` —
  release APK dropped from ~11.2 MB to ~1.3 MB. Re-confirmed now after F-47's
  dependency bumps: `assembleRelease` still succeeds and produces a
  ~1.46 MB APK, so R8 is still shrinking the icon set (and everything else)
  as expected on the newer toolchain.

### F-47 · Dependencies were well over a year stale — Done.

Done in the two steps the entry asked for, each built and tested before the
next: the Compose BOM alone first, then Kotlin and KSP together.
[libs.versions.toml](../gradle/libs.versions.toml) now carries Compose BOM
`2026.08.00`, Kotlin `2.4.10`, lifecycle `2.11.0`, activity-compose `1.13.0`,
navigation-compose `2.9.8`, coroutines `1.11.0` and core-ktx `1.19.0`.

- **The Compose BOM step forced `compileSdk` 36 → 37** on its own — the new
  BOM's artifacts (`ui-text-android` and others) require compiling against
  API 37, not something optional. `targetSdk` was deliberately left at 36
  rather than following it: Robolectric 4.16 (the newest *stable* release)
  caps out at API 36 and rejects a `targetSdk` above its `maxSdkVersion` at
  test-collection time, and Robolectric 4.17 — the release that adds SDK 37
  support — is still beta-only. `compileSdk` and `targetSdk` are independent
  by design (the AGP warning that flagged this says so directly), so this
  isn't a compromise, just not following the entry's compileSdk number out to
  targetSdk too, which it never asked for.
- **KSP's own versioning changed underneath this**: as of KSP 2.3.0 its
  version is no longer the `<kotlin>-<ksp>` composite the old `2.2.10-2.0.2`
  followed — it's decoupled and standalone now, so the paired release is
  just `ksp = "2.3.11"`.
- **The Kotlin step broke two things the compiler used to only warn about,
  both now promoted to hard errors**: `kotlinOptions { jvmTarget = "17" }` in
  [build.gradle.kts](../app/build.gradle.kts) is gone, replaced by the
  top-level `kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }`
  block the AGP/Kotlin migration guide points at; and two `arrayOf(...)`
  calls in
  [RestaurantDatabaseReaderTest.kt](../app/src/test/kotlin/com/saatxi/eatapp/data/sync/RestaurantDatabaseReaderTest.kt)
  (building mixed-type SQLite row arrays) needed an explicit `arrayOf<Any?>`
  — Kotlin 2.4 stopped tolerating the reified type parameter inferring to an
  intersection type silently.
- Verified with `./gradlew test assembleDebug assembleRelease lint` after
  each of the two steps — 101 tests green throughout, `assembleRelease`
  confirms R8 minification still runs clean against the new dependency set.
  Lint gained two findings the previous pass didn't have —
  `ModifierParameter` (one optional `Modifier` parameter in
  [RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt)
  without a plain `Modifier` default) and `LocalContextResourcesRead` (a
  `context.resources.getQuantityString` call in the same file) — both from
  Compose lint checks that shipped with this newer toolchain and now flag
  code that predates this pass; left alone as out of scope for a version
  bump. `GradleDependency` / `NewerVersionAvailable`, `UseKtx` and
  `OldTargetApi` / `ObsoleteSdkInt` remain, as before.

### Multi-language support pass

Section G in full, which retires the section: F-53 was its last item.

- **F-53 · Multi-language support — Done.** [CLAUDE.md](../CLAUDE.md)'s string
  rule changed from "all strings in English" to "English is the default
  locale, other languages are `values-xx/strings.xml` overrides" — exactly the
  relaxation the entry called for. A new
  [values-es/strings.xml](../app/src/main/res/values-es/strings.xml) covers
  every resource in the default `strings.xml` with Spanish text, including the
  five `<plurals>`: Spanish's CLDR rules need a `many` quantity alongside
  `one`/`other` (lint's `MissingQuantity` flagged its absence), which none of
  this app's plural counts will ever actually reach, so it duplicates the
  `other` wording rather than inventing a distinct phrasing for numbers in the
  millions. `app_name` is the one string not translated — a brand name — and
  is marked `translatable="false"` in the default `strings.xml`, which is what
  lint's `MissingTranslation` check needed to stop treating its absence from
  `values-es` as an error. Nothing in `Cuisine.kt` or the `.db` changed: the
  groundwork from F-43 (English vocabulary keys, resolved through
  `cuisineLabel()`) meant this was purely a resource addition.
- Verified with `./gradlew test assembleDebug lint` — 101 tests green, lint
  report unchanged from before the pass (`MissingQuantity` and
  `MissingTranslation` both appeared and were then resolved, not left as new
  findings).

### F-44 · Screen readers get fragments — Done.

Two new strings carry the spoken versions of the rating stars and the price
marks: `restaurant_rating_description` ("Rated %1$d of 5") and
`restaurant_price_description` ("Price range %1$d of 4", fed the price mark
count since the model only carries the rendered `"$"`-repeated label, not the
raw integer). The list row's `Card` in
[RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt)
now carries `Modifier.clearAndSetSemantics { contentDescription = ... }`
joining name, cuisine, rating, price and address (when present) into one
sentence, so the whole card is one screen-reader stop instead of five separate
text fragments; the card's own click action is untouched, since it comes from
`Card`'s `onClick` on the same layout node, one level inside where
`clearAndSetSemantics` only cuts the merge from *descendant* nodes. On the
detail screen ([RestaurantDetailScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/detail/RestaurantDetailScreen.kt))
the star row and the price chip get the same treatment individually, each
replacing what would otherwise merge into "3 slash 5" and "dollar dollar"
with the real phrase. `clearAndSetSemantics`'s lambda isn't `@Composable`, so
each description is resolved via `stringResource` into a local `val` first and
only captured inside the lambda.
- Verified with `./gradlew test assembleDebug lint` — 101 tests green, lint
  report unchanged from before the pass. No emulator or TalkBack run was
  available to confirm the actual announcement, only that the app builds and
  the existing test suite still passes.

### F-42 · The window theme is light-only — Done.

The app has no AppCompat dependency (Compose/Material3 only, per CLAUDE.md), so
there is no `Theme.AppCompat.DayNight` to switch to, and the framework's own
`android:Theme.*.DayNight` styles only exist from API 31 — below that on this
app's `minSdk = 26` they'd fail to resolve at runtime. The fix instead splits
`themes.xml` by the standard `night` resource qualifier: `values/themes.xml` kept
`android:Theme.Material.Light.NoActionBar`, and a new
[values-night/themes.xml](../app/src/main/res/values-night/themes.xml) parents on
`android:Theme.Material.NoActionBar` (the same family, without `.Light`). This
works on every API level back to 8, well under the app's floor, and means the
window background the system paints before Compose's first frame is now dark
when the system is in dark mode, instead of always flashing white.

### Colour scheme pass

- **F-41 · Half the colour scheme is still Material's default — Done.**
  [Color.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Color.kt) gained
  a `Neutral*`/`NeutralVariant*` tonal family, hand-derived from the Terracotta
  seed's hue (24°) at the low saturations M3's neutral (6%) and neutral-variant
  (14%) palettes use, at exactly the tone steps the baseline scheme maps onto
  `background`, `surface`, `surfaceVariant`, `outline` and their
  `on*`/container/inverse siblings — so those roles are now warm off-white/off-black
  instead of Material's default cool purple-gray. `error` and its container roles
  are the one family left untouched in hue: they use the standard M3 baseline red
  tones, since error is a semantic colour independent of brand and red doesn't
  clash with terracotta or sage. Both `lightColorScheme()` and `darkColorScheme()`
  in [Theme.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Theme.kt)
  now set every role the M3 baseline scheme defines, including the
  `surfaceContainer*` tiers, `surfaceDim`/`surfaceBright`,
  `inverseSurface`/`inverseOnSurface` and `scrim`. `inversePrimary` reuses the
  existing `Terracotta80`/`Terracotta40` constants rather than adding new ones,
  since those are already the right tones for that role.
- Verified with `./gradlew test assembleDebug lint` — all green, lint report
  unchanged from before the pass.

### Detail screen pass

Section F in full, which retires the section. The two entries turned out to be
one change: F-35 removes the hero, so F-38 needed somewhere else to land.

- **F-35 · The top app bar has no title — Done.** The hand-rolled hero Box is
  gone and its job moved into a `LargeTopAppBar`: the restaurant name is the
  title, so it shrinks into the bar as you scroll instead of leaving with the
  hero, and the bar takes over the hero's cuisine tint (`containerColor` and
  `scrolledContainerColor` both set to it — the tint is the screen's identity,
  not a scroll affordance). Dropping the hero also collapsed the content
  column's outer/inner nesting into one. Two details worth knowing:
  `exitUntilCollapsedScrollBehavior` gets an explicit `canScroll` guard, because
  the default `{ true }` lets a fling collapse the bar on a page short enough to
  fit and leave a blank strip under it; and loading/not-found keep a plain
  `TopAppBar`, since a large bar with no name to show would just stand empty
  above a centred message.
- **F-38 · No transition between list and detail — Done.** `EatAppNavHost` now
  wraps the graph in a `SharedTransitionLayout`, and the cuisine icon is the
  shared element: the 48 dp tinted disc in the list row travels into the 32 dp
  icon in the detail app bar. `sharedBounds` rather than `sharedElement` because
  the two are deliberately drawn differently — the bounds animate while the
  contents cross-fade. The destinations themselves only cross-fade, over the
  same 320 ms; the default horizontal slide would have dragged the badge
  sideways along with everything else. The two scopes Compose needs are
  published as CompositionLocals from the NavHost
  ([SharedTransition.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/SharedTransition.kt))
  rather than threaded through every screen signature, and the modifier is a
  no-op when they are absent, so the screens stay composable outside the graph —
  which matters for F-51. `androidx.compose.animation:animation` was added to
  the version catalog: it was already on the classpath through Foundation, but
  the app now uses its API directly.
- Verified with `./gradlew test assembleDebug lint` — all green, no new lint
  findings.

### List screen search and sort pass

Section E in full, which retires the section along with F-33 before it.

- **F-26 · The search field is bare — Done.** The field gained a leading
  search icon, a trailing clear button that only appears once there is
  something to clear (`list_search_clear`), `singleLine = true` so Enter can
  no longer insert a newline into a search box, and `ImeAction.Search`, whose
  action just drops focus — results already follow every keystroke, so there
  is nothing left for it to submit. `label` became
  `placeholder`, which is what stops the floating label from permanently
  costing a row of height. The placeholder text went from "Search by name" to
  "Search restaurants" while it was being moved: search has covered name,
  cuisine and address since the unused-column pass, so the old wording
  undersold it.
- **F-29 · No sorting — Done.** A `RestaurantSort` enum (`NAME`, `RATING`)
  runs from a sort menu in the app bar — a check mark on the active order,
  no vertical space taken from the list — through `RestaurantListUiState.sort`
  and the ViewModel's `Filters` into the repository. The DAO takes a
  `sortByRating: Boolean` rather than the enum, so the ordering stays a bound
  parameter (`ORDER BY CASE WHEN :sortByRating THEN rating ELSE 0 END DESC,
  name COLLATE NOCASE ASC`) instead of SQL assembled from a value, and the
  name order remains the tiebreak within a rating so both orders are stable.
  Sorting is not a filter: it is excluded from `hasActiveFilter`, and
  `clearFilters()` deliberately preserves it, since that button is reached
  from the "No matches" state where the user wants their restaurants back,
  not their chosen order undone.
- Verified with `./gradlew test assembleDebug lint` — 101 tests green (four
  new DAO cases for the rating order, its name tiebreak and its interaction
  with the filters, plus four ViewModel cases for the sort input), lint
  unchanged.

### List refresh indicator pass

- **F-33 · Two progress indicators, and a disappearing button — Done.** The
  app bar no longer swaps its refresh button for a `CircularProgressIndicator`
  while a sync runs: the button stays where it is and is disabled instead
  (`enabled = !uiState.isSyncing`), so the overflow icon beside it stops
  shifting on every refresh and `PullToRefreshBox`'s indicator is the only
  spinner on screen. That holds for a sync started from the button rather than
  the gesture too, since the box's indicator follows `isRefreshing` and not the
  drag. The screen's one remaining `CircularProgressIndicator` is F-20's
  initial-load one, which shows before the pull-to-refresh box has anything to
  report.
- Verified with `./gradlew test assembleDebug` — 93 tests green.

### State and architecture pass

Section D in full: both of its entries.

- **F-20 · Empty state flashes on cold start — Done.** `RestaurantListUiState`
  gained an `isInitialLoad` flag: true in `stateIn`'s initial value, false in
  every state the `combine` block builds. Since `combine` produces nothing
  until all of its sources have emitted, "that block ran at all" is exactly
  the signal that the database's first emission arrived — no extra flow needed
  to track it. The list screen shows a centred spinner while the flag is set,
  so an empty list can no longer be mistaken for a loaded-but-empty database
  and "No restaurants yet" only paints once it really is one.
- **F-22 · The Room entity is used directly as the UI model — Done.** New
  `ui/model/RestaurantUiModel.kt` holds what the screens draw plus the
  `Restaurant.toUiModel()` mapper; both ViewModels map at their edge, so
  `RestaurantListUiState.restaurants` and `DetailUiState.Loaded` carry UI
  models and neither screen sees the entity any more. The formatting that used
  to sit inside composables moved into the mapper: `"$".repeat(priceRange)`
  became a ready-made `priceLabel` (clamped, so a hand-built row can't draw a
  runaway chip), the detail screen's `repeat(5) { index < rating }` became
  `stars: List<Boolean>`, and a blank address is normalised to null so the
  location row is skipped instead of drawn empty. Anything that needs a string
  resource stayed in the composables — the cuisine label and the "3/5" rating
  text can't be resolved without a Context — so the model carries the raw
  `cuisineKey` and `rating` and `CuisineVisuals` resolves them at draw time.
- Verified with `./gradlew test assembleDebug lint` — 93 tests green, among
  them a new `RestaurantUiModelTest` pinning the mapper and three new
  ViewModel tests for the flag and the mapping; the lint report is unchanged
  from the previous pass (`GradleDependency` / `NewerVersionAvailable`, i.e.
  F-47; `UseKtx`; `OldTargetApi`; `ObsoleteSdkInt`).

### Sync robustness pass

Section B in full: all four remaining sync-hardening items.

- **F-03 · The download had no size limit — Done.** `download()` now copies
  through a new `copyUpToLimit(input, output, limit)` instead of raw
  `input.copyTo(output)`; past 10 MB it stops and the sync fails as
  `INVALID_FILE` instead of writing an unbounded stream into `cacheDir`.
  `copyUpToLimit` is a plain function (no Android dependency), so it is
  covered directly without a network round trip.
- **F-07 · Every refresh re-downloaded everything — Done.** The manager now
  persists the response `ETag` alongside the existing last-synced timestamp
  and sends it back as `If-None-Match`. A `304` short-circuits straight to a
  new `DatabaseSyncResult.UpToDate` — no file read, no `repository.replaceAll`
  wiping and reinserting every row for nothing — and the snackbar says
  "Already up to date" (`list_sync_up_to_date`) instead of claiming a refresh
  that didn't happen.
- **F-08 · No automatic first sync — Done.** `RestaurantListViewModel` gained
  an `init` block that checks the new `RestaurantRepository.count()` /
  `RestaurantDao.count()` and calls `syncNow()` once when it's zero, so a
  fresh install fills itself in instead of waiting on the empty state's
  button. Making this testable without hitting the network on every
  ViewModel construction is what motivated pulling a `DatabaseSyncManager`
  interface out of `RestaurantDatabaseSyncManager` (a `fun interface` with
  just `sync()`); the ViewModel test now runs against a hand-written
  `FakeDatabaseSyncManager` instead of the real one, which is also why it no
  longer needs `RobolectricTestRunner` at all. The "older than a day" half of
  the original idea was left out — it depends on F-06 and wasn't asked for.
- **F-09 · No connectivity pre-check — Done.** `sync()` now asks
  `ConnectivityManager` before doing anything else and fails immediately (as
  `SyncFailureReason.NETWORK`, the same "Couldn't download. Check your
  connection." message a real timeout would have produced) instead of
  burning up to 30 seconds across the two connect/read timeouts first. Needs
  `ACCESS_NETWORK_STATE`, added to the manifest and to CLAUDE.md's permission
  list — the only other permission besides `INTERNET`.
- Verified with `./gradlew test assembleDebug lint` — 85 tests green, nothing
  new in the lint report beyond one more instance of the pre-existing
  `SharedPreferences.edit` `UseKtx` finding (the new `saveETag`, same pattern
  as the existing `recordSyncTimestamp`).

### Low/S cleanup pass

Every entry scored **Low / XS** or **Low / S** at the time, done in one pass.

- **F-21 · Sync results are fragile across config changes — Done.** `SyncEvent`
  and its `MutableSharedFlow` are gone; the pending message now lives in
  `RestaurantListUiState` as `pendingSyncMessage` (renamed `SyncMessage`, still
  `Success`/`Error`), fed into the same `combine(...)` that builds the rest of
  the state. The screen's `LaunchedEffect` is keyed on the message itself and
  calls the new `onSyncMessageShown()` once it has shown it, which resets the
  state to null — the standard Compose one-shot-event-via-state pattern. This
  also gave F-34 (retry) a natural home: see below.
- **F-24 · The database singleton is duplicated — Done.** `EatAppDatabase`
  lost its companion object and `getInstance`'s double-checked locking
  entirely; there is now a single top-level `buildEatAppDatabase(context)`
  function, and `EatApplication`'s existing `by lazy` is the only thing that
  ever calls it — one singleton instead of two stacked on each other.
- **F-27 · The "1+" rating chip did nothing — Done.** Every synced restaurant
  has a rating of at least 1, so that chip filtered nothing while looking like
  it should. The row now runs `2..5` instead of `1..5`.
- **F-31 · No result count — Done.** A `list_result_count` plural renders
  above the results, but only when a filter is active and the list isn't
  empty — exactly the moment "12 restaurants" is worth knowing, as opposed to
  restating the total on an unfiltered list.
- **F-34 · No retry on the error snackbar — Done.** Folded into F-21's fix:
  an `Error` message now carries a "Retry" (`action_retry`) snackbar action,
  and `SnackbarResult.ActionPerformed` calls `syncNow()` directly.
- **F-45 · `ArrowBack` was deprecated and not RTL-aware — Done.**
  `Icons.Default.ArrowBack` became `Icons.AutoMirrored.Filled.ArrowBack` on
  the detail screen's back button; lint's `NotificationActionIcon`/mirroring
  warning for it is gone from the report.
- **F-46 · The sync message wasn't a plural — Done.** `list_sync_success`
  became a `<plurals>` resource (`Data refreshed (%1$d restaurant/s)`), read
  via `Resources.getQuantityString` from inside the snackbar's
  `LaunchedEffect` (not `pluralStringResource`, since that call site isn't
  composable). Lint no longer flags `PluralsCandidate` for it.
- Verified with `./gradlew test assembleDebug lint` — all green, and the
  lint report's remaining findings are unrelated to this pass (`GradleDependency`
  / `NewerVersionAvailable`, i.e. F-47; `UseKtx`; `OldTargetApi`;
  `ObsoleteSdkInt`).

### Query layer pass

- **F-15 · `%` and `_` in the search box acted as wildcards — Done.** The
  query is now escaped with `escapeLikeWildcards` (folded in the same step as
  `normalizeForSearch`) and the DAO's `LIKE` clause gained an `ESCAPE '\'`
  clause to match. A search for a literal `%` or `_` now matches that
  character instead of the whole table.
- **F-16 · No search debounce — Done.** The query half of the filter pipeline
  now runs through `debounce`, 250 ms for a non-blank query and 0 ms
  (immediate) for a blank one — so clearing the field or loading the screen
  for the first time isn't held up waiting on a timer that exists for
  keystrokes. `minRating` and `cuisineType` are unaffected: only the text
  query is debounced, since those are discrete taps rather than a stream of
  keystrokes. The search box itself still updates every keystroke instantly;
  only the repository query is throttled, via a second `Filters` flow
  (`queryFilters`) that the UI state's `filters` flow does not go through.

### Unused-column pass

Four columns removed from the entity, the reader, the UI and `data/eatapp.db`.

- **`photoUri` — Dropped.** It was `NULL` in every row and had never been read
  by any composable: the entity field, the `REQUIRED_COLUMNS` entry, the
  `SELECT` and the `cursor.isNull` mapping are gone.
- **`visitDate` — Dropped.** Its only appearance was one `InfoRow` on the
  detail screen, whose card is now titled "Rating and price"
  (`detail_section_rating`). It was the last `LocalDate` in the schema, so
  `Converters` and the `@TypeConverters` annotation went with it. This closes
  F-32 and F-37, which existed only to improve how that one row looked.
- **`createdAt` — Dropped.** Never read by anything: no composable, no query,
  no ordering. It briefly gained a `DEFAULT (CAST(strftime('%s','now') AS
  INTEGER) * 1000)` so it would not have to be typed by hand, before being
  removed outright in the same pass.
- **`notes` — Dropped, and this one cost something.** Unlike the others it was
  live: a card on the detail screen, one of the four fields folded into
  `searchText`, and part of the non-blank check in the reader. Search now
  covers `name`, `cuisineType` and `address` only, the reader's blank check is
  down to `name` and `cuisineType`, and `detail_section_notes` is gone. The
  DAO's `matches on notes` test and the reader's `rejects a NULL note` test
  went with it; `combines all three filters` now carries its query term in
  `address` instead.
- The reader only ever asked that `REQUIRED_COLUMNS` be *present*, so a `.db`
  still carrying any of the four dropped columns keeps importing unchanged; a
  test pins that. The Room version went 2 → 4, which the existing
  `fallbackToDestructiveMigration` handles by re-syncing.
- What is left is the minimum the UI actually renders: `id`, `name`,
  `cuisineType`, `address`, `rating`, `priceRange`. Only `address` is nullable.

### Cuisine vocabulary pass

- **F-18 · Dead code — Done.** `observeAll()` had no callers and was removed
  with the repository change. Still outstanding: the `GIT_COMMIT`
  `buildConfigField` is generated but never read. (`photoUri` was dropped
  outright in the unused-column pass above.)
- **F-25 · Filters ate the screen — Done.** The rating and cuisine rows moved
  inside the `LazyColumn` so they scroll away; only the search field stays
  pinned. Adding the cuisine row would otherwise have pushed the fixed header
  past ~210 dp on a phone.
- **F-28 · No way to clear filters — Done.** The "No matches" state now has a
  "Clear filters" button, and the filter chips themselves stay on screen when
  a filter matches nothing — previously the empty state replaced the entire
  list, taking the controls with it.
- **F-30 · No cuisine filter — Done.** Filter chips, each with its cuisine
  icon, listing only the cuisines actually present in the data via a new
  `DISTINCT` query.
- **F-39 · Cuisine icons never matched the data — Done.** `cuisineIcon`
  matched English keywords (`pizza`, `japan`, `bar`) against Spanish values
  (`Japonesa`, `Mediterránea`, `Frankfurt`), so *every* row fell back to the
  generic icon. Replaced with an exact match against the closed 22-key
  vocabulary in [Cuisine.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/local/Cuisine.kt),
  each key with its own distinct icon.
- **F-40 · Arbitrary cuisine colours — Done.** `cuisineTint` keyed off
  `cuisineType.hashCode().mod(3)`; it now keys off the enum ordinal, which is
  stable across releases and spreads evenly over the three container roles.
- **F-43 · Data migrated to English — Done.** `cuisineType` values became
  vocabulary keys and `notes` were translated. Restaurant names and addresses
  were deliberately left alone — `Plaça Santa Anna, Mataró` is a real place,
  not a string to translate. Multi-language support is now tracked as F-53.

### Crash, sync and search pass

- **F-01 · Negative `priceRange` crashed the screen — Done.** Handled by
  rejecting rather than coercing: `readRestaurants` fails the whole import as
  `INVALID_FILE` when `rating` is outside 0–5 or `priceRange` outside 0–4, and
  names the offending row id. A typo in the source data is now a message you
  can act on instead of a silently clamped value.
- **F-02 · NULL text columns caused an NPE — Done.** Rows with a blank `name`,
  `cuisineType` or `notes` are rejected the same way. `address` goes through
  `cursor.isNull` and stays genuinely optional. (`notes` has since been
  dropped; the check now covers `name` and `cuisineType`.)
- **F-05 · Failure details were thrown away — Done (partly).** Every failure
  site now logs its `detail` under the `EatApp.Sync` tag, so `adb logcat` tells
  you why a refresh failed. Still outstanding: surfacing that detail in the app
  behind a "Details" action on the snackbar — folded into F-34.
- **F-06 · No "last synced" timestamp — Done.** Stored in SharedPreferences on
  success and read back through `RestaurantDatabaseSyncManager.getLastSyncTime`.
  It shows in the About dialog only; putting a relative time under the list
  title, as originally sketched, was not done.
- **F-13 · Search only looked at the name — Done.** Superseded by F-14, which
  covers the same four fields through the normalized column.
- **F-14 · Accented text never matched — Done.** `Restaurant` gained a
  `searchText` column holding an NFD-folded, accent-stripped, lowercased
  concatenation of `name`, `cuisineType`, `address` and `notes`. (`notes` was
  later dropped; the column now covers the remaining three.) It is a
  constructor default derived from those fields, so it cannot drift from them
  and the sync importer needs no changes. The DAO's four `LIKE` clauses
  collapsed into one against `searchText`, and the repository folds the query
  with the same `normalizeForSearch` before it reaches Room.
- **F-17 · No Room migration strategy — Done.** Forced by F-14's schema change:
  the database is now `version = 2` with
  `fallbackToDestructiveMigration(dropAllTables = true)`. Correct for a pure
  cache, but it does mean existing installs come up empty once and have to be
  refreshed by hand — which makes F-08 (automatic first sync) worth more than
  it was.
- **F-19 · The detail screen could show nothing — Done.** `DetailUiState` now
  distinguishes `Loading`, `NotFound` and the loaded case; missing restaurants
  get an explanation and a back button instead of a blank screen. The strings
  went in hardcoded, though — see F-54.
- **F-36 · The address was dead text — Done (partly).** The address row fires
  `ACTION_VIEW` on a `geo:0,0?q=<address>` URI. The share action from the same
  entry was not added and is still worth having.

### Release signing pass

- **F-48 · Release builds were unsigned — Done.** `app/build.gradle.kts` gained
  a `release` signing config whose keystore path, store password, key alias and
  key password come from `local.properties` or, for CI, from the matching
  `EATAPP_*` environment variables — nothing secret is committed, and `*.jks` /
  `*.keystore` were added to `.gitignore` so a stray keystore cannot be
  committed by accident. When no keystore is configured the release build still
  succeeds but stays unsigned and now says so with an explicit warning, and only
  on release tasks so debug builds stay quiet. Verified end to end against a
  throwaway keystore: `assembleRelease` produced `app-release.apk` instead of
  `app-release-unsigned.apk` and `apksigner verify` confirmed the signature.
  README gained a "Signing releases" section and the release checklist now
  points at it.

### Test suite pass

- **F-23 · No tests at all — Done.** 69 JUnit4 unit tests under
  `app/src/test/kotlin/`, all four targets the entry named. Robolectric covers
  the two that need an Android runtime, so `./gradlew test` runs the whole
  suite on the JVM with no emulator. `readRestaurants` was extracted from
  `RestaurantDatabaseSyncManager` into `RestaurantDatabaseReader` so the
  validation could be exercised against a file without a network round trip.
  The tests found that **F-02 was only half fixed**: `cursor.getString` returns
  null for a NULL column, so `name.isBlank()` threw an NPE before the blank
  check could report anything, and the catch-all in `sync()` turned it into the
  same generic "Couldn't refresh the data" the entry complained about. Reading
  the three non-null text columns through `?: ""` makes the check do what it
  claimed to. Two tests deliberately pin behaviour the backlog calls wrong —
  F-11 (an empty table is rejected) and F-15 (`%` acts as a wildcard) — so
  fixing either has an obvious place to start.

### String resources pass

- **F-54 · Recent features hardcoded English strings — Done.** The detail
  screen's "not found" state and the About dialog's "Last synced" line now read
  from `strings.xml`, and `formatRelativeTime` became a `@Composable` that
  resolves its output through three `<plurals>` resources
  (`relative_time_minutes_ago` / `_hours_ago` / `_days_ago`) plus a
  `relative_time_just_now` string, replacing the hand-rolled `if (…) "s" else ""`
  pluralisation. F-53 is no longer blocked: every user-visible string in the app
  now lives in `values/strings.xml`. The `"$".repeat(priceRange)` price marks and
  the `"$rating+"` chip label are deliberately left as Kotlin — they are symbols
  and numbers, not prose; making them readable is F-44's and F-27's job.

### Launcher icon pass

- **F-52 · The launcher icon was still template-grade — Done.** The entry said
  "the generic Android robot"; what was actually there was a half-finished
  fork-and-knife. The knife drew, but the fork's tines, and its handle, were
  written as bare line segments (`M37,28 L37,44`, `M40,54 L40,84`) inside
  `fillColor` paths — zero-area subpaths, so they contributed nothing and the
  fork rendered as a solid blob. Both shapes also ran to `y=84`, outside the
  66dp safe circle a launcher mask is guaranteed to leave alone, so the
  bottoms were at the mercy of the device's mask. Redrawn as two closed filled
  outlines — a three-tined fork and a flat-spined knife, paired around the
  centre and scaled to fill the safe circle without touching it.
- The two lint findings the entry named are gone with it. `<monochrome>` now
  points at the same foreground drawable, which is all the themed-icon path
  needs since it only reads that layer's alpha — and it is why the shapes had
  to become real filled outlines rather than strokes. `ic_launcher_round.xml`
  was deleted: `android:roundIcon` already pointed at `@mipmap/ic_launcher`,
  so nothing referenced it, and the attribute itself went too — with
  `minSdk = 26` every device gets the adaptive icon and masks it round itself.
- `./gradlew lint` now reports neither `MonochromeLauncherIcon` nor the unused
  resource; what is left is unrelated (`GradleDependency` / `UseKtx` and
  friends, i.e. F-47 and F-45).

### Sync validation pass

- **F-04 · No magic-header check — Done.** `RestaurantDatabaseReader.read`
  now reads the first 16 bytes and compares them against `SQLite format 3\0`
  before the file reaches `SQLiteDatabase.openDatabase`, failing as
  `INVALID_FILE` with `"not a SQLite database: bad file header"`. Nothing was
  unsafe before — the file was already read-only and `SQLiteException` was
  caught — but a truncated download or an HTML error page saved as `.db` used
  to surface as whatever SQLite happened to say, or as "missing columns" when
  it opened an empty database anyway. A file shorter than the header (the
  empty file included) is rejected on the same path.

### Sync plumbing pass

- **F-10 · Temp files leak on abnormal exit — Done.** The download target is now
  a fixed `sync.db` rather than `sync_<millis>.db`, so a process death mid-sync
  leaves at most one file behind and the next download truncates it instead of
  adding another. Files left by earlier versions are swept at the start of every
  sync: anything in `cacheDir` matching the old `sync_*.db` shape is deleted.
- **F-11 · A legitimately empty dataset is rejected — Done.** The
  `restaurants.isEmpty()` branch is gone, so a `.db` with zero rows imports as
  zero rows and the list empties. It is the only way to sync back to nothing, and
  nothing is lost by allowing it: the header and `REQUIRED_COLUMNS` checks are
  what actually catch a malformed file. The test that pinned the old behaviour
  now asserts the new one.
- **F-12 · `DATABASE_URL` is hardcoded — Done.** The URL is now a
  `buildConfigField` set per build type, and `RemoteConfig.DATABASE_URL` reads
  `BuildConfig`. Release keeps the hardcoded `releaseDatabaseUrl` from
  `app/build.gradle.kts` and ignores any override, so nothing local can escape
  into a published APK; debug takes `eatapp.database.url` from
  `local.properties` or `EATAPP_DATABASE_URL` from the environment, defaulting to
  the same public URL. A non-`https://` override fails the build at configuration
  time rather than at runtime, since the app allows no cleartext traffic. The
  `signingSecret` helper became `localOrEnv`, shared with the signing config.
