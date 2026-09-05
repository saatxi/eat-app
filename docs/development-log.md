# EatApp development log

A single place to look up everything worth improving in this app, plus the
design-history record of the two redesign passes that shaped it, so none of
it gets lost between sessions. The backlog below is a menu, not a plan —
nothing in it is committed to, and items can be picked off in any order.

Every backlog entry has a stable ID (`F-01`…`F-73`). Use those in commit
messages and when asking for something to be worked on; they never get
renumbered, and items that get done stay in the list marked **Done** rather
than being deleted, so the file keeps a record of what changed and why.

- **Impact** — High: a crash, data loss, or something visibly broken /
  Medium: a real annoyance / Low: polish.
- **Effort** — XS: minutes · S: under an hour · M: an afternoon · L: bigger.

Large-screen and tablet support is deliberately not covered here. (A
`tablet-adaptive-layout-idea.md` file was referenced from this backlog's
earlier, separate-file form as where that write-up would live, but it was
never actually created — there's nothing to read yet, this is just where
tablet-layout notes would go if written.)

## Where to start

The second redesign pass — started 2026-09-04 with a UI/UX audit, now
[Appendix B](#appendix-b-visual-redesign-proposal-audit-second-pass-audit),
that found the app's theming/navigation foundations solid (see
[Appendix A](#appendix-a-visual-modernization-plan-first-redesign-pass)) but
its data model and a few screens thin — is now complete: no photos anywhere
(F-63), no notes (F-56) or tags (F-59), no visited/want-to-try status
(F-55), a flat Settings screen and an ungrouped edit form (F-62), no
statistics screen (F-64), Favorites lacking the list screen's own
search/sort/filter tools (F-60), and no swipe actions on list rows (F-65)
are all done. See **Done** for the full record.

The *first* pass is recorded in
[Appendix A](#appendix-a-visual-modernization-plan-first-redesign-pass): the
redesign pass started 2026-08-28 (three selectable colour schemes, bottom
navigation, favourites, a "what to eat" picker, optional link columns, and a
performance pass). All seven of its phases are done; its eighth and last —
usability polish, partly gated on a stable Material3 1.5.x release — is
still in progress (see CLAUDE.md's "Known blockers to revisit").

---

## Open

### F-70 · No test coverage for the import confirmation path

**Impact**: High · **Effort**: M

`ui/importing/RestaurantImportViewModel.kt` has no test file at all, even
though CLAUDE.md calls this screen "the last line of defence" against
untrusted shared files — nothing exercises its accept/reject/replace
decisions. `data/share/ContentFiles.kt` (enforces `MAX_IMPORT_BYTES` against
untrusted input), `BackupWriter.kt` and `RestaurantShareWriter.kt` are
likewise untested.

**Fix**: add a `RestaurantImportViewModelTest`, plus unit tests for
`ContentFiles.kt`'s size cap and the two writers.

### F-71 · Other data-layer classes still have no tests

**Impact**: Medium · **Effort**: M

`data/photo/RestaurantPhotoStorage.kt` (file I/O plus EXIF-based rotation),
`data/local/TagValidation.kt` (unlike its sibling `LinkValidationTest.kt`),
`data/prefs/AppLocaleManager.kt`, and
`data/repository/RoomRestaurantRepository.kt` (only exercised indirectly
through `RestaurantDaoTest`) have no dedicated test file.
`DataStoreUserPreferencesRepository.kt`'s own missing test is already
tracked separately, in Appendix A's Phase 8 "Still to write" list.

**Fix**: no architectural change needed, just tests — pick these off same as
any other coverage gap.

---

## Done

Recorded here rather than deleted, so the numbering stays stable.

### F-72 · `RestaurantListScreen.kt` has grown into a single ~1000-line file — Done.

Split along exactly the lines the entry named, a pure reorganisation with no
behaviour change — everything stays in the `com.saatxi.eatapp.ui.list`
package, so no other file's imports needed to change.

- **`RestaurantListScreen.kt`** (1007 → 277 lines): now just the screen's
  own composable, `EmptyState` (internal — reused by
  [FavoritesScreen](../app/src/main/kotlin/com/saatxi/eatapp/ui/favorites/FavoritesScreen.kt),
  [RestaurantImportScreen](../app/src/main/kotlin/com/saatxi/eatapp/ui/importing/RestaurantImportScreen.kt),
  [RouletteScreen](../app/src/main/kotlin/com/saatxi/eatapp/ui/roulette/RouletteScreen.kt)
  and [StatisticsScreen](../app/src/main/kotlin/com/saatxi/eatapp/ui/stats/StatisticsScreen.kt)),
  and `EmptyState`'s two previews.
- **New [SearchAndFilterBar.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/SearchAndFilterBar.kt)**
  (414 lines): `SearchAndFilterBar`, `FilterSection`, the sort-label helpers,
  and `SearchSuggestionsRow` plus its preview. `SearchSuggestionsRow` moved
  from `private` to `internal` since its call site (the screen's own
  `LazyColumn`) is now in a different file; `FilterSection` and the sort
  helpers stay `private`, used only within this file.
- **New [RestaurantRow.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantRow.kt)**
  (372 lines): `RestaurantRow`, `SwipeActionBackground`,
  `RestaurantRowSkeleton` and its preview data. `RestaurantRowSkeleton` and
  `SKELETON_ROW_COUNT` moved from `private` to `internal` for the same
  cross-file-call-site reason as `SearchSuggestionsRow`; `SwipeActionBackground`
  stays `private`.
- One real bug caught by the split itself: the first compile after moving
  `RestaurantRow` failed on an unresolved `contentDescription` inside its
  `clearAndSetSemantics` block — the monolith's single `import
  androidx.compose.ui.semantics.contentDescription` had silently covered
  both call sites (this one and `SearchAndFilterBar`'s), so splitting the
  file surfaced a missing import that isolated compilation wouldn't have
  hidden going forward.
- Verified with `./gradlew test assembleDebug lint` — 222 tests passing
  (unchanged; no logic moved, only which file each composable lives in),
  lint clean, and no new Kotlin compiler warnings (checked
  `:app:compileDebugKotlin --rerun` explicitly for unused-import warnings
  after moving code between files, since this project has no
  ktlint/detekt to catch that otherwise). Not verified: how any of the
  three screens actually look or behave on a real device — this entry
  changed no rendering logic, only file boundaries.

### F-73 · `material3Adaptive` and the Baseline Profile plugin are pinned off their own stable lines — Done.

Checked both against Google's Maven `maven-metadata.xml` rather than
assuming either was still current:

- **`material3Adaptive`**: latest version overall is `1.4.0-alpha01`; the
  newest *stable* release is still `1.3.0`, already what's pinned in
  [libs.versions.toml](../gradle/libs.versions.toml). Nothing to bump.
- **`androidx.baselineprofile`** (via `androidx.benchmark:benchmark-macro-junit4`,
  same `baselineProfile` version ref): the newest stable release is still
  `1.4.1` — the one Appendix A's Phase 7 already found incompatible with
  this project's AGP 9.3.2 — and `1.5.0-rc02`, already what's pinned, is
  still the latest version available on the `1.5.0` line. Nothing to bump.

**Fix**: no dependency change needed this time; both pins are already the
right ones. CLAUDE.md's "Known blockers to revisit" section now carries a
"last checked 2026-09-05" note on both the material3 and baselineprofile
entries, so a future pass through this list doesn't have to re-derive
which artifact each pin is even for.

- Verified with `./gradlew test assembleDebug lint` — no dependency version
  changed, so no new test/build/lint behaviour to check beyond confirming
  the build is still green. Not verified: nothing else, since this entry
  was a version check with no resulting code change.

### F-65 · No swipe actions on list rows — Done.

Every mutation (favorite, delete) used to require either the row's heart
icon or a trip into the detail screen. Swipe right toggles favourite; swipe
left requests a delete — both directions spring the row back to settled
immediately rather than letting the gesture itself carry it away, since a
favourite-toggle removes nothing and a delete only actually happens once the
confirmation dialog it triggers is accepted.

- **`RestaurantRow`** is now wrapped in a `SwipeToDismissBox`
  ([RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt)),
  its `confirmValueChange` firing the matching action (with the same
  `HapticFeedbackType.LongPress` the heart button already gives) and always
  returning `false` — so `SwipeToDismissBoxValue` is only ever used as a
  gesture signal here, never to actually remove the composable the way a
  literal "dismiss" would. A new `SwipeActionBackground` draws the revealed
  hint behind the row: a heart (filled or outlined, matching what the swipe
  would actually do) on a `primaryContainer` tint for favourite, a trash
  icon on an `errorContainer` tint for delete, aligned to whichever side is
  being revealed, drawing nothing once the row has sprung back to `Settled`.
- **New `DeleteConfirmDialog`**
  ([ui/common](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/DeleteConfirmDialog.kt))
  is the detail screen's own delete confirmation (same title/body/button
  strings) pulled out into a shared composable, now shown from
  `RestaurantListScreen`/`FavoritesScreen` too instead of a copy of the same
  dialog markup appearing a second and third time. `RestaurantRow` itself
  never deletes anything directly — a swipe past the delete threshold only
  calls `onDeleteRequest()`, which each screen wires to show this dialog;
  only accepting it calls the new `onDeleteRestaurant(id)` on
  `RestaurantListViewModel`/`FavoritesViewModel` (a thin
  `repository.delete(id)` wrapper, mirroring the detail screen's own
  `onDelete`).
- **Accessibility**: a drag gesture has no equivalent in TalkBack's default
  navigation, and delete had no non-gesture path on this row at all before
  this entry (only reachable via the detail screen's trash icon) — so the
  Card's existing `clearAndSetSemantics` block (already collapsing the row
  into one description per F-44) now also carries a `CustomAccessibilityAction`
  exposing "Delete" through the accessibility actions menu. Favourite
  doesn't need the same treatment: its `IconToggleButton` already sits
  outside that collapse and was already independently reachable.
- **Checked `material3`'s maven metadata** (per `CLAUDE.md`'s standing note,
  since `rememberSwipeToDismissBoxState`'s `confirmValueChange` parameter
  logs a deprecation warning in this BOM with no direct replacement yet) —
  still no stable 1.5.x as of this entry, only alpha releases, so there's
  nothing to migrate to regardless; left as the one (harmless, functioning)
  deprecation warning in the build.
- Verified with `./gradlew test assembleDebug lint` — 222 tests passing (2
  new: `onDeleteRestaurant` reaching the repository for both
  `RestaurantListViewModel` and `FavoritesViewModel`), lint report unchanged
  (`UnusedResources` still the same pre-existing 3) — no new strings needed,
  every string this touches already existed. Not verified: the swipe gesture
  itself, the revealed background's look, or the accessibility action
  through actual TalkBack — none of which run outside a real device, only
  that it compiles and the confirm/delete/favourite logic is covered by
  tests.

### F-60 · Favorites has no search or filters — Done.

Favorites reused `RestaurantRow` and `EmptyState` from the list screen but
had none of its search bar, sort control or filter chips, even though it
shows the same kind of list — an inconsistency between two screens with
near-identical content. Took the entry's second suggested option (a shared
composable) for the UI half and its first (lift the filtering logic in) for
the ViewModel half, rather than picking one for both: the ~150 lines of
search-field/sort-row/filter-panel Compose code were worth sharing outright,
but each ViewModel's `combine` chain differs enough (Favorites narrows the
same query down to favourited ids afterward) that forcing one generic
ViewModel abstraction over both would have been a bigger, riskier
abstraction than either screen's actual filtering logic.

- **New `SearchAndFilterBar`**
  ([RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt))
  is the search field, sort control and filter-chip panel pulled out of
  `RestaurantListScreen` into its own `internal` composable, taking plain
  primitives and callbacks rather than a `RestaurantListUiState` — so it
  doesn't care which screen's state shape is feeding it. `FavoritesScreen`
  now calls it exactly the way it already called `RestaurantRow`/`EmptyState`.
  `showSortAndFilters` (hide the sort/filter section, but never the search
  field itself, while there's nothing to sort or filter yet) is computed by
  each screen from its own condition rather than baked into the composable,
  since "nothing to filter yet" means something slightly different for an
  unfiltered list versus one already narrowed to favourites.
- **New `RestaurantFilters`/`Flow<RestaurantFilters>.debounced()`**
  ([RestaurantFilters.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantFilters.kt))
  is the query/minRating/cuisineType/visited/sort shape and the
  debounce-just-the-query-field logic `RestaurantListViewModel` already had,
  pulled out so `FavoritesViewModel` builds its repository query the exact
  same way instead of a second, hand-rolled copy that could quietly drift
  out of sync with it.
- **`FavoritesViewModel`** now calls the same `repository.observeFiltered(query, minRating, cuisineType, sort, visited)`
  the list screen does — no new DAO query — and narrows the result down to
  favourited ids afterward, same as before this entry. `FavoritesUiState`
  gained the same shape `RestaurantListUiState` already has
  (`searchQuery`/`minRating`/`cuisineType`/`visited`/`sort`/`availableCuisines`/`hasActiveFilter`).
  Tag pills also reach Favorites' rows for the first time as a side effect
  of this rewrite — the old version never threaded `observeTagsByRestaurantId()`
  into its `toUiModel()` calls (a gap the F-59 entry above already flagged
  as deferred to whoever picked this entry up).
- **`FavoritesScreen`** gained the matching "no matches, try clearing
  filters" empty state and result-count line the list screen has, reusing
  its exact strings (`list_empty_no_results_*`, `list_action_clear_filters`,
  `list_result_count`) rather than favourites-specific duplicates, since the
  UI element itself is now the literal same one. The F-66 quick-suggestion
  chips were deliberately not extended here — that entry's fix was scoped to
  the list screen specifically, and Favorites' own empty-vs-no-favourites
  states already cover its blank-slate case.
- No new strings needed at all: every string this touches already existed
  for the list screen and is generic enough (not `list_screen_*`-prefixed)
  to mean the same thing here.
- Verified with `./gradlew test assembleDebug lint` — 220 tests passing (8
  new: `FavoritesViewModelTest` gained cases for the search/min-rating/
  cuisine/visited/sort filters reaching both the state and the repository
  query, `clearFilters`, available cuisines, and the tags-reaching-the-row
  fix), lint report unchanged (`UnusedResources` still the same pre-existing
  3). Not verified: how the shared search/filter bar actually looks or
  behaves inside Favorites on a real device or emulator, only that it
  compiles and the existing/new tests pass.

### F-66 · Empty search shows a blank box — Done.

There was no guidance before the user typed anything — with no query and no
filter active, the space above the list where a result count sometimes shows
just sat blank. The entry's own wording (a "short list of suggestions") left
the exact shape of the fix a genuine open question, since this app has no
existing search-suggestions affordance to extend and the full list already
shows below regardless — resolved with the user before writing code: a row
of quick-filter chips, shown only while browsing everything (no query or
filter active), each one a shortcut into an existing filter rather than a
new feature of its own.

- **New `SearchSuggestionsRow`**
  ([RestaurantListScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/list/RestaurantListScreen.kt))
  takes over the exact spot the "N restaurants" result count already occupies
  when a filter is active — `else` branch of the same `if
  (uiState.hasActiveFilter)` check, so the two are mutually exclusive by
  construction rather than by a second condition that could drift out of
  sync. Three chips, reusing `FilterSection`'s own `FilterChip` look: "Top
  rated" (`onMinRatingChange(4)`, the same threshold `FilterSection`'s own
  "4+" chip already offers), "Want to try" (`onVisitedChange(false)`,
  reusing the existing `visit_status_want_to_try` string), and whichever
  cuisine appears most often among the restaurants currently on screen
  (`groupingBy { it.cuisineKey }.eachCount().maxByOrNull { it.value }`,
  computed from the same unfiltered list already in state — no new
  repository query needed since this branch is only reached when nothing is
  filtering the list down).
- **Tapping a chip applies the real filter** (not a separate "suggestion"
  state) by calling straight into `RestaurantListViewModel`'s existing
  `onMinRatingChange`/`onVisitedChange`/`onCuisineChange` — the row then
  disappears on the next recomposition since `hasActiveFilter` is now true,
  same as if the user had opened the filter panel themselves.
- Two new strings (`list_suggestions_title`, `list_suggestion_top_rated`)
  added to `values/`, `values-es/` and `values-ca/`.
- Verified with `./gradlew test assembleDebug lint` — 212 tests passing
  (unchanged; this is a UI-only change with no ViewModel logic — the
  `onXChange` methods it calls already existed and are already covered),
  lint report unchanged (`UnusedResources` still the same pre-existing 3, no
  new `MissingTranslation`). A new light/dark `@Preview` pair covers the row
  itself. Not verified: how it actually looks or behaves on a real device or
  emulator, only that it compiles and the preview is well-formed.

### F-59 · No free-form tags — Done.

"Terraza", "para grupos", "llevar niños" — recurring, user-invented labels
that don't fit the closed cuisine vocabulary. Built essentially as the
entry's own `Fix` described, plus two scope decisions made with the user
before writing code: tags round-trip through the restaurant
sharing/export-import feature (not deferred to a later item), and matching a
typed name against an existing tag is case-insensitive — reusing the
existing tag, keeping its original casing, rather than creating a
near-duplicate.

- **Room**: new `Tag` (`@ColumnInfo(collate = ColumnInfo.NOCASE)` on `name`
  plus a unique index — a case-insensitive uniqueness constraint at the
  SQLite level, for free) and `RestaurantTag` join entities (composite
  primary key, both foreign keys `ON DELETE CASCADE`) — this app's first use
  of `@ForeignKey`/a composite key anywhere. `EatAppDatabase` → version 9
  with a real `MIGRATION_8_9`, not the destructive fallback.
  [`TagDao`](../app/src/main/kotlin/com/saatxi/eatapp/data/local/TagDao.kt)
  is an `abstract class`, not an `interface`: this project sets no
  `-Xjvm-default` compiler flag, so whether `@Transaction` on a Kotlin
  interface default method is honoured by Room's codegen is
  toolchain-dependent — an abstract class with one concrete `@Transaction`
  method calling its own abstract methods sidesteps that ambiguity entirely.
- **`setTags(restaurantId, tagNames)`** replaces every link for a restaurant
  in one transaction: finds-or-creates each tag case-insensitively,
  de-duplicates the input up front, and both inserts use
  `OnConflictStrategy.IGNORE` — defensive hardening so a stray
  case-insensitive duplicate in the input is a no-op instead of a
  `SQLiteConstraintException` aborting the whole save.
- **Repository**: `insert`/`update` now take the tags to save and commit
  them in the same `database.withTransaction { }` as the restaurant row
  itself, rather than a second call the ViewModel makes afterward — the
  latter would leave the on-device `backup.json` one write stale after every
  tagged save (it's written from inside `insert`/`update`) and risked a
  restaurant persisting with no tags at all if the process died between two
  separate calls. `deleteAll()` also clears the `tags` table directly, since
  cascade only cleans up `restaurant_tags` when restaurants are deleted.
- **UI model**: `RestaurantUiModel`'s own doc comment is explicit that a
  `List` property would make the whole class Compose-unstable and hurt every
  list row's recomposition, so tags are carried as `tagsLabel: String`
  (comma-and-space-joined, mirroring `priceLabel`) rather than a list —
  composables split it back apart only at render time, never storing the
  split result. Tag names are validated to never contain a comma, which is
  what keeps that split unambiguous.
- **Display**: a new shared
  [`TagPillRow`](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/TagPills.kt)
  (`FlowRow` plus the same pill `Surface` shape the list row's "want to try"
  badge already used) draws under the cuisine label on list rows (capped at
  3 with a "+N" overflow, so row heights stay predictable across restaurants
  with wildly different tag counts), the detail screen's Overview card
  (unbounded), and the import review row (unbounded) — so a shared or
  imported file's tags are visible before the user confirms anything.
- **Edit form**: a new "Tags" section — a text field that commits a tag on
  IME Done or a typed comma, existing-tag suggestions filtered by what's
  typed so far (reusing the `FilterChip` and colours already built for
  cuisine filtering), and the tags already added as removable `InputChip`s.
- **Sharing/import**: `RestaurantExport` gained `tags: List<String> =
  emptyList()` (the same backward-compatibility treatment `notes`/`visited`
  got); import validates each tag the same per-row-lenient way the rest of a
  row already is (`normalizeTagName` — trimmed, rejected outright rather
  than silently stripped if it contains a comma or is over 40 characters),
  dedupes case-insensitively, and caps a single row at 20 tags so one
  malicious file can't create unbounded junk.
- **Favorites doesn't show tag pills yet**: `FavoritesViewModel` reuses
  `RestaurantRow` (the same one the list screen uses — see F-60) but doesn't
  thread tags into its `toUiModel()` calls, so a restaurant's `tagsLabel`
  defaults to empty there rather than showing anything. Left for whoever
  picks up F-60, which already tracks bringing Favorites in line with the
  list screen.
- Verified with `./gradlew test assembleDebug lint` — 212 tests passing (25
  new: DAO/repository coverage for case-insensitive find-or-create, replace
  semantics, cascade delete and `deleteAll`; a from-scratch migration
  regression test building the pre-migration schema by hand rather than
  adding a `room-testing`/`MigrationTestHelper` dependency, since that needs
  `exportSchema = true` schema JSON this project deliberately doesn't
  generate; edit/list/detail ViewModel cases; export/import validation
  cases), all seven `RestaurantRepository` fakes across the test suite
  updated to the changed interface, lint report unchanged (`UnusedResources`
  still the same pre-existing 3, no new `MissingTranslation` across the
  three new strings × three locales). Not verified: the chip-entry field,
  the pill badges, and the whole flow on a real device or emulator — only
  that it compiles, the ViewModel/DAO logic is covered by tests, and the
  migration opens a real pre-existing database cleanly.

### F-58 · Rating-and-price markup is copy-pasted three times — Done.

The stars-plus-"N/5"-plus-price-pill block was hand-duplicated across
`RestaurantListScreen.RestaurantRow`, `RestaurantDetailScreen` and
`RouletteScreen.RouletteResultCard` — extracted into one shared
[`RatingAndPriceRow`](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/RatingAndPriceRow.kt),
all three now call.

- **The three call sites didn't actually draw the same thing**, so this
  stayed one flexible composable rather than one fixed look forced onto
  three different rows: the list row shows a single decorative star next to
  the number to stay compact (`starCount = 1`), while detail and roulette
  draw a full five-star gauge (`starCount = MAX_RATING`). A single star
  always renders filled rather than gauging against the rating — with only
  one star, `index < rating` isn't a meaningful comparison, and filled is
  what the list row always looked like. `stacked` switches between the list
  row's vertical stack (stars above the price pill, end-aligned) and
  detail/roulette's horizontal row; `showRatingLabel` drops the "N/5" text
  for roulette, which never had it; `pricePaddingHorizontal`/`Vertical` and
  `horizontalArrangement` reproduce each site's own spacing exactly (detail's
  price pill padding was actually larger than the other two's — preserved,
  not quietly evened out); `ratingContentDescription`/`priceContentDescription`
  are only non-null on the detail screen, the one call site not already
  nested inside something else that collapses its semantics.
- **One incidental, low-risk fix bundled in**: the price pill is now
  genuinely absent when `priceLabel` is empty, everywhere — previously only
  Roulette guarded with `isNotEmpty()`; the list row and detail screen drew
  a small empty pill for a restaurant with no price set. Unifying the three
  naturally adopted the safer behaviour rather than keeping the bug in two
  of them.
- Each of the three files lost several now-unused imports (`Icons.Star`,
  `RoundedCornerShape`, in detail's case also `Surface` and the semantics
  imports) as their inline markup was replaced by the one call.
- Verified with `./gradlew test assembleDebug assembleRelease lint` — 187
  tests passing (unchanged; pure UI refactor, no ViewModel logic touched),
  R8 unaffected, lint report unchanged. Added a light/dark `@Preview`
  showing all three configurations side by side. Not verified: the on-screen
  result, only that it compiles and each call site's parameters reproduce
  what the removed inline code did.

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
above and [Appendix B](#appendix-b-visual-redesign-proposal-audit-second-pass-audit)).
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

---

## Appendix A: Visual modernization plan (first redesign pass)

The working plan for the redesign pass started on 2026-08-28: three
selectable colour schemes, a bottom navigation bar, two new destinations,
optional link columns in the data file, and a performance pass. Phases 1–7
are done; Phase 8 is still in progress (see below).

Inspired by Compose Samples' **Now in Android** (bottom bar with filled/outline
icon pairs, colourful topic chips) and **Reply** (navigation suite that becomes
a rail on large screens, colourful per-item accents).

Large-screen two-pane layout is deliberately still out of scope (see the
tablet/large-screen note near the top of this file). The
`NavigationSuiteScaffold` in Phase 5 gives the rail for free, but not the
list/detail split.

### Status

| Phase | | |
|---|---|---|
| 1 | Theme foundations — palettes, accents, typography | **Done** |
| 2 | Preferences (DataStore) and Settings screen | **Done** |
| 3 | Favourites | **Done** |
| 4 | Website and Instagram links | **Done** |
| 5 | Bottom navigation | **Done** |
| 6 | "What to eat" picker | **Done** |
| 7 | Performance | **Done** |
| 8 | Usability and M3 Expressive | In progress |

At the last checkpoint: `test`, `assembleDebug` and `lint` all green, 145 unit
tests passing (up from 101), still JVM-only with no emulator.

### Why

- **The old palette had a real accessibility bug.** The `onXContainer` roles
  reused their family's tone 40 because tones 10/20/30/90 were never generated.
  `Sage40 #5B7B4A` on `Sage80 #C9D4B8` is about 2.9:1, below the 4.5:1 WCAG AA
  needs for normal text — visible in the selected cuisine filter chips and in
  the badge behind every list row's icon. Nothing caught it because nothing was
  checking.
- **The app looked monotonous.** `cuisineTint` spread 24 cuisines over three
  container roles (`ordinal % 3`), so a screenful of rows cycled through the
  same trio instead of reading varied.
- **Only 5 of the ~15 M3 type styles were defined**, so `bodyMedium` (every
  row's secondary line) and `headlineMedium` (the detail screen's
  `LargeTopAppBar`) silently fell back to the Material baseline.
- **No bottom bar, because there was nowhere to navigate**: the graph had two
  destinations, `list` and `detail/{id}`.
- **The detail screen was thin** — cuisine, address, rating, price, and nothing
  else. No way to reach a restaurant's website or Instagram, because the data
  didn't carry them.
- **A concrete performance problem**: `RestaurantUiModel` held
  `stars: List<Boolean>`, which marked the class unstable for Compose and made
  every row unskippable — any state change recomposed the whole list.

### Decisions

| Topic | Decision |
|---|---|
| Tabs | Restaurants · Favorites · What to eat · Settings |
| Colour | Three complete palettes, user-selectable in Settings |
| Typography | Bundled variable font + full M3 scale |
| Scope | Performance + M3 Expressive + Baseline Profile |
| Data | Optional `website` / `instagram` columns in the `.db` |
| CLAUDE.md | The "no emulator is ever required" rule is relaxed for the Baseline Profile module |

---

### Phase 1 — Theme foundations · Done

#### Three palettes with complete tonal ramps

[Color.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Color.kt) now
holds only the shared error tones. Each palette lives in
`ui/theme/palette/`: [SaffronPalette.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/palette/SaffronPalette.kt),
[GardenPalette.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/palette/GardenPalette.kt),
[IndigoPalette.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/palette/IndigoPalette.kt),
declaring tones through the types in
[Tones.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Tones.kt).

**Saffron** (default — saffron orange + teal + plum)

```
Primary    10 #3A0B00  20 #5D1900  30 #862E0C  40 #B4471B  80 #FFB59B  90 #FFDBCF  95 #FFEDE7
Secondary  10 #002022  20 #003739  30 #004F52  40 #00696D  80 #4DDADF  90 #A8F0F3  95 #D2F8FA
Tertiary   10 #2E0B33  20 #46204A  30 #603663  40 #7A4E7E  80 #EBB5EE  90 #FFD7FB  95 #FFEBFB
Neutral     4 #0F0B09   6 #140F0D  10 #1F1613  12 #241A17  17 #302521  20 #372B27  22 #3C2F2B
           24 #413430  87 #E5DBD6  90 #EDE3DE  92 #F2E8E3  94 #F8EEE9  95 #FAF1EC  96 #FCF4EF
           98 #FFF8F6 100 #FFFFFF
NeutralVar 30 #53433C  50 #85736A  60 #A08D83  80 #D8C7BE  90 #F5E3DA
```

**Garden** (deep green + amber + blue-green)

```
Primary    10 #00210E  20 #00391C  30 #00522A  40 #226B3E  80 #8FD9A6  90 #ABF3C1  95 #C7FFD8
Secondary  10 #261A00  20 #402D00  30 #5C4200  40 #7A5900  80 #F3C03F  90 #FFDF95  95 #FFEFCE
Tertiary   10 #001F26  20 #00363F  30 #1E4D56  40 #38656E  80 #A0CFDA  90 #BCEBF6  95 #DDF6FB
Neutral     4 #060D08   6 #0A120C  10 #111811  12 #151C16  17 #202721  20 #252C26  22 #29302A
           24 #2E352F  87 #DCE4DC  90 #E4ECE3  92 #E9F1E8  94 #EFF6EE  95 #F2F9F0  96 #F4FBF2
           98 #F9FEF7 100 #FFFFFF
NeutralVar 30 #3F4A40  50 #6F7B70  60 #899589  80 #C0CCC0  90 #DCE8DB
```

**Indigo** (indigo + coral + sage)

```
Primary    10 #00105C  20 #182878  30 #313E90  40 #4A57A9  80 #B9C3FF  90 #DEE0FF  95 #F0EFFF
Secondary  10 #410004  20 #601A18  30 #7E2D2C  40 #9C4341  80 #FFB3AE  90 #FFDAD6  95 #FFEDEA
Tertiary   10 #092016  20 #1F352A  30 #354B40  40 #4C6357  80 #B2CCBD  90 #CEE9D8  95 #DCF7E6
Neutral     4 #08090E   6 #0D0E13  10 #121318  12 #16171C  17 #202126  20 #26272C  22 #2A2B30
           24 #2E2F35  87 #DCDCE3  90 #E4E4EB  92 #E9E9F0  94 #EFEFF6  95 #F2F1F9  96 #F5F4FB
           98 #FBF8FF 100 #FFFFFF
NeutralVar 30 #45464F  50 #767680  60 #90909A  80 #C6C6D0  90 #E2E1EC
```

The tone-to-role mapping is written **once** in
[PaletteSchemes.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/PaletteSchemes.kt),
rather than per scheme. That is what makes the old contrast bug
unreintroducible: an on-container is always the far end of its own ramp, stated
in one place. `onXContainer` is tone 10 in light and tone 90 in dark.

#### Cuisine accents: 3 → 8

[CuisineAccents.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/CuisineAccents.kt)
defines `CuisineTint` and a `LocalCuisineAccents` static CompositionLocal
carrying eight accents, published by `EatAppTheme` for the active palette.
Light = container tone 90 / on tone 10; dark = container tone 30 / on tone 90.
`cuisineTint` in
[CuisineVisuals.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/CuisineVisuals.kt)
now indexes `ordinal % 8`; an unknown key still falls back to `surfaceVariant`,
so a newer data file never breaks an older app.

#### Palette and mode selection

[Theme.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Theme.kt)
exposes `AppPalette` (SAFFRON / GARDEN / INDIGO) and `ThemeMode`
(SYSTEM / LIGHT / DARK), with `EatAppTheme(palette, themeMode, content)`. Enum
names are what gets persisted, so they must not be renamed without a migration.
Both parameters default, so the existing `@Preview` composables were untouched.

#### Typography

Outfit Variable (SIL OFL) bundled at `app/src/main/res/font/outfit.ttf`, ~110 KB,
licence in `app/licenses/OFL-Outfit.txt`. Weights come from
`FontVariation.Settings`, which needs API 26 — the project's `minSdk`.

Outfit carries display, headline and title; body and label stay on
`FontFamily.Default`. Deliberate: Outfit gives the app character at large
sizes, but at 12–16sp a system font the platform has already hinted for the
user's screen reads better. The full M3 scale is now spelled out in
[Type.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Type.kt).

---

### Phase 2 — Preferences and Settings · Done

`androidx.datastore:datastore-preferences` and `androidx.core:core-splashscreen`
added to the version catalog;
[UserPreferencesRepository.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/prefs/UserPreferencesRepository.kt)
(interface + `UserPreferences`) and
[DataStoreUserPreferencesRepository.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/prefs/DataStoreUserPreferencesRepository.kt)
written and exposed as a third `by lazy` on
[EatApplication.kt](../app/src/main/kotlin/com/saatxi/eatapp/EatApplication.kt).
Every stored value is read back defensively: a renamed enum or a non-numeric id
degrades to the default rather than throwing, because the file outlives any one
version of the app. `formatRelativeTime` moved to
[ui/common/RelativeTime.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/common/RelativeTime.kt).

#### Wiring `MainActivity`

[MainActivity.kt](../app/src/main/kotlin/com/saatxi/eatapp/MainActivity.kt)
calls `installSplashScreen()` before `super.onCreate`, reads
`UserPreferences?` into a `mutableStateOf` seeded `null`, and holds the splash
with `setKeepOnScreenCondition { preferences == null }` until the DataStore
flow's first emission — no `runBlocking`, so the startup metric Phase 7 will
measure stays honest. `EatAppTheme` is now called with the stored
palette/mode, falling back to `UserPreferences.Defaults` for the one frame
before that first emission (which the splash is covering anyway).

#### `SettingsScreen` and `SettingsViewModel`

New `ui/settings/SettingsScreen.kt` +
[SettingsViewModel.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/settings/SettingsViewModel.kt).
The palette picker is three `Card`s, each built from `palette.tones.lightScheme()`
/ `darkScheme()` directly (not the currently-applied `MaterialTheme`, since two
of the three cards are never the active scheme) and resolved against the mode
actually in effect via the new `isDarkTheme(mode)` helper in
[Theme.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/theme/Theme.kt) —
shared with `EatAppTheme` itself so the preview can't drift from what
selecting a palette actually produces. Mode selection reuses
`SingleChoiceSegmentedButtonRow`. Sync feedback (last-sync time, a sync
button, and the same `SyncMessage`-driven snackbar the list screen uses,
reusing that sealed interface) replaces what used to be the list screen's
"About" dialog; `about_version_template` gained a third `%3$s` slot for
`BuildConfig.GIT_COMMIT` alongside version name and code.

Not yet wired into navigation — `EatAppNavHost` still only has `list` and
`detail/{id}`. `SettingsScreen` becomes reachable once Phase 5 restructures
the graph around `NavigationSuiteScaffold`; until then it's covered by its
ViewModel test and a `@Preview`.

`SettingsViewModel` added to
[AppViewModelProvider.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/AppViewModelProvider.kt).

The overflow menu and the "About" `AlertDialog` are gone from
`RestaurantListScreen.kt`, along with the now-unused `list_action_more` /
`list_action_about` strings.

---

### Phase 3 — Favourites · Done

**Where they live: DataStore, not Room.** [EatAppDatabase.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/local/EatAppDatabase.kt)
uses `fallbackToDestructiveMigration(dropAllTables = true)` — right for a cache
of a re-downloadable file, wrong for user data. Favourites are a tiny
`Set<Long>`; putting them in the cache database would mean either abandoning
that policy or standing up a second database with real migrations, and the size
doesn't justify it. `UserPreferences.favoriteIds` already existed from Phase 2.

Ids are stable: the reader preserves the source `.db`'s id verbatim
(`RestaurantDatabaseReader.kt`, `id = cursor.getLong(0)`), so a favourite
survives a sync. If the ids in the source file are ever renumbered, favourites
drift.

- `RestaurantListViewModel` gained a `UserPreferencesRepository` constructor
  parameter. A separate `restaurantsWithFavorites` flow combines the filtered
  restaurant stream with `preferences.map { it.favoriteIds }` before feeding
  the outer `uiState` combine — kept as its own `combine()` rather than adding
  a sixth flow to the existing one, which would have dropped it out of
  kotlinx.coroutines' typed 5-flow overload and into the untyped vararg one.
  `onFavoriteToggle(id)` writes through to the repository.
- `RestaurantRow` (`RestaurantListScreen.kt`) gained an `onFavoriteToggle`
  parameter and now draws the heart in a `Box` **alongside** the `Card`, not
  inside it: the card's `clearAndSetSemantics` collapses its whole subtree into
  one accessibility node, which would otherwise swallow the heart's own toggle
  semantics and leave it unreachable under TalkBack. The card's content row
  gained 44dp of extra end padding so the overlaid heart (top-end corner)
  doesn't sit on top of the rating/price column. `RestaurantRow` and
  `EmptyState` are now `internal` instead of `private`, so `FavoritesScreen`
  can reuse them.
- `RestaurantDetailViewModel` gained the same `UserPreferencesRepository`
  parameter and combines `observeById(id)` with `favoriteIds` the same way.
  `DetailTopBar` gained a leading `IconButton` favourite toggle ahead of the
  cuisine badge in its actions row.
- Both toggles perform `HapticFeedbackType.LongPress` — the one haptic type
  guaranteed present across Compose UI versions, rather than guessing at the
  newer `ToggleOn`/`ToggleOff` constants sight-unseen against a BOM this build
  couldn't inspect offline.
- New `ui/favorites/FavoritesScreen.kt` + `FavoritesViewModel.kt`. No new DAO
  query: `FavoritesViewModel` reuses `repository.observeFiltered(null, null,
  null)` unchanged and filters to `favoriteIds` in memory, the same "no new
  query" approach Roulette (Phase 6) uses for its own filters. Its own empty
  state (`favorites_empty_title` / `_body`) covers the no-favourites case.
- `AppViewModelProvider` wires all of the above through `EatApplication`,
  which already exposed both `repository` and `userPreferences`.

---

### Phase 4 — Website and Instagram links · Done

#### Optional columns

`REQUIRED_COLUMNS` in
[RestaurantDatabaseReader.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/sync/RestaurantDatabaseReader.kt)
was **not** touched. Had `website` and `instagram` gone in there, the already
published `.db` would have stopped validating and users would have opened the
app to an empty list. They live in a separate `OPTIONAL_COLUMNS` instead.

The `PRAGMA table_info(restaurants)` that already ran says which are present,
and the `SELECT` projection is composed from those names. This is not SQL built
from the file's content: the literals come from our own constant and only
*which* to include depends on the file, so the security rule in
[CLAUDE.md](../CLAUDE.md) holds. Indices are resolved with `getColumnIndex`,
which returns -1 for an absent column.

#### Validation

Both values end up in an `Intent.ACTION_VIEW`, so a hand-edited or hostile file
could otherwise hand the system a `javascript:`, `intent:` or `file:` URI.
[LinkValidation.kt](../app/src/main/kotlin/com/saatxi/eatapp/data/sync/LinkValidation.kt)
is a whitelist, and deliberately free of Android imports so it can be tested as
plain Kotlin:

- **`website`** — only `http` and `https`. A value with no scheme is read as
  `https://`, since data files tend to hold bare hosts. Anything else → null.
- **`instagram`** — the **handle**, not a URL, matched against
  `^@?[A-Za-z0-9._]{1,30}$` with the `@` stripped. The URL is built by the app,
  which makes scheme injection structurally impossible.

An invalid value degrades to null with a logged warning; it does **not**
invalidate the file. Same graceful degradation an unrecognised cuisine key
gets — one bad cell shouldn't cost the user every restaurant.

#### Propagation

`Restaurant` gained `website` / `instagram` (not part of `searchText`);
`EatAppDatabase` went to version 5, which the existing destructive migration
handles by itself. `RestaurantUiModel` carries both plus a `hasLinks`
convenience. The detail screen draws a "Links" card — omitted entirely when
both are null — reusing the existing clickable `InfoRow`, with
`Icons.Outlined.Language` and `Icons.Outlined.AlternateEmail`.

The `https` Instagram URL deep-links into the Instagram app on its own when
installed, so no `instagram://` scheme and no `<queries>` manifest entry are
needed.

**Also fixed here**: the address row's `geo:` intent was unguarded, so a device
with no maps app would have crashed the detail screen. Both it and the links
now go through one `Context.openUri` helper that catches
`ActivityNotFoundException` and shows a toast.

Data authors: the two columns are documented in the
[README](../README.md#the-optional-link-columns), with the `ALTER TABLE` to add
them to an existing file.

---

### Phase 5 — Bottom navigation · Done

New [navigation/TopLevelDestination.kt](../app/src/main/kotlin/com/saatxi/eatapp/navigation/TopLevelDestination.kt),
exactly as planned:

```kotlin
enum class TopLevelDestination(
    val route: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector,
    @StringRes val labelRes: Int
) {
    LIST(     "list",      Icons.Filled.Restaurant, Icons.Outlined.Restaurant,     R.string.nav_restaurants),
    FAVORITES("favorites", Icons.Filled.Favorite,   Icons.Outlined.FavoriteBorder, R.string.nav_favorites),
    ROULETTE( "roulette",  Icons.Filled.Casino,     Icons.Outlined.Casino,         R.string.nav_roulette),
    SETTINGS( "settings",  Icons.Filled.Settings,   Icons.Outlined.Settings,       R.string.nav_settings)
}
```

The filled/outline pair by selection state is Now in Android's pattern. Every
icon was already in `material-icons-extended`, and both that dependency and
`material3-adaptive-navigation-suite` turned out to already be wired into
`app/build.gradle.kts` from Phase 1 — no dependency changes needed.

[EatAppNavHost.kt](../app/src/main/kotlin/com/saatxi/eatapp/navigation/EatAppNavHost.kt)
restructured:

- The `NavHost` is now wrapped in **`NavigationSuiteScaffold`**: bottom bar on
  a phone, navigation rail on a tablet, with no extra code — its `layoutType`
  defaults to `NavigationSuiteScaffoldDefaults.calculateFromAdaptiveInfo(...)`,
  which the "hide on detail" branch below has to name explicitly rather than
  omit, since a Kotlin default-parameter expression can't be reused across two
  call sites without repeating it. `currentWindowAdaptiveInfoV2()` is used
  rather than the older `currentWindowAdaptiveInfo()` the IDE's own
  autocomplete reaches for first, which is deprecated in this BOM in favour of
  the V2 overload (L/XL window size class support).
- `SharedTransitionLayout` stays **outside** the scaffold, so the list→detail
  badge transition keeps working.
- The bar hides on detail: `layoutType = NavigationSuiteType.None` when
  `currentBackStackEntryAsState().value?.destination?.route == Routes.DETAIL`.
- Tab navigation uses `launchSingleTop = true`, `restoreState = true` and
  `popUpTo(graph.findStartDestination().id) { saveState = true }`, so each tab
  keeps its own scroll position and filters across visits.
- `SettingsScreen` — built in Phase 2 but never reachable — is now the
  `SETTINGS` tab's destination.

---

### Phase 6 — "What to eat" · Done

New [ui/roulette/RouletteViewModel.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/roulette/RouletteViewModel.kt)
+ [RouletteScreen.kt](../app/src/main/kotlin/com/saatxi/eatapp/ui/roulette/RouletteScreen.kt):

- Picks at random among the restaurants passing this screen's own filters,
  reusing `repository.observeFiltered(...)` unchanged — no new query. A
  favourites-only filter narrows the candidates in memory afterwards, the same
  approach Favourites (Phase 3) uses.
- `Random` is **injected via the constructor** (defaulting to `Random.Default`),
  so `RouletteViewModelTest` seeds it (`Random(42)`) and asserts two
  identically-seeded ViewModels against identical data land on the same pick.
- Its own light filters: minimum-rating chips (`2+`…`5+`, same reasoning as
  the list screen — every synced restaurant already rates at least 1) and a
  "favourites only" `FilterChip`.
- `RouletteUiState.pickCount` increments on every `pick()`, independent of
  whether the picked restaurant's identity actually changed — needed because
  chance can land on the same restaurant twice in a row, and the shuffle
  animation should still play. A `picked` that falls out of the candidate pool
  after a filter changes is cleared back to the "pick one" prompt rather than
  left showing a restaurant that no longer matches.
- A large `RouletteResultCard` (cuisine icon, name, cuisine label, star rating,
  price chip, address) with a shuffle effect: `AnimatedContent` cross-fades the
  card content on an actual pick change, while a separate `Animatable`-driven
  `Modifier.graphicsLayer { rotationY = ... }` spins the card a full turn on
  every `pick()` regardless — a face-on card flip that still reads as "shuffled"
  even when the outcome repeats. Haptic feedback (`HapticFeedbackType.LongPress`)
  fires when the pick button is pressed. Tapping the result card opens its
  detail screen.
- `roulette_empty_title` / `_body` empty state when the current filters match
  nothing.

---

### Phase 7 — Performance · Done

**Done**: `RestaurantUiModel` no longer holds `stars: List<Boolean>`. Every
property is a primitive or a String, so the class is stable and rows are
skippable; the stars are computed at draw time from `rating`, which was already
in the model.

**Also done**: Compose compiler metrics behind an optional Gradle property.
`app/build.gradle.kts` adds a `composeCompiler {}` block, gated on
`-Peatapp.composeMetrics=true`, that points `metricsDestination` and
`reportsDestination` at `build/compose_metrics/`. Verified the point-1 claim
rather than just assuming it: `gradlew.bat :app:compileDebugKotlin
-Peatapp.composeMetrics=true` produces `app-classes.txt` showing
`stable class ...ui.model.RestaurantUiModel` with every property `stable`, and
`app-composables.csv` showing `RestaurantRow` as `composable=1, skippable=1,
restartable=1`. The report only reflects files Kotlin actually recompiles in
that invocation, so a metrics run after an unrelated no-op build can come back
thin — force a real recompile (e.g. add `--rerun` on `compileDebugKotlin`) if
that happens.

**Also done**: `contentType` and `animateItem()` on both `LazyColumn`s
(`RestaurantListScreen.kt`'s list and `FavoritesScreen.kt`'s) — they already
had `key`. Each `item`/`items` call now tags a `contentType` (`"filters"`,
`"empty"`, `"header"`, `"restaurant"`) so the layout only recycles a
composed slot against another item of the same shape, and every item's root
composable carries `Modifier.animateItem()` so insertions, removals and
reorders (a filter narrowing the list, a favourite toggle removing a row from
`FavoritesScreen`) animate instead of jump-cutting. This needed two small
signature additions: `FilterSection` and `RestaurantRow` (`RestaurantRow` is
also called directly from `FavoritesScreen.kt`) neither took a `Modifier`
before — both now do, `modifier: Modifier = Modifier`, applied to each one's
outermost layout, which is what `animateItem()` needs a stable modifier chain
on to work at the call site rather than buried inside.

**Also done**: `pluralStringResource` instead of `context.resources.getQuantityString`
for the sync-result snackbar text. The call site is a `LaunchedEffect`, whose
block is a plain suspend lambda rather than `@Composable`, so
`pluralStringResource` (like `stringResource`) can't be called from inside it
directly — the message text is now resolved in the composable body itself,
right before the effect, keyed the same way, and the effect reads the
already-resolved string. Turned out the identical pattern existed twice, not
once as the plan below assumed: `RestaurantListScreen.kt`'s sync snackbar and
`SettingsScreen.kt`'s (its "Same pattern as the list screen's sync feedback"
comment was correct about the code, just not about lint already catching
both copies). Both are fixed the same way; `SettingsScreen.kt` keeps its
`LocalContext.current` since `RestaurantDatabaseSyncManager.getLastSyncTime(context)`
elsewhere in that file still needs it. This clears the `LocalContextResourcesRead`
lint warning (`gradlew.bat lint` now reports zero occurrences, confirmed from
the SARIF output).

**Also done**: `EmptyState`'s (`RestaurantListScreen.kt`) `modifier` default
changed from `Modifier.fillMaxSize()` to a bare `Modifier`, which is what
`ModifierParameter` actually wants — an optional `Modifier` parameter should
default to the no-op `Modifier`, not bake in a specific layout behaviour the
caller might not want. All six call sites that had been relying on that
default now pass `modifier = Modifier.fillMaxSize()` explicitly instead, so
behaviour is unchanged: the two in `RestaurantListScreen.kt`'s screen body and
its two `@Preview`s, and one each in `FavoritesScreen.kt` and
`RouletteScreen.kt`. `gradlew.bat lint` confirms zero `ModifierParameter`
occurrences.

**Also done**: the `:baselineprofile` module (`com.android.test`,
`androidx.baselineprofile` plugin) — see the [README](../README.md#baseline-profile)
for how to run it — and the profile itself has now actually been generated on
a connected physical device (Gradle reported it as `CPH2557 - 15`) via
`gradlew.bat :app:generateBaselineProfile`, landing at
`app/src/release/generated/baselineProfiles/baseline-prof.txt` (~8,570 rules).
**Not** `app/src/main/baseline-prof.txt` as originally planned below and as
this doc first said — that was wrong, corrected once an actual run showed
where the plugin puts it for a project with no product flavors. The `Task
:app:copyReleaseBaselineProfileIntoSrc` log line names the real destination
directly.

That path tripped a second, unrelated latent bug: `.gitignore`'s `**/release`
rule (added for the real `app/release/` AGP APK-output directory) also
matched `app/src/release/`, silently swallowing the profile. Fixed with a
narrow `!app/src/release/` exception right after that rule — `app/release/`
stays ignored, `app/src/release/` doesn't.

The run also logged `No startup profile rules were generated ... because
there are no instrumentation test with baseline profile rule, which specify
includeInStartupProfile = true`. That's `BaselineProfileGenerator.collect()`'s
`includeInStartupProfile` parameter (default `false`) — an even more targeted
subset for just the startup path. Left off for now; worth an intentional
on/off decision later rather than defaulting it by accident.

`StartupBenchmark`'s two tests correctly `SKIPPED` during that run (they're
gated to the `benchmarkRelease` variant via the plugin's own manifest-injected
`enabledRules` flag; profile *collection* runs under `release`/`nonMinifiedRelease`)
— confirms the variant-gating both test classes rely on to safely coexist in
one module actually works, not just compiles.

`StartupBenchmark` itself was then run with `gradlew.bat :baselineprofile:connectedBenchmarkReleaseAndroidTest`
(and, correspondingly, `BaselineProfileGenerator.generate` `SKIPPED` this
time — the same gating in reverse). First attempt failed with `ERRORS (not
suppressed): DEVICE-MIRRORING` — Android Studio's "Running Devices" panel was
mirroring the phone's screen, which adds rendering overhead the macrobenchmark
tooling refuses to measure through, by design (there's a
`suppressErrors`/`"DEVICE-MIRRORING"` instrumentation-runner argument to force
past it, deliberately not used here since the whole point is accurate
numbers, not a green checkmark). Stopping the mirroring session and rerunning
passed cleanly. Real numbers, OPPO CPH2557 / Android 15 (API 35), 5 iterations
each, `timeToInitialDisplayMs`:

| | No profile (`CompilationMode.None()`) | With profile (`CompilationMode.Partial()`) |
|---|---|---|
| Median | 753.8 ms | 654.1 ms |
| Min – max | 715.0 – 931.8 ms | 613.0 – 708.6 ms |

**~13% faster cold start** (99.7 ms off the median). Raw data:
`baselineprofile/build/outputs/connected_android_test_additional_output/benchmarkRelease/connected/CPH2557 - 15/com.saatxi.eatapp.baselineprofile-benchmarkData.json`
(gitignored build output, not committed).

What's in the module: [`BaselineProfileGenerator.kt`](../baselineprofile/src/main/kotlin/com/saatxi/eatapp/baselineprofile/BaselineProfileGenerator.kt)
(cold start, a list fling, opening a restaurant's detail, back) and
[`StartupBenchmark.kt`](../baselineprofile/src/main/kotlin/com/saatxi/eatapp/baselineprofile/StartupBenchmark.kt)
(cold-start `StartupTimingMetric`, once with `CompilationMode.None()` and once
with `CompilationMode.Partial()`, for the before/after). `app/build.gradle.kts`
gained the `androidx.baselineprofile` plugin, `implementation(libs.androidx.profileinstaller)`
(installs the shipped profile at APK-install time) and
`baselineProfile(project(":baselineprofile"))`.

Two surprises versus the original plan, both discovered by actually running
Gradle rather than assuming:

- **Plugin version**: `androidx.baselineprofile` 1.4.1 (the latest *stable*
  release at the time) fails applying to `:app` on this project's AGP 9.3.2
  with `Module :app is not a supported android module` — 1.4.1 predates AGP 9
  and can't recognize its extension types. `1.5.0-rc02` (the newest available,
  matching AGP 9.3.2's own recency) applies cleanly. Worth re-checking for a
  stable 1.5.x once one ships.
- **No manual "benchmark" build type needed**: older Baseline Profile
  tutorials have you hand-write a `benchmark` build type in both `:app` and
  `:baselineprofile` (`initWith(release)`, debuggable, `matchingFallbacks`).
  Doing that here produced a duplicated/ambiguous `assembleBenchmarkBenchmark`
  task — plugin 1.5.0-rc02 already auto-creates `benchmarkRelease` and
  `nonMinifiedRelease` variants on both modules by itself. The manual build
  type was removed; the plugin's defaults are what's committed.

Verified along the way: `gradlew.bat :baselineprofile:compileBenchmarkReleaseSources
:baselineprofile:compileNonMinifiedReleaseSources` (both generator and
benchmark classes compile, before a device was involved), and
`gradlew.bat test assembleDebug lint --no-daemon` — the exact command CI runs
— confirming the new module doesn't change CI's outcome:
`:baselineprofile:test` runs as a harmless no-op, and it has no `assembleDebug`
or `lint` task at all, so root-level invocation skips it silently, exactly as
planned below. `gradlew.bat :app:assembleRelease` was run twice: once before
the profile existed (accepted the plugin wiring, `compileReleaseArtProfile`
just produced an empty profile) and once after
(`app/build/intermediates/r8_art_profile/release/minifyReleaseWithR8/baseline-prof.txt`
now has 9,808 R8-remapped rules, and `app/release/baselineProfiles/{0,1}/`
carries the packaged `.dm` files) — confirming the real profile actually flows
through R8 and into the APK, not just that the plugin wiring compiles.

**Still outstanding**: commit `app/src/release/generated/baselineProfiles/baseline-prof.txt`
— currently untracked (`.gitignore`'s new exception unblocked it, but nothing
has staged/committed it yet). That's the only remaining step; the profile is
generated, verified end-to-end into a release APK, and its startup benefit is
measured.

#### The CLAUDE.md change this needed

[CLAUDE.md](../CLAUDE.md) said no emulator is ever required and that
`app/src/androidTest` is empty on purpose. Applied, in the "Tests" bullet:
unit tests (`./gradlew test`) stay 100% JVM, unchanged; instrumented tests in
the `:baselineprofile` module are now allowed, running only on demand via
`:baselineprofile:...AndroidTest` tasks (or the `:app:generateBaselineProfile`
umbrella task), never from `./gradlew test`.

CI is unaffected, confirmed above by running its exact command locally: it
runs `test`, `assembleDebug` and `lint`, none of which pull in instrumented
tests.

---

### Phase 8 — Usability and M3 Expressive · In progress

#### `ButtonGroup` and `MaterialShapes` don't exist yet on a stable BOM

Both were planned against material3's M3 Expressive surface. Checked before
writing any code: `androidx.compose.material3:material3` resolves to **1.4.0**
under `composeBom = "2026.08.00"` (confirmed via `gradlew.bat :app:dependencies
--configuration debugRuntimeClasspath`), and neither `ButtonGroup` nor
`MaterialShapes` exists in that jar — both only appear starting at
`1.5.0-alpha01` (checked against the actual `material3-android-1.4.0.aar`
classes, not just changelogs). Per Google's `maven-metadata.xml`, **1.5.0's
latest version is still `1.5.0-alpha27` — no stable release exists yet.** The
Risks section below already anticipated needing `@OptIn` for these and that
they "can change signature when the BOM moves," but not that today's stable
BOM wouldn't carry them at all.

Decision (user-confirmed): don't pull in an alpha `material3` override for
this. Substituted with stable-API equivalents that meet the same usability
goal instead of blocking the phase on it:

- **Sort** uses `SingleChoiceSegmentedButtonRow` + `SegmentedButton` — the
  same pattern `SettingsScreen.kt` already uses for theme mode — rather than
  `ButtonGroup`. Still "one tap fewer" than the `DropdownMenu` it replaces.
- **Shape morphing** on the cuisine badge is **not done**. Left out rather
  than faked with a non-`MaterialShapes` substitute; the badge stays a plain
  circle in both the row and the detail header, `sharedBounds` transition
  unchanged. Revisit once material3 ships a stable 1.5.x.

#### Pinned, collapsible filters · Done

`FilterSection` no longer lives inside the `LazyColumn` (was its first
`item`, scrolling away with the list). It's now a fixed row between the
search field and the list, gated behind the same condition the list's own
empty states already use (`!isInitialLoad && (restaurants.isNotEmpty() ||
hasActiveFilter)`) so it doesn't appear over the loading spinner or the
first-sync empty state.

The row itself is a clickable header (`FilterList` icon + "Filters" label +
count `Badge` + a chevron that rotates via `animateFloatAsState`) toggling an
`AnimatedVisibility` around the existing `FilterSection` composable — chip
content unchanged, only its container moved. `activeFilterCount` is computed
inline from `minRating`/`cuisineType` (0–2); the `Badge` only shows when it's
nonzero, and carries its own `pluralStringResource`-driven content
description (`list_filters_active_count`) separately from the visible digit,
since a bare "2" read by TalkBack right after "Filters" is not self-explanatory.
`filtersExpanded` is `rememberSaveable`, so it survives rotation.

New strings: `list_filters_title`, `list_filters_expand`,
`list_filters_collapse`, `list_filters_active_count` (plural), in both
`values/` and `values-es/`.

#### Sort via `SingleChoiceSegmentedButtonRow` · Done

Replaces the top app bar's sort `IconButton` + `DropdownMenu` entirely — the
segmented row sits fixed in the body, always visible, above the filters
header. One tap selects a sort order directly. `list_action_sort` (only ever
used as that icon's content description) is now unused and was removed from
both string files, the same way `list_action_more`/`list_action_about` were
dropped in Phase 2 when their UI went away.

#### Predictive back · Done

`android:enableOnBackInvokedCallback="true"` added to `<application>` in
`AndroidManifest.xml`. Lint flags `UnusedAttribute` for it (`minSdk` 26 <
33) — expected and harmless: the attribute is simply ignored below API 33,
which is exactly the intended graceful degradation, not a real issue.

#### Haptics · Done

Favouriting already had `HapticFeedbackType.LongPress` from Phase 3 (list and
detail toggles) — nothing to add there. Roulette had haptic feedback on the
pick *button press* (Phase 6) but not on the result actually landing,
which is what this item asked for: `RouletteScreen.kt`'s `LaunchedEffect`
now fires a second, distinct haptic once the card's flip animation
(`rotation.animateTo`) completes, marking the moment the pick settles rather
than the moment it was requested.

#### Verification

`gradlew.bat test assembleDebug lint --no-daemon` — 145 tests passing
(unchanged from Phase 7, these are UI-only changes with no new ViewModel
logic), zero new lint warnings. Lint's `UnusedResources` dropped from 4 to 3
after removing `list_action_sort`; the remaining 3 (`action_ok`,
`detail_link_website`, `detail_link_instagram`) predate this phase and are
unrelated to it — not touched.

**Still to do**: shape morphing (blocked on a stable material3 1.5.x), and
the on-device pass (pinned filters expand/collapse and the badge count on a
real device, predictive back's system gesture actually working, both
haptics distinguishable from each other on hardware).

---

### Strings

All of these were already added, in both `values/` and `values-es/` (Spanish
plurals need the extra `many` quantity, as elsewhere), back when Phases 3/5/6
were still unstarted — `lint` flagged them `UnusedResources` until the screens
below consumed them. Now that Favourites, the bottom bar and Roulette all
exist, `lint` reports zero unused resources among this list.

`nav_restaurants` · `nav_favorites` · `nav_roulette` · `nav_settings` ·
`favorites_title` · `favorites_empty_title` · `favorites_empty_body` ·
`action_add_favorite` · `action_remove_favorite` · `roulette_title` ·
`roulette_prompt` · `roulette_action_pick` · `roulette_action_again` ·
`roulette_only_favorites` · `roulette_empty_title` · `roulette_empty_body` ·
`settings_title` · `settings_section_appearance` · `settings_palette` ·
`settings_theme_mode` · `theme_mode_system|light|dark` ·
`palette_saffron|garden|indigo` · `settings_section_data` ·
`settings_section_about` · `detail_section_links` · `detail_link_website` ·
`detail_link_instagram` · `detail_link_handle_format` · `detail_link_failed`

The 24 cuisine keys were not touched.

---

### Tests

Everything stays in `app/src/test/kotlin`, JUnit4 with hand-written fakes and no
mocking library.

**Written**:

- **`ColorSchemeContrastTest`** — the most valuable one. Walks all three
  palettes × light/dark and asserts ≥4.5:1 on every `onX`/`X` and
  `onXContainer`/`XContainer` pair, plus all eight accents and `onSurface` over
  each surface tier. This is what stops the old `onSecondaryContainer` bug from
  coming back. Pure maths on `Color` values — no Compose runtime, no
  Robolectric.
- **`LinkValidationTest`** — the whitelist, with the rejection cases weighted
  more heavily than the happy path.
- **`RestaurantDatabaseReaderTest`** (extended) — a `.db` *without* the new
  columns still reads (the regression protecting the published file), with them
  the values arrive, and an unsafe value nulls the field without failing the
  file.
- **`RestaurantUiModelTest`** (updated) — `stars` out; links, `hasLinks` and
  `isFavorite` in.
- **`SettingsViewModelTest`** — palette/mode changes write through to a fake
  `UserPreferencesRepository` and land back in `uiState`; `syncNow` against a
  fake `DatabaseSyncManager` for both the success and failure paths.
- **`RestaurantListViewModelTest`** (updated) — a `FakeUserPreferencesRepository`
  joined the existing fakes; new cases cover `isFavorite` mapping onto the
  right restaurant and `onFavoriteToggle` writing through.
- **`RestaurantDetailViewModelTest`** (new) — loading/not-found/loaded states,
  `isFavorite` reflecting the stored ids, and `onFavoriteToggle` toggling this
  restaurant's own id specifically.
- **`FavoritesViewModelTest`** (new) — only favourited ids reach the state
  (each mapped with `isFavorite = true`), and un-favouriting removes a
  restaurant from the list immediately.
- **`RouletteViewModelTest`** (new) — two identically-seeded ViewModels
  (`Random(42)`) against identical data land on the same pick;  `pickCount`
  increments even when chance repeats the same restaurant; an empty candidate
  pool leaves `picked` null; `minRating` reaches the repository query;
  `favoritesOnly` narrows candidates to favourited ids; a pick that falls out
  of the pool after a filter change is cleared.

**Still to write**:

- `UserPreferencesRepositoryTest` — round-trip of palette, mode and favourite
  toggling against the real `DataStoreUserPreferencesRepository`, not just the
  in-memory fakes the ViewModel tests use.
- Consider `androidx.compose.ui:ui-test-junit4` as a **`testImplementation`**:
  `createComposeRule()` runs under Robolectric on the JVM, so composable
  coverage is possible without an emulator and without touching `androidTest` —
  the bottom bar marking the right tab, hiding on detail, and the links card
  disappearing when both fields are null.

`CuisineTest` is untouched: no cuisine keys were added or removed.

### Verification

```
gradlew.bat test                 # JVM unit tests, no emulator
gradlew.bat assembleDebug
gradlew.bat lint
gradlew.bat :app:printVersionInfo
```

Beyond that:

1. **Previews** — add a list and detail preview per palette (3 × light/dark) to
   review all three schemes at a glance in Android Studio without installing
   anything.
2. **On device** — change palette and mode in Settings and confirm they survive
   killing the app; favourite something and sync to confirm it survives; rotate
   on a tablet and see the bottom bar become a rail; open detail and confirm the
   bar disappears and the badge transition is intact.
3. **Links** — sync against the **current `.db`, without the new columns**, and
   confirm the app still loads and no links card appears. Then, with a local
   file that has them, confirm the website and `@handle` open, and that a row
   with `website = 'javascript:alert(1)'` simply draws no link.
4. **Performance** — `eatapp.composeMetrics=true` confirms `RestaurantUiModel`
   reports as `stable` and `RestaurantRow` as `skippable`; the Baseline Profile
   is generated, verified into a release APK, and measured at ~13% faster
   cold start on a real device (see Phase 7).

### Risks

- **`ButtonGroup` and `MaterialShapes`** turned out not to exist on any stable
  material3 release at all (latest stable is 1.4.0; both ship starting
  1.5.0-alpha01, and 1.5.0 has no stable release yet — see Phase 8). Sort was
  rebuilt on the stable `SingleChoiceSegmentedButtonRow` instead; shape
  morphing on the cuisine badge is deferred until 1.5.x stabilizes.
- **APK size** — Outfit adds ~110 KB. R8 already shrinks resources, and the
  font is the only heavy new one.
- **Baseline Profile** — generated, verified into a release APK, and its
  ~13% cold-start improvement measured on a real device. See Phase 7.
- **`.db` compatibility** — the new columns are optional on purpose, so the
  currently published file keeps validating untouched.

---

## Appendix B: Visual redesign proposal audit (second-pass audit)

*UI audit & proposal · EatApp · Compose / Material 3 · 2026-09-04.*

Originally a standalone, self-contained Spanish-language HTML mockup
(`visual-redesign-proposal.html`) with styled before/after phone
comparisons. Folded in here as text: the audit findings and roadmap below
are a faithful English translation of its written content; the rendered
mockup visuals themselves aren't reproduced, since they don't carry over to
plain text and every improvement they illustrate was implemented as F-55,
F-56, and F-58 through F-66 in the **Done** section above.

**De formulario de fichas a libreta de restaurantes con ganas de abrirse —**
"From spec-sheet form to a restaurant notebook worth opening": EatApp
already has a solid foundation — its own tonal palettes, variable Outfit
typography, shared-element transitions between list and detail, and a
roulette with a 3D spin animation. What it's missing isn't system — it's
warmth: no screen shows a photo, and what it can record about a place falls
short of what people actually remember about a restaurant.

Stats at a glance: 7 screens audited · 24 cuisine types, 0 photos · 3 tonal
palettes already built · 8 improvements proposed up front (the roadmap
below grew to 14 once broken out by group).

### What already works

Before touching anything: this is a better-than-usual foundation, worth
keeping rather than replacing.

- **Its own color system** — 3 hand-built tonal palettes (Saffron, Garden,
  Indigo) with full light/dark support — not generic Material You.
- **Cuisine identity** — 24 icons + 8 color accents spread across the
  screen without repeating — the circular badge already works as a visual
  signature.
- **List → detail transition** — The cuisine badge travels via a
  shared-element transition up into the detail screen's top bar. An
  expensive detail to get right.
- **The roulette moment** — A 3D spin via `graphicsLayer` plus haptic
  feedback on landing. The only screen that already aims to delight, not
  just list.

### Where the gap shows

Six concrete frictions found while walking through list, detail, edit,
favorites, roulette, importing and settings.

- **LIST · DETAIL · ROULETTE — Zero photos anywhere in the app.** Every
  restaurant is a cutlery icon in a colored circle. For a notebook of
  places to eat, the photo is the single most memorable piece of data —
  and it doesn't exist anywhere yet.
- **DATA MODEL — No notes or status.** No way to jot down "order the
  lobster" or mark "want to try" vs. "already visited". The model only
  stores name, cuisine, rating, price, website and Instagram.
- **SETTINGS — The flattest screen in the app.** Colored section headers
  with no cards, no per-row icons — a contrast with the detail and roulette
  screens, which are polished.
- **EDIT/ADD — Ungrouped form.** Eight fields in a single column with no
  sections; the cuisine dropdown also loses the icons the filter chips
  already have.
- **FAVORITES — Neither search nor filters.** Reuses the list screen's row
  but not its capabilities — an inconsistency between two screens showing
  the same kind of content.
- **IMPORTING — Doesn't use the rest of the app's visual language.**
  Import-candidate rows are plain text — no badge, no cuisine icon, the
  only screen breaking the pattern.

### List: from icon to photo

Same cuisine badge kept as a fallback, but the photo becomes the primary
element — and each row shows at a glance whether the place has been
visited or is still pending.

- *Before:* badge + text. Three rows of identical height and shape —
  nothing distinguishes one place from another besides the cuisine color.
- *Proposed:* photo + status + tags. The cuisine badge doesn't disappear —
  it shrinks to a stamp over the photo, and visited/want-to-try status
  reads without opening the record.

### Detail: the header gets a face

The large top bar already tints with the cuisine's color; the proposal is
for that color to live behind a photo instead of a flat background, with
notes and tags appearing too.

- *Before:* the cuisine color paints a flat bar. No photo, no notes — three
  text-only cards.
- *Proposed:* a real photo as the header, notes and tags underneath. The
  cuisine icon becomes a stamp over the photo instead of tinting the whole
  bar.

### Settings: from text list to panel

Same information, grouped into cards — consistent with how the detail
screen is already grouped.

- *Before:* colored section headers with no card or icons — the screen
  feels like an unstyled default.
- *Proposed:* each section becomes one card with an icon; adds an entry
  point to a statistics screen (see roadmap).

### Roadmap

Fourteen improvements grouped by type, with perceived impact and estimated
effort given the stack at the time (Compose + Material 3, local Room, no
network).

**New data**

- *Per-restaurant photos* (impact: high, effort: medium) — System photo
  picker (Android Photo Picker) — no storage permission needed. Save the
  path in Room, copy into the app's internal storage.
- *Free-form notes* (impact: high, effort: low) — A long text field
  ("what to order", "who to go with"). A new column on `Restaurant` and a
  multiline `OutlinedTextField` in the form.
- *Status: want to try / visited* (impact: high, effort: low) — Today
  everything is stored as if it's already been visited. A simple enum
  enables the most-requested filter in place-list apps.
- *Free-form tags* (impact: medium, effort: medium) — "terrace", "good for
  groups", "bring kids" — a dedicated tags table plus an N:N relation,
  reusing the `FilterChip` pattern already built for cuisine.

**Consistency across screens**

- *Search and filter in Favorites* (impact: medium, effort: low) — Reuse
  the list screen's own search bar and chips — today Favorites is the only
  list-shaped screen without them.
- *Cuisine badge in Import* (impact: medium, effort: low) — Import
  candidate rows are plain text — add the same circular badge list, detail
  and roulette already use.
- *Sectioned add/edit form* (impact: medium, effort: low) — Group into
  "Basics" / "Rating" / "Links" cards, the way detail already is grouped —
  and bring the icons back to the cuisine dropdown.
- *Shared price + stars component* (impact: medium, effort: low) — Today
  it's copy-pasted across list, detail and roulette. One
  `RatingAndPriceRow` reduces the risk of the three drifting apart.

**Interaction**

- *Swipe to favorite / delete* (impact: medium, effort: medium) —
  Material 3's `SwipeToDismissBox` over `RestaurantRow` — a quick action
  without opening detail.
- *Skeleton-style loading states* (impact: medium, effort: low) — Replace
  the centered spinner with placeholders shaped like the real rows — feels
  faster even at the same actual load time.
- *Search with suggestions* (impact: medium, effort: low) — With an empty
  query, show frequent cuisines or "top 3 rated" instead of a blank box.

**New functionality**

- *Statistics screen* (impact: high, effort: medium) — Most common
  cuisines, average rating, price spread — all aggregated locally with
  Room, no network dependency.
- *Home-screen widget* (impact: medium, effort: high) — A Glance widget
  showing the latest roulette pick or the next "want to try" place without
  opening the app.

Fits the project's constraints: pure Kotlin + Compose, Material 3 (no new
network dependencies — the system photo picker and Room are enough), 100%
local persistence. The statistics screen and the visited/want-to-try status
were called out as the two highest-impact, lowest-effort items to start
with.

*Design proposal · did not itself implement any code changes · 2026-09-04.*
