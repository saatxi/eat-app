# Overhaul plan

The plan for the 2026 overhaul: drop iOS, upgrade the toolchain, move to
Riverpod and go_router, redesign the app, and add a stored wishlist status and
a first-run onboarding. The work happens on the `overhaul` branch, one commit
per phase. Every commit passes `flutter analyze` and `flutter test`, and ticks
its own line in the checklist below.

## Status

- [x] Phase 0 — Put this plan in the repo
- [ ] Phase 1 — Design mockup (approval gate)
- [ ] Phase 2 — Remove iOS and purge what isn't needed
- [ ] Phase 3 — Upgrade dependencies, SDK and toolchain
- [ ] Phase 4 — Structural refactor (behaviour unchanged)
- [ ] Phase 5 — Riverpod for state and dependency injection
- [ ] Phase 6 — go_router
- [ ] Phase 7 — Visual redesign
- [ ] Phase 8 — Wishlist and status
- [ ] Phase 9 — Onboarding and docs

## Why

The app works, but it has grown by hand:

- ChangeNotifier controllers are wired through an `InheritedWidget`
  (`lib/app/app_scope.dart`).
- `main.dart` hand-builds every object.
- Navigation is imperative `Navigator.push` from a large `HomeShell`.
- Several files run to 500–1100 lines (`restaurant_repository.dart` is the
  biggest).
- The Terracota/Lora/Nunito identity is text-led, while most restaurants have
  no photo, so users mostly see small cuisine badges.
- "Want to try" is not stored; it only means "no visits yet".
- There is no onboarding.
- README.md and AGENTS.md are stale (roulette, tags, a deleted `docs/`).

iOS is dropped: without the paid Apple Developer Program the app can't be
distributed to iPhones, the widget's App Group never works on a free account,
and the project is built on Windows, so the iOS half can never be built or
verified. It stays in git history, and `flutter create --platforms=ios .`
regenerates the runner if it's ever needed again.

## Phase 1 — Design mockup

An HTML mockup, approved before any Flutter design work starts: palette, type
scale, and the Journal (standard and compact), Detail, Stats and Onboarding
screens, in light and dark, at phone width.

The proposed direction, "Paprika", sits between vibrant/playful and premium:

- **Palette**: a saturated paprika red-orange primary (dark enough for white
  text to clear AA), a saffron secondary with a dark on-colour, a deep
  aubergine tertiary, warm ivory light neutrals and an espresso near-black dark
  mode, plus eight more saturated cuisine accents.
- **Type**: Fraunces (variable) for display, headline and `titleLarge`; Plus
  Jakarta Sans (variable) for body and labels. Both OFL and bundled.
- **Shape and motion**: Material 3 Expressive radii, pill buttons, squircle
  thumbnails; the `AppMotion` tokens and `PressableScale` actually used.
- **Journal**: photo-led cards — a 16:10 cover with a scrim and the title
  overlaid. The cover falls back from the restaurant photo to the latest visit
  photo to generated cuisine art (an accent gradient with a large cuisine-icon
  motif). Compact density stays a dense row list.
- **Detail**: a large collapsing hero, a status chip and priority flag, and an
  extended "Log a visit" FAB.
- **Stats**: a bento grid of tiles.

## Phase 2 — Remove iOS and purge what isn't needed

- Delete `ios/`, the iOS-only Dart in `lib/widget/home_widget_service.dart` and
  `main.dart` (App Group id, iOS widget kind), the iOS wording in doc comments,
  `test/core/theme/page_transitions_test.dart`, the iOS outputs of
  `scripts/generate_app_icons.dart`, and the `ios` entry in `.metadata`.
- Delete dead code: `features/groups/group_settings_section.dart`,
  `AppScope.sync`, `core/theme/theme_gallery.dart`, the roulette ARB keys and
  any other unused ARB key, and the unused `tabularFigures` token.
- Drop the unused `public.group_tags` table with a Supabase migration.
- Drop any unused direct dependency.
- Remove iOS from README.md and AGENTS.md.

## Phase 3 — Upgrade dependencies, SDK and toolchain

- Bump every direct dependency, loosen the unexplained exact pins
  (`sqlite3`, `drift_flutter`), raise the SDK constraint.
- Try AGP 9's `builtInKotlin`/`newDsl` defaults; keep them only if every
  plugin builds.
- CI: pin the Flutter version, fetch full history, cache pub, and add a
  `flutter build apk --debug` job (the only check of the Kotlin widget).
- Enable a few more lints and fix what they flag.

## Phase 4 — Structural refactor

Behaviour unchanged; smaller seams so the Riverpod migration touches less at
once.

- Split `RestaurantRepository` into restaurant, visit, photo, group-membership
  and stats repositories, an exporter, and a shared `WriteEffects`
  collaborator; split its tests to match; drop the test-only methods.
- Split `SyncEngine` into a pusher, a puller and photo blob sync.
- Split the large screens into per-feature `widgets/` folders; move
  `RestaurantListUiState` into its own file; merge the duplicated section
  label; give Settings' account card a controller.
- Move the one hardcoded UI string into the ARB files; merge the three copies
  of the fake group gateway in `test/`.

## Phase 5 — Riverpod

- `flutter_riverpod` with `riverpod_generator`. Root providers in
  `lib/app/providers.dart` replace `AppScope` and the hand wiring in
  `main.dart`; the providers are the dependency injection.
- Every controller becomes a notifier, keeping its immutable `*UiState`.
- The home-widget background isolate builds its own `ProviderContainer`.
- Tests share one `test/helpers/pump_app.dart` with provider overrides.

## Phase 6 — go_router

- A `StatefulShellRoute` with Journal, Groups (only with a backend) and
  Settings branches; restaurant, edit, visit, stats, import, join, members,
  invite and onboarding routes.
- The two-pane layout above 840 px stays, with the Hero pairing intact.
- Share intents, `eatapp://join/…` links and widget clicks navigate through the
  router.

## Phase 7 — Visual redesign

- New palette, typography (Fraunces, Plus Jakarta Sans), radii and component
  themes; the palette supplies its own on-colours.
- Hardcoded colours, radii, text styles and durations replaced by tokens.
- New shared `RestaurantCover`, status chip and stat tile; every screen rebuilt
  to the approved mockup.
- Android widget (with a dark variant), launcher icon and splash colours kept
  in step.
- Contrast, theme and text-scale tests updated and extended.

## Phase 8 — Wishlist and status

- Schema 19 adds `restaurants.status` (`want_to_try`, `visited`,
  `wont_return`, `closed`) and `restaurants.priority` (0–2), backfilling the
  status from whether visits exist; a migration test drives the step.
- Logging a visit promotes `want_to_try` to `visited`; the home widget skips
  `closed` and `wont_return`; the Journal gains a status filter and sorts by
  priority, last visited and most visited.
- The two columns sync through a new Supabase migration and the sync mapper,
  and travel in a new `eatapp.restaurants.v4` share format (v3, v2 and
  `eatapp.group.v1` still import, with a derived status).

## Phase 9 — Onboarding and docs

- A three-page first-run flow, shown once; installs that already hold data
  skip it.
- README.md and AGENTS.md brought up to date with everything above.

## Verification

Every phase runs `flutter analyze`, `flutter test` and
`flutter build apk --debug`, plus `dart run build_runner build` when generated
code changes and `npx markdownlint-cli2` when docs change. From Phase 5 on, the
app is also exercised on an Android device or emulator. Supabase migrations are
checked against a local project with `rls_smoke_test.sql` when the Supabase CLI
is available; deploying them to the live project is a separate decision.
