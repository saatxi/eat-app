# Changelog

All notable changes to EatApp are documented here, one entry per release
tag, newest first. Loosely follows the spirit of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); entries are
derived from this repo's annotated git tag messages (`git tag -l -n99`)
rather than hand-maintained separately, so the wording matches what was
tagged at release time. Versioning follows the `vMAJOR.MINOR.PATCH` scheme
described in [README.md](README.md#versioning) — `versionName`/`versionCode`
are always derived from git, never hand-edited.

## [4.2.0] - 2026-10-09

Let past visits be edited and stop a cleared field reverting

- A visit was write-once: a wrong date or a note typed in haste could only
  be undone by wiping the restaurant's whole history, so the visit form now
  opens on an existing visit as well as a new one, reusing the create/edit
  split the restaurant form already had rather than growing a second screen
  beside it
- Editing covers the photos too, which is why the form distinguishes a
  stored photo from a just-picked one — the first is kept or dropped by id,
  the second is a temporary file still to be persisted — and why a shared
  visit's dropped photo is tombstoned and queued like any other shared
  delete instead of vanishing for the other members
- Deleting a single visit finally has an interface: the repository could
  already do it, but nothing in the app called it, so a mistaken entry had
  no way out short of deleting the restaurant
- Both DAOs wrote an updated row as a data class, which drift converts with
  nullToAbsent, so any column the caller had nulled was dropped from the
  UPDATE and silently kept its old value — clearing a restaurant's address,
  city, website or Instagram never saved, a cleared visit note came back,
  and a restaurant taken out of its last group stayed pointed at it
- The edit form's "Add photo" and "Remove photo" buttons overflowed a 360dp
  phone by 429 pixels in Catalan, cutting the second label off, so the
  destructive action moved onto the photo preview as an icon; the rule
  behind it is now written down, since this was the third screen to hit it
- The accessibility suite lays the edit form out in Catalan on a narrow view
  at 1.3x and 2.0x text, because the overflow was locale-dependent and
  nothing in the existing cases would ever have caught it
- Documentation for the iOS widget, the old sign-in process, the
  account-code identity and the groups redesign is removed now that all four
  have shipped and the plans no longer describe the code

## [4.1.1] - 2026-10-08

Refresh the journal UI, remove Roulette, and add system theme mode

- Removing the Roulette simplified the navigation shell and cut a screen
  that was never the right way to pick a restaurant
- The system/auto theme mode was intentionally absent (see the old
  doc-comment) but enough users expect it that reopening the decision is
  warranted
- A cuisine-tinted gradient header for photo-less restaurants gives every
  detail screen a visual identity without requiring a photo
- Moving the filter controls into a bottom sheet frees the list's vertical
  space and hides complexity until it is asked for
- The collapsible Journal title and a larger card thumbnail push the visual
  language toward the bolder direction the design intended
- Selective shadows on the detail header and the Stats total tile introduce
  hierarchy without flattening the whole surface palette
- The import confirm button was pinned to the absolute bottom of the screen,
  leaving a large empty gap when all candidates were duplicates; it now
  follows the content
- CI, global error capture and strict analyzer language flags harden the
  project against regressions going forward

## [4.1.0] - 2026-10-03

Swap the emailed sign-in for a device account code and add a Delete profile
flow

- The emailed one-time code needed a Supabase template and an SMTP sender,
  and gotrue's default PKCE flow made signInWithOtp throw before any request
  left the device so sign-in silently did nothing; an account the app mints
  itself removes the whole email path
- Adoption derives a synthetic email and password from the code with two
  server-held HMAC secrets and signs in with the ordinary password grant, so
  the session stays a real one, multi-device keeps working, and no session
  has to be minted server-side
- The code is a bearer secret, so it travels only inside a dedicated account
  backup and never in the shareable restaurant export, or sharing a
  restaurant would hand over the whole account
- Removing an auth user needs the service role and is blocked by the
  created_by foreign keys on the shared tables, so a delete-account Edge
  Function clears those rows through delete_account_data before deleting the
  user, and Delete profile sits behind a confirmation dialog that spells out
  the irreversible loss
- The account section is now a single signed-in line with the Delete profile
  action and a one-tap create-account button, since the code is never shown
  or typed; recovering it on another phone goes through an account backup
- Creating a group while signed out points the user to Settings instead of
  opening a name dialog that could not succeed
- Shared with becomes a multi-select dropdown, so a restaurant can be shared
  into several groups without a row of chips that crowded the form as the
  group count grew

## [4.0.0] - 2026-10-02

Ship multi-group sharing with email sign-in

- A restaurant can now belong to several groups at once, chosen where it is
  added or edited, instead of being pinned to a single list
- Membership moves to its own table with owner, editor and reader roles, so
  read-only access can be granted without also handing over the ability to
  write
- An emailed one-time code replaces the anonymous identity, so an account,
  its groups and their restaurants come back after a reinstall or on a new
  phone, and the flow behaves the same on Android and iOS
- Share files move to the eatapp.restaurants.v3 format and gain a
  whole-group export, while ownership and roles stay on the server and never
  travel in a file
- The shared-groups schema migration is applied, the local database moves to
  schema 18, and the RLS smoke test now drives an owner, an editor, a reader
  and a stranger through every table

## [3.5.6] - 2026-09-29

Tidy the shared-groups backend and pin down the local schema's migrations

- Collapse the twelve shared-groups migrations into one initial schema,
  since the backend is pre-production and the chain recorded the path the
  schema took while it was being built rather than its final shape, folding
  every superseded intermediate step into its final form
- Fold the member roster into a security_invoker view so the members screen
  reads it in one round-trip instead of hitting PostgREST twice, while the
  caller's row-level security still decides what it may see
- Merge the invite and join rate limits onto one rate_attempts table and one
  record_rate_attempt RPC, and share the Edge Functions' json and client
  boilerplate, so the two flows stop carrying a copy of the same
  sliding-window logic
- Make the invite token use rejection sampling rather than a modulo over
  random bytes, which had made the first few alphabet characters slightly
  likelier than the rest
- Test the 14-to-15 drift migration and rewrite the note that claimed the
  local schema had no migration path, so the documented version history
  matches the real 14-to-17 onUpgrade steps
- Drop the leftover refactoring plan documents and unused configuration, none
  of which any build or tool reads

## [3.5.5] - 2026-09-29

Push group changes live and clean up a deleted group's data

- Attribute a shared write's group through a new onSharedWrite hook on the
  repository and push it the moment it lands, so a restaurant added in a
  group reaches the other members without a manual sync or a restart, which
  is why it had only appeared after the app was reopened
- Coalesce overlapping sync runs in SyncService, because the auto-push, a
  poll tick and a manual tap can land together and the engine is not
  re-entrant, and poll the selected group on a timer so the rest of the
  group's changes arrive without a tap while the sync button still gives an
  immediate pull
- Purge a group's local rows, pending-sync queue and cursor when it is
  deleted or left, and drop a selection that no longer names a group, so a
  dissolved group can no longer show its restaurants under Personal or keep
  the sync button on
- Hide the Change your name row while the user belongs to no groups, since a
  display name means nothing outside one

## [3.5.4] - 2026-09-29

Sync shared groups on resume and on demand, remove the non-clickable
join-link share, and raise the owner-group cap to ten

- Pull the selected group whenever the app returns from the background and
  when the Journal or Roulette is opened, not only on a cold start, because
  that is the moment the rows are most likely to have gone stale
- Add a sync button to the Journal's app bar that shows the pull in progress
  and becomes a retry with a snackbar on failure, so a member no longer has
  to guess at a gesture or be left with a silent no-op
- Stop a failed push from skipping the pull that follows it, which would
  otherwise freeze every future pull behind one row the server keeps
  refusing, skip a photo binary that cannot be downloaded rather than
  aborting the whole pull, and log a failed sync with its cause instead of
  failing silently
- Remove the invite screen's Share link action: the eatapp:// custom scheme
  is never linkified by messaging apps, so the shared link arrived as dead
  plain text and cannot be made clickable without an App Link the project
  does not have, while the QR and the hand-copyable short code stay for
  in-person and remote invites
- Raise the owner-group cap from 2 to 10 through a new migration over
  private.app_settings, leaving plain membership unlimited, and make the RLS
  smoke test derive the cap instead of hardcoding it

## [3.5.3] - 2026-09-28

Fix invite tokens so a scanned QR, a typed code and a shared link all join
again

- The client pinned the invitation token at 32 characters while the
  create-invite Edge Function has always minted 16 (128 bits, one character
  per byte), so every join path rejected the token as malformed and never
  reached the server: the scanner read the QR but dropped the payload,
  manual entry reported the code as invalid, and an eatapp://join/<token>
  deep link arriving from Mail or WhatsApp was silently ignored
- Align the client contract to the server's real shape instead of changing
  the backend, so invitations already minted work without redeploying the
  function, and update the token fixtures in invite_link_test and
  invite_join_controller_test to the 16-character shape

## [3.5.2] - 2026-09-28

Finish the shared-groups workflow: a dedicated Groups tab, an ownership cap
and a group that dissolves with its last member

- Move group management out of Settings and into a dedicated Groups tab in
  the bottom navigation — shown only when the backend is compiled in — with
  full create, rename, invite, expel and leave flows, plus 10-second
  timeouts on the identity and group-list calls so an unreachable backend
  surfaces a message instead of an infinite spinner
- Restore the group's name editor and add a Change your name entry to the
  groups menu, so a member sets the display name their roster row shows
  without leaving the list
- Cap how many groups a user may own at owner_group_limit in
  private.app_settings, default 2, while leaving plain membership unlimited;
  the group_members_owner_cap trigger enforces the cap inside the atomic
  create_owned_group RPC so a refused ownership rolls the fresh group back,
  and the app reads the limit through the owner_group_limit() RPC, disables
  the create button and shows a dedicated message once it is reached
- Dissolve a group when its last member leaves, via the
  group_members_dissolve_when_empty trigger that the v3.5.0 release never
  deployed, and drop the dissolved group from the shared roster after a
  leave
- Extend the RLS smoke test with an owner-cap section and run it over the
  Management API, and make member names in the roster purely informational
  as the rename stays on the groups list
- Document the Windows multiline commit trap in AGENTS.md and add the MCP
  workspace configuration

## [3.5.1] - 2026-09-28

Fix the shared groups' rough edges and a handful of smaller issues

- Creating a group did nothing and said nothing, because a device that had
  already signed in never handed its stored session to the client; the stored
  session now seeds the client, and a failure reaches the screen as a message
  instead of silence
- Keep the create-group dialog's text controller alive until the dialog itself
  is torn down, rather than disposing it the moment the caller resumes, which
  the framework rejected as a build in the wrong scope during the exit
  transition
- No group's member list ever loaded: the roster embedded profiles in
  group_members, but both tables key off auth.users rather than each other, so
  PostgREST refused the embed — the two are now fetched separately and joined
- A fresh anonymous account has no display name, so the roster listed a bare
  user id; a member can now set their own name from their row, written to
  profiles.display_name
- The group scope was a chip row over the journal that could strand the user on
  Personal with no way back; it is now one labelled drop-down in the app bar of
  the journal, the roulette and the statistics, naming the scope in force and
  keeping every group reachable from wherever you are
- Group management — creating a group, joining one and seeing its members —
  moved out of the journal and into Settings, so the journal's app bar dropped
  its statistics and share actions, both already offered in Settings
- The launcher now shows EatApp rather than the package name it had been
  shipping as
- The detail header shows the restaurant's name where the cuisine badge used to
  sit, so a long name is no longer truncated beside it, and the roulette card
  shows a compact region-and-country line instead of the whole address
- Sharing a restaurant carries its favourite mark now, and importing restores it

## [3.5.0] - 2026-09-27

Add shared groups: a synced, group-scoped restaurant list with invitations

- Add the shared-groups backend — a Supabase schema with Row Level Security,
  the two Edge Functions that mint and redeem invitations, and the private
  Storage bucket photos travel through — wired so the whole feature stays
  dormant unless the build carries SUPABASE_URL and SUPABASE_ANON_KEY, leaving
  personal mode fully offline
- Bump the drift schema to 17 with real, purely additive migrations: 16 added
  the sync metadata (groupId, createdBy, updatedAt, deletedAt) to every shared
  table and 17 added the pending-change queue and the per-group pull cursor, so
  existing rows stay private without a backfill
- Add the sync layer: an anonymous Supabase identity, a queue of pending
  changes and per-group pull cursors, a SyncEngine over a transport abstraction
  with its Supabase implementation, soft deletes that travel as tombstones, and
  photo binaries carried through Storage
- Scope every read to the selected group behind a selector over the journal,
  so the list, the statistics, the roulette and the home-screen widget all
  follow the chosen group, and attribute every shared write to whoever made it
- Add group management: create a group, see its members, expel someone or
  leave, and follow the sync state from the journal
- Add invitations: an owner shows a QR drawn with qr_flutter, the joining side
  scans it with mobile_scanner or types the short code, and app_links delivers
  the eatapp://join/… deep link — the scanner is the app's only camera user and
  the manifest's single permission
- Harden the backend: rate-limit both minting and redeeming invitations, keep
  every non-empty group with at least one owner by refusing the last owner's
  leave and offering dissolution instead, verify every policy with the
  owner/member/stranger RLS test, and let a group's data be exported before it
  is left or dissolved
- Compile the backend configuration through the release build — bundle.ps1
  resolves SUPABASE_URL and SUPABASE_ANON_KEY like the signing keys — and add a
  gitignored dart_defines.json plus launch configurations so a debug run can
  switch the backend on without editing code

## [3.3.0] - 2026-09-27

Redesign the app as a warm humanist journal and drop the tag feature

- Rebuild the UI around a new terracotta, olive and berry palette that
  replaces the verd scheme, with its own radius and motion tokens and the
  Lora and Nunito fonts, and rebuild the theme assembly and every shared
  widget on top of it
- Make the journal the app's main surface under a Restaurants / Roulette /
  Settings bottom bar, with a prominent search, the visited / want-to-try /
  favourites segments folded into a dropdown chip, and the add action moved
  into the app bar
- Migrate every screen — restaurants, detail, add/edit, log-visit, roulette,
  statistics, settings and the import review — onto the new design system
- Give the restaurants filters a region and country dropdown, hide the
  location dimensions that have no values, and give the roulette the same
  filter set behind a collapsible Filtres header
- Re-skin the home-screen widget's Android resources and iOS extension to
  match the new palette
- Remove the tag feature end to end: drop the tags and restaurant_tags
  tables and bump the drift schema to 15 with a real migration, take tags
  out of the repository, the UI models, the share format and every screen,
  and drop the column from the CSV converter
- Tolerate a leading UTF-8 BOM when importing a share file, and space the
  rating apart from the price pill

## [3.2.0] - 2026-09-26

Redesign the app's appearance around a single verd colour scheme

- Replace the three selectable palettes and their picker with one hand-tuned
  verd scheme — a forest primary, a citrus secondary and a berry tertiary
  over leaf-tinted neutrals — so the app reads as a single identity rather
  than three variants of itself
- Keep only the light/dark toggle, drop the palette names from the ARB files
  and the pickers from Settings and the dev gallery, and treat a stale stored
  palette id as ignored rather than throwing so an upgrade from the previous
  build cannot crash on startup
- Add the redesign's motion: a spring press on the add button and the
  roulette reveal, a reveal that settles instead of popping, a count-up on
  the statistics tiles, and a leaf-to-citrus wash behind the list header
- Stand every new animation down when the platform asks for reduced motion,
  and keep each one-shot so it always settles rather than holding a frame
  source open
- Hold the accessibility line for the new scheme, with the light and dark
  on-colours and the eight cuisine accents clearing WCAG AA in
  color_contrast_test and the 2× dynamic-type and semantics tests kept green
- Add the Java null-analysis mode to the workspace's editor settings

## [3.1.0] - 2026-09-26

Add the home-screen widget, restore the app's own icon and splash, and fix
the screens' rough edges

- Add the home-screen widget on both platforms: a Kotlin AppWidgetProvider
  with its layout for Android, a WidgetKit extension for iOS, and the
  restaurant, the language and every string it shows decided in Dart
- Make the shell adapt at 840 logical pixels — a bottom bar below that, a
  NavigationRail with the detail beside the list above it — and add motion,
  empty states and paired hero images to the list and the detail
- Follow each platform's own behaviour instead of restating it (iOS keeps the
  framework's edge swipe-back) and support large system text rather than
  clamping it
- Restore the launcher icon and splash screen the rewrite had left as
  templates: one fork-and-knife artwork living in the Android vectors, with
  every raster Android below 26 and iOS need generated from them
- Show the app's own version in Settings again, read back off the platform so
  it cannot disagree with the build it is running in
- Fix the rough edges: a rating trend chart that painted nothing, a language
  picker that was a four-row list, a bottom bar carrying labels, a filter
  panel with no way to clear it, a visits action floating over the visits it
  was about, and a roulette reveal that was clipped — it is scaled to fit
  now, with its filters wrapping instead of running off the edge
- Widget-test the four screens that had none, cover the photo pipeline and
  the filter bundle, and drop the migration planning docs that had outlived
  their job

## [3.0.1] - 2026-09-26

Add sharing, importing and photos to the Flutter app

- Add the share sheet and the export options dialog, so one restaurant or the
  whole list can be sent as an .eatapp file
- Add the import review screen, which lists a shared file's restaurants,
  flags likely duplicates against the current list and writes nothing until
  the user confirms
- Add photo storage and picking: copy each picked image into the app's own
  store with its EXIF orientation baked in and its longest side bounded,
  delete the file whenever its row goes, and show the photo on the list,
  roulette, detail and edit screens
- Carry a visit's photos onto the log-visit form and the detail timeline
- Trim the release bundle by obfuscating Dart, dropping the x86_64 ABI and
  archiving the Dart symbols
- Fix the CSV helper's stale price scale and a dead Gradle path left over
  from the native build
- Remove the legacy native Android app and the last Claude Code-specific
  directory now that the Flutter rewrite is the only codebase
- Silence JEP 472 native-access warnings by setting GRADLE_OPTS

## [3.0.0] - 2026-09-25

Rewrite EatApp in Flutter

- Add a complete Flutter implementation at the repository root, keeping the
  same applicationId, git-derived versioning and release keystore as the app
  it replaces
- Port the data layer to drift (schema, DAOs and search helpers) and add a
  Room-to-drift importer so existing installs migrate their restaurants
- Rebuild the localization layer for English, Spanish and Catalan from ARB
  files with flutter gen-l10n
- Recreate the theme and design-token layer (palettes, typography, spacing,
  radii and cuisine accents) with the bundled Manrope and Newsreader fonts
- Port every screen: restaurant list with search and filters, add/edit form,
  detail with visit history, favourites, log-visit, statistics, roulette and
  settings
- Extract the shared presentation widgets and the list model, filters and
  controller those screens build on
- Re-implement the .eatapp share format, its reader and writer, and the
  on-device backup snapshot
- Move git-tag versioning and release signing into the Flutter Android module
  and make scripts/bundle.ps1 build the signed bundle with flutter build
  appbundle
- Pin local builds and the VS Code Java extension to Temurin 21, fix UTF-8
  reading of .eatapp files, and drop the CI workflow configuration

## [2.6.1] - 2026-09-24

Include visits in restaurant exports and fix the average-rating label
wrapping

- Add an "Include visits" switch to every export path (share from Detail,
  "share all" from List, "export my data" from Settings), backed by
  RestaurantRepository.exportRestaurants so all three agree on what a file
  contains; the detail screen's single share now carries the real visit
  history instead of only the latest visit
- Name a single restaurant's export file after the restaurant
  (cal-ferran-20260924_1246.eatapp) while bulk exports keep
  restaurants-YYYYMMDD_HHmm.eatapp
- Shorten the average-rating stat tile label so it no longer wraps onto two
  lines on narrow phones or larger font scales, keeping it level with the
  other tiles
- Bump the minor-and-patch dependency group with 10 updates

## [2.6.0] - 2026-09-13

Collapsible price range filtering and a clearer import review screen

- Revert the Google Maps share-link import added in v2.5.4: the
  redirect-resolution approach proved unreliable in practice
- Collapse already-imported restaurants into their own section on the import
  review screen instead of interleaving them with new ones
- Add a price range filter to the restaurant list and collapse the filter
  chips into dropdowns to make room for it
- Replace the "$"-tier price range with six euro-band tiers for finer-grained
  filtering and display

## [2.5.4] - 2026-09-13

Add importing a restaurant from a Google Maps share link

- Resolve a share.google/maps.app.goo.gl link's redirect chain to recover a
  place name, the app's one deliberate exception to its zero-network design,
  scoped to an allowlist of Google Maps hosts with no API key and silent
  fallback on failure
- Add a share-sheet entry point so EatApp can receive a shared Google Maps
  link directly, and an "Import from a link" button on the add-restaurant
  screen for pasting one manually

## [2.5.3] - 2026-09-13

Add an in-app help screen explaining how to use EatApp

- Add a "How to use EatApp" screen, reached from Settings, covering adding a
  restaurant, favorites vs. want-to-try, the roulette picker, sharing a
  restaurant, the home-screen widget, and exporting your data

## [2.5.2] - 2026-09-13

Fix restaurant import/export bugs found after the CSV converter release

- Always write the format field when exporting or backing up restaurants, so
  exported files show their actual on-disk format
- Retry reading a shared file's content Uri up to three times before giving
  up, so opening a Gmail attachment right after receiving it no longer fails
  with a false "can't read this file" error
- Don't let a missing street address block duplicate detection on import, so
  a restaurant already in the list is flagged instead of silently duplicated
- Timestamp the exported restaurant file's name
  (restaurants-YYYYMMDD_HHmm.eatapp) instead of reusing a fixed name
- Fix the three-way import decision buttons overflowing on long translations
  like "Reemplaça"

## [2.5.1] - 2026-09-12

Stop wiping user data on app updates with a schema version bump

- Fix destructive Room migrations silently wiping user data on schema version
  bumps; only a downgrade still falls back destructively
- Replace csv-to-eatapp.ps1 with a bidirectional eatapp/CSV converter matching
  the current v2 share schema

## [2.5.0] - 2026-09-12

Multi-visit restaurant model with photo carousel, rating trends, and a
visual refresh

- Split Restaurant into Restaurant/Visit/Photo with UUID ids, enabling
  multiple logged visits per restaurant
- Build the real visit-timeline UI and log-visit flow, and simplify Edit to
  place-level data
- Replace the single restaurant photo with a multi-photo carousel in Edit
- Add a per-visit price range and extract a shared PriceRangePicker
- Add a per-restaurant rating trend and a global average-rating trend to
  Statistics
- Replace the manual ViewModel factory with Hilt dependency injection
- Replace the default palette and type scale with the approved "mercado
  fresco" visual identity

## [2.4.3] - 2026-09-11

Add structured address (street, town, region, country) and a combined
location filter

- Simplify the Settings export row's label
- Update SingleChoiceSegmentedButtonRow modifier to fill max width for better
  layout
- Bump the minor-and-patch dependency group with 2 updates

## [2.4.2] - 2026-09-06

Fix stale detail dialogs on restaurant switch, wrong Roulette price-chip
colors, missing accessibility landmarks, and layout bugs; show a clean version
in Settings

- Fix the detail screen occasionally reusing a stale delete-confirm dialog or
  overflow menu for the wrong restaurant when switching between restaurants
  in the two-pane layout
- Fix Roulette's price chip not picking up the same colors List and Detail
  already use
- Restore the Overview and Rating section labels on the detail screen as
  TalkBack (screen reader) headings, lost in an earlier visual refresh
- Fix uneven statistics tile heights with longer Catalan labels, and remove a
  "top cuisine" chip in List's search suggestions that could get clipped at
  the screen edge with no scroll hint
- Show a plain X.Y.Z version in Settings' About row for a clean release
  build, instead of the full development build string

## [2.4.1] - 2026-09-06

Remove the System theme option from Settings.

Settings' Theme picker now offers only Light and Dark — the System option
(which followed the device's own dark-mode setting) has been removed since
it wasn't intended to be a user-facing choice. Existing installs with a
saved "System" preference fall back to Light, the new default.

## [2.4.0] - 2026-09-06

Roulette visited filter and visual refresh for List, Detail, Settings and
Statistics.

- Add a want-to-try/visited filter to Roulette (`RouletteViewModel`, `RouletteScreen`).
- Visual refresh to List, Detail, Settings and Statistics — tonal header
  wash and recoloured price chip on List, borderless Overview/Rating and
  tinted Notes with an overflow menu on Detail, card-and-row layout on
  Settings, headline stat tile on Statistics.
- Fix flaky `RestaurantShareWriterTest` failures caused by `FileProvider`'s
  static `PathStrategy` cache surviving across Robolectric test methods.

## [2.3.0] - 2026-09-05

What's New in 2.3.0.

- Add restaurant visit status, photos, notes, free-form tags, and aggregate statistics.
- Add a home-screen widget showing a random "want to try" restaurant.
- Improve Favorites with search, sorting, filtering, and swipe actions.
- Add search suggestions and cuisine icons.
- Improve import compatibility and translated button layout.

## [2.2.2] - 2026-08-31

Add bulk deletion of all restaurants from Settings.

The Settings screen's Data section now includes a "Delete all restaurants"
button, giving users a quick way to clear their entire restaurant list and
reset the app without manually deleting restaurants one by one. The button
follows the existing safe-delete pattern with a confirmation dialog before
clearing the database, and the automatic on-device backup is updated to
reflect the now-empty state to keep data consistent across the app. The
feature is fully localized in English, Spanish, and Catalan.

## [2.2.1] - 2026-08-31

Add `.eatapp` file extension for restaurant export files.

Restaurant export files now use the `.eatapp` extension instead of `.json`,
giving EatApp's shared files a distinct, recognizable type. An additional
intent-filter matches the `.eatapp` extension directly, so files opened from
file managers and downloads folders are now reliably recognized and opened
by EatApp even when their MIME type isn't preserved, making the sharing
feature more dependable across more apps and contexts.

## [2.2.0] - 2026-08-30

Pivot to fully user-owned, offline restaurant data with sharing and backup.

EatApp is now a fully offline, user-owned restaurant tracker instead of a
synced and curated one. The entire remote database sync system has been
removed — no more server-side restaurant database, remote configuration, or
networking code of any kind. The `INTERNET` and `ACCESS_NETWORK_STATE`
permissions, carried over from the previous sync system, have been removed
entirely. The app now installs with an empty list and prompts users to add
their first restaurant through a new in-app form with validation, placing
complete control over their data in their hands.

Since there's no more central restaurant database, users can now share
their restaurants directly with each other: individual restaurants or the
full list can be exported as JSON through Android's native share sheet and
imported by friends. The import path is hardened for safety — files are
size-capped before parsing, validated field-by-field, and sent through a
review-and-confirm screen before any data touches the database. Incoming
restaurants are checked for duplicates by name and address, with per-row
choices to Add, Skip, or Replace.

With restaurants living only on-device and no server backup available,
automatic on-device backup has been added: a `backup.json` file is written
to the app's private storage after every change and protected by Android's
Auto Backup so phone restores and device transfers bring the data along.
Users can also manually export all their restaurant data from the Settings
screen whenever they want, for proactive backup or transfer to another
device.

## [2.1.4] - 2026-08-30

Add two-pane list-detail layout for tablet-width windows and rating filter
improvements.

Tablet users can now view restaurant lists and details side by side on
devices with adequate screen width (≥600dp). The List, Favorites, and
Roulette tabs now use a responsive `ListDetailPaneScaffold` that displays
both panes simultaneously on larger screens, providing a more immersive
browsing experience, while phones continue to navigate between full-screen
views as before. This involved refactoring the detail ViewModel to support
both navigation patterns and adding a pane-aware composition flow.

Also included are quality-of-life improvements for Roulette: the rating
filter range now starts at 1+ instead of 2+, giving users finer control
over suggestions, and the Roulette screen itself is more polished with the
result card now fully scrollable to prevent content clipping, and filter
chips wrapped across multiple lines on narrow screens instead of
horizontally scrolling off-screen.

## [2.1.3] - 2026-08-29

Pin NDK version for native debug symbols archiving.

v2.1.2 added native debug symbols archiving, but AGP requires an installed
NDK to extract symbols from dependencies' prebuilt `.so` files — without an
explicit version, the step was silently skipped and the archive remained
empty. This release pins `ndkVersion` to `28.2.13676358`, ensuring the NDK
is available so `native-debug-symbols.zip` is properly populated for Play
Console crash symbolication.

## [2.1.2] - 2026-08-29

Add native debug symbols archiving for Play Console crash symbolication.

The release build now archives native debug symbols for upload to Play
Console. While the app itself contains no native code, its dependencies may
ship prebuilt `.so` files, and archived symbols enable Play Console to
symbolicate native crashes and ANRs with full debugging information.

## [2.1.1] - 2026-08-29

Add runtime language selection and Catalan language support.

Users can now select their preferred language from Settings, choosing from
English, Spanish, and Catalan without relying on their device's system
language. This expands accessibility to Catalan-speaking users and gives
all users direct control over the app's language.

## [2.1.0] - 2026-08-29

Android package renamed to match saatxi GitHub organization.

With the project's GitHub repository moving to the saatxi organization, the
Android package name has been updated from `com.albertferran.eatapp` to
`com.saatxi.eatapp`. This aligns the app's identity with its new repository
home. Existing installations use the old package name and will need to
migrate to a new Google Play Console listing under the renamed package.

## [2.0.1] - 2026-08-29

PowerShell release-tooling improvements.

This patch release adds and fixes PowerShell scripts for automated release
Android App Bundle building on Windows, with no app behavior changes.

- Add `scripts/bundle.ps1`: new PowerShell script that automates building
  signed release Android App Bundles for Google Play upload, with
  verification of release signing configuration, optional working tree
  cleanliness and tag checks, and R8 `mapping.txt` archival alongside the
  built `.aab` file.
- Fix PowerShell 5.1 stderr redirection crash: both `bundle.ps1` and
  `release.ps1` now use `git tag --points-at HEAD` instead of
  `git describe --tags --exact-match` for handling the "not on a tag" case,
  and wrap `git rev-parse --show-toplevel` checks in try/catch blocks to
  prevent terminating `NativeCommandError` exceptions under strict error
  handling.

README.md is updated to document the new bundling script alongside existing
`gradlew bundleRelease` instructions.

## [2.0.0] - 2026-08-29

Theme customization, favorites, roulette, and adaptive navigation.

- Settings screen added with persistent user preferences; three Material 3
  color palettes (Garden, Indigo, Saffron) now selectable for app theming,
  plus dark/light mode control; Outfit typeface integrated throughout the
  interface.
- Restaurant favorites feature enables users to bookmark and manage
  favorite restaurants, accessible via a dedicated Favorites tab.
- "What to eat" roulette picker offers random restaurant suggestions
  through a new Roulette navigation tab.
- Adaptive bottom navigation and rail automatically adjust for larger
  screens and landscape orientation, optimizing the experience on tablets
  and foldable devices.
- Restaurant profiles now include website and Instagram link fields with
  comprehensive link validation to ensure only properly formatted URLs are
  stored and displayed.
- Phase 8 usability enhancements including predictive back gesture support,
  haptic feedback on interactions, collapsible filter controls, and
  segmented sort.
- Baseline Profile infrastructure scaffolded and generated on real devices
  to optimize app startup performance.
- Dependabot integration configured for automated Gradle and GitHub Actions
  dependency updates via pull requests.
- Unit test coverage expanded with new tests for link validation,
  favorites, roulette, settings, and color contrast verification;
  LazyColumn animations improved with `contentType` and `animateItem()` for
  smoother rendering and better list recycling.

## [1.4.0] - 2026-08-28

Search and sort, Material 3 design, dark mode, and Spanish support.

- Search bar refined with placeholder, clear button, and search icon;
  search now covers name, cuisine, and address.
- Restaurant sorting by name (default) or rating with stable ordering and
  tiebreaks; accessible via checkmark menu in the app bar.
- Material 3 design system completed with full tonal palette from
  terracotta seed covering all color families; dark mode window theme added
  to prevent white flash.
- Detail screen enhanced with `LargeTopAppBar` in cuisine color; shared
  element transition animates cuisine icon from list to detail with 320ms
  cross-fade.
- Spanish localization added with full plurals support; internationalization
  approach documented for future language additions.
- Accessibility enhancements with semantic descriptions on restaurant cards
  and ratings for improved screen reader support.
- Dependencies upgraded: Compose BOM to 2026.08.00, Kotlin to 2.4.10, KSP to
  2.3.11, and updates to lifecycle, activity-compose, navigation-compose,
  and coroutines; `compileSdk` bumped to 37.
- Build system migrated to AGP's built-in Kotlin compiler; `gradle.properties`
  flags cleaned; R8 minification validated.
- GitHub Actions CI workflow added to run tests, lint, and assemble on push
  and pull request.
- Compose preview composables added for list and detail screens supporting
  visual development without an emulator.

## [1.3.1] - 2026-08-27

UI polish, architecture refactoring, and release automation.

- Stabilized list refresh UI by replacing conditional swap between progress
  indicator and refresh button with always-present button disabled during
  sync, eliminating button disappearance and icon layout shift mid-refresh;
  `PullToRefreshBox`'s indicator is now the only spinner on screen (F-33).
- Introduced `RestaurantUiModel` as a dedicated UI model layer between Room
  entities and screens with `Restaurant.toUiModel()` mapper, moving
  formatting logic (price labels, star ratings, address normalization) from
  composables into the mapper; added `isInitialLoad` flag to
  `RestaurantListUiState` to prevent empty state flashing on cold start;
  expanded test suite to 93 tests (F-20, F-22).
- Added `scripts/release.ps1` to automate the release ceremony: validates
  X.Y.Z version format, prevents retagging existing releases locally or
  remotely, warns about uncommitted changes, opens editor for tag message
  composition, and pushes tags by default.

## [1.3.0] - 2026-08-27

Sync robustness improvements, search enhancements, and comprehensive
testing.

- Cap downloaded database size at 10 MB, implement ETag/If-None-Match
  support to skip re-imports of unchanged data, automatically sync on first
  launch when local database is empty, and pre-check connectivity to fail
  immediately offline (F-03, F-07, F-08, F-09).
- Escape SQL LIKE wildcards (`%` and `_`) to match literally in search, and
  add 250ms debounce on query input (F-15, F-16).
- Make searches accent- and case-insensitive, and establish Room migration
  strategy with `fallbackToDestructiveMigration` (F-14, F-17).
- Fix seven low-priority items: move sync result messages into UI state for
  config-change resilience, remove duplicated database singleton, fix "1+"
  rating filter that filtered nothing, show result count when filters are
  active, add Retry action to failed-sync snackbar, replace deprecated
  non-RTL-aware back arrow icon, fix sync-success message pluralization
  (F-21, F-24, F-27, F-31, F-34, F-45, F-46).
- Validate SQLite magic header of downloaded `.db` files before opening to
  prevent confusing errors from truncated downloads or HTML error pages
  (F-04).
- Harden sync plumbing: fix temporary file leaks on abnormal exit, stop
  rejecting legitimately empty synced datasets, make remote database URL
  configurable via `BuildConfig` (F-10, F-11, F-12).
- Add comprehensive JUnit4 test suite with 69 tests using Robolectric for
  Android runtime scenarios.
- Enable R8 code and resource optimization for release builds to
  substantially reduce APK size, and configure release signing via
  `local.properties` or environment variables.
- Extract remaining hardcoded UI strings to resources, expand cuisine
  vocabulary with Catalan and Basque, and fix launcher icon fork-and-knife
  rendering broken by zero-area subpaths.

## [1.2.0] - 2026-08-26

Add Maps integration, sync timestamp tracking, and improved search.

- Tap restaurant address to open in Maps with `geo:` intent (F-36).
- Track and display last successful sync timestamp in About dialog with
  relative time formatting (F-06).
- Expand search to cover cuisine type, address, and notes fields in
  addition to name (F-13).
- Prevent detail screen crashes and blank states: coerce price range and
  rating on import, validate data integrity, handle restaurant deletion
  gracefully with explicit loading/loaded/not-found states (F-01, F-02,
  F-19).
- Add comprehensive logging to all sync failures for on-device diagnostics
  (F-05).
- Cuisine vocabulary fully migrated to stable English keys with localized
  labels for future multi-language support.

## [1.1.0] - 2026-08-26

Material 3 UI redesign, git-tag-based versioning, and documentation
updates.

- Redesigned restaurant list and detail screens with Material 3 theming,
  cuisine-derived icon avatars, color-tinted cards, and improved layouts
  including pull-to-refresh and richer empty states.
- Added git-tag-based automatic versioning with version display UI.
- Extended Material 3 theme with custom rounded shapes and explicit
  container color roles for the terracotta/sage/cream palette.
- Updated README and added CLAUDE.md project instructions.

## [1.0.0] - 2026-08-25

Initial versioned release.
