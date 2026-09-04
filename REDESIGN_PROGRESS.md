# EatApp Redesign Progress

## Overview

This document tracks the progress on visual and UX improvements for EatApp, following a comprehensive audit of the app's interface and identification of key gaps. The full redesign proposal is available in the [Visual Design Proposal Artifact](https://claude.ai/code/artifact/cd682044-962b-4c0d-82c1-696e5ccbd37f).

---

## ✅ Implemented Features

### 1. Restaurant Visit Status (`visited` field)
**Status**: COMPLETE  
**Commit**: Add restaurant visit status: "visited" vs "want to try"

#### What was done:
- Added `visited: Boolean` field to `Restaurant` entity (defaults to `true` for backward compatibility)
- Created Room migration 5→6 to add the column safely; existing rows with `rating=0` marked as "want to try", others as "visited"
- Extended `RestaurantExport`/`RestaurantShareFile` JSON to include `visited` field (defaults `true` for older export files)
- Added `visited` filter to DAO query and repository interface (`null` = no filter)
- Updated `RestaurantUiModel` to carry visit status
- Added segmented button toggle in edit/add form ("Quiero ir" / "Ya he ido")
- Added visit status filters to list screen with two filter chips
- Display "Por probar" (want to try) badge on unvisited rows in list
- Show visit status in detail screen overview section when not yet visited
- Added Spanish (`visit_status_visited`, `visit_status_want_to_try`) and Catalan translations
- Comprehensive test coverage:
  - DAO tests for `visited` filter (inclusion/exclusion/no-filter cases)
  - Export/import tests for backward compatibility and round-trip serialization
  - ViewModel tests for filter state management
  - UI model tests for the field carry-through
  - All ViewModel fakes updated for consistency

#### Files changed:
- Data layer: `Restaurant.kt`, `EatAppDatabase.kt` (migration), `RestaurantDao.kt`, `RestaurantRepository.kt`, `RoomRestaurantRepository.kt`, `RestaurantShareModels.kt`
- UI layer: `RestaurantEditScreen.kt`, `RestaurantEditViewModel.kt`, `RestaurantListScreen.kt`, `RestaurantListViewModel.kt`, `RestaurantDetailScreen.kt`, `RestaurantUiModel.kt`, `RouletteScreen.kt`, `FavoritesScreen.kt`
- Strings (all locales): `strings.xml`, `values-es/strings.xml`, `values-ca/strings.xml`
- Tests: 8 files updated with new test cases and fake repository signatures

---

## 📋 Remaining Work (Prioritized Roadmap)

### Tier 1: High Impact, Low Effort

#### 2. Free-form Notes
**Impact**: HIGH | **Effort**: LOW  
- Add a `notes: String?` column to `Restaurant` entity
- Extend `RestaurantEditUiState` with a notes field and `onNotesChange` callback
- Add a multi-line `OutlinedTextField` in the edit form (after Address field)
- Display notes in detail screen overview card with an italic, smaller style
- Update export/import JSON models
- Test: DAO, import validation, ViewModel, UI model

**Why**: Every user remembers "ask for the burrata as an appetizer" far better than generic metadata. Notes are the second most-requested field after photos.

#### 3. Cuisine Dropdown Icons in Edit Form
**Impact**: LOW | **Effort**: LOW  
- Add `leadingIcon` to each `DropdownMenuItem` in `CuisineDropdown`
- Reuse the icon lookup already built for filter chips
- Mirroring the visual language from list-screen filters improves recognition

#### 4. Segmented Button for Visit Status in Edit Form
**Status**: Already done (as part of #1)

#### 5. Shared Composable: `RatingAndPriceRow`
**Impact**: MEDIUM | **Effort**: LOW  
- Extract the stars + "N/5" + price-pill markup into one reusable composable
- Currently copy-pasted in `RestaurantListScreen.RestaurantRow`, `RestaurantDetailScreen`, and `RouletteScreen.RouletteResultCard`
- Reduces maintenance burden and ensures consistent styling

---

### Tier 2: Medium Impact

#### 6. Free-form Tags/Labels
**Impact**: MEDIUM | **Effort**: MEDIUM  
- Add new entity `Tag` with N:N relationship to `Restaurant` via junction table
- Add `RestaurantTag` junction entity to Room
- Update edit form with a free-entry chip-input field (suggest existing tags)
- Display tags as pill badges below the cuisine label in list and detail rows
- Example tags: "terraza", "para grupos", "llevar niños"

#### 7. Search and Filter Consistency in Favorites Screen
**Impact**: MEDIUM | **Effort**: LOW  
- Favoritos screen today reuses `RestaurantRow` but lacks search/sort/filter
- Add the search bar and filter chips from list screen
- Makes the two screens consistent and more discoverable

#### 8. Cuisine Icon in Import Candidate Rows
**Impact**: MEDIUM | **Effort**: LOW  
- Import screen's candidate rows today are plain text, missing the cuisine badge
- Add 48dp circular badge with cuisine icon (matching list/detail/roulette treatment)
- One line of visual consistency across the whole app

#### 9. Edit/Add Form Grouping in Cards
**Impact**: MEDIUM | **Effort**: LOW  
- Currently all fields in a single scrolling column without visual grouping
- Group into 3 cards: "Basics" (name, cuisine, address), "Rating" (rating, price, visited), "Links" (website, instagram)
- Matches the visual pattern from detail screen
- Improves mental model of the form's shape

---

### Tier 3: High Impact, Medium Effort

#### 10. Restaurant Photos
**Impact**: HIGH | **Effort**: MEDIUM  
- Add `photoUri: String?` column to `Restaurant` entity (store a URI to app-internal cache)
- Use Android Photo Picker (no storage permission needed) to let users pick a photo
- Copy selected photo to app's cache directory; store the URI in Room
- Display photo in list rows (replacing or above the cuisine badge)
- Display photo as hero image in detail screen (above the current "Overview" card)
- Photo shows in roulette result card as well
- Update export/import to handle photo URIs (or skip photos in exports if too large)

**Why**: A photo is the single strongest memory cue for a restaurant. The audit found this was the #1 gap across all screens.

#### 11. Statistics Screen
**Impact**: HIGH | **Effort**: MEDIUM  
- New nav destination under settings or as a card in settings
- Show aggregates: most-eaten cuisines, average rating, price distribution, total restaurants, visited vs. want-to-try split
- Use simple bar charts or stat tiles (no heavy charting library needed)
- All computed locally from Room with no network calls

#### 12. Swipe Actions on List Rows
**Impact**: MEDIUM | **Effort**: MEDIUM  
- Use `SwipeToDismissBox` to add left/right swipe gestures to `RestaurantRow`
- Left swipe: mark as favorite (or add to favorites and delete from want-to-try)
- Right swipe: delete or mark as visited (depending on current state)
- Faster than entering the detail screen for common actions

---

### Tier 4: Polish & Advanced

#### 13. Search Suggestions & Empty Search State
**Impact**: MEDIUM | **Effort**: LOW  
- When search bar is empty, show "Popular", "Recently added", or "Top-rated" sections
- Reduce cognitive load vs. a blank screen

#### 14. Skeleton / Shimmer Loading States
**Impact**: MEDIUM | **Effort**: LOW  
- Replace centered `CircularProgressIndicator` with shape-matching skeleton placeholders
- Perceived performance improves even if actual load time is the same

#### 15. Home Screen Widget
**Impact**: MEDIUM | **Effort**: HIGH  
- Glance widget showing the latest roulette pick or next "want to try" restaurant
- Requires exploring Glance library and Android widget framework
- Lower priority: nice-to-have for frequent users

---

## 🎯 Visual Design Proposal

The full interactive proposal—including before/after mockups, detailed audit findings, and all 14 planned improvements—is available here:

**[EatApp Visual Design Proposal](https://claude.ai/code/artifact/cd682044-962b-4c0d-82c1-696e5ccbd37f)**

### Key findings from the audit:

✅ **What already works well:**
- Custom 3-palette tonal system (Saffron, Garden, Indigo) with full light/dark support
- Cuisine identity system (24 keys × 8 accent colors, no collision)
- Shared-element transition from list badge into detail bar
- Roulette's 3D flip animation with haptic feedback

❌ **Gaps identified:**
- No photos anywhere in the app (biggest single visual gap)
- No notes or free-form tags on restaurants
- No "visited vs. want to try" status
- Settings screen is flat (no cards, no icons on rows)
- Edit form is a long unsegmented column
- Favorites screen lacks search/filter parity with list
- Import screen breaks the cuisine-badge visual language

---

## 🛠️ Tech Notes

### Database Migration Strategy
When a new field is added:
1. Create a `MIGRATION_X_Y` object extending `Migration(X, Y)` in `EatAppDatabase.kt`
2. Use `ALTER TABLE` to add the column with a sensible default
3. For data-dependent defaults (like the `visited` field), use `UPDATE` to set based on existing columns
4. Increment `@Database(..., version = Y)`
5. Add tests to `RestaurantDaoTest` to verify the filter works end-to-end

### Backward Compatibility
- JSON export/import defaults new fields to "safe" values (e.g., `visited = true`, `notes = ""`)
- Older export files missing these fields deserialize cleanly thanks to `@Serializable` defaults
- No migration-in-place needed for importing; the DAO's `toRestaurantOrNull()` handles validation

### Test Coverage
Every new DAO query should have test cases in `RestaurantDaoTest` covering:
- No filter (returns all matching)
- Filter included (returns only matching)
- Multiple filters combined

UI layer tests should verify:
- ViewModel state updates correctly on user action
- UI state flows through the view
- Export/import round-trips preserve the new field

---

## 📊 Estimated Timeline

| Phase | Features | Est. Effort | Priority |
|-------|----------|------------|----------|
| **Phase 1** | Visit status (✅ done), Notes, Cuisine icons, Rating/Price shared component | 2–3 days | NOW |
| **Phase 2** | Tags, Favorites consistency, Import icon, Form grouping | 2–3 days | Q1 |
| **Phase 3** | Photos, Statistics screen | 3–5 days | Q1–Q2 |
| **Phase 4** | Swipe actions, Skeleton states, Search suggestions | 2 days | Q2 |
| **Phase 5** | Widget, advanced polish | 2+ days | Q2+ |

---

## 📝 Next Steps

1. **Pick one from Tier 1**: Notes or Cuisine icons—both are quick wins that unlock higher-value work
2. **Test on real devices**: The shared-element transition and roulette animation are smooth in debug; run on older devices to confirm
3. **Gather user feedback**: Soft-launch the visit status feature; see if it's intuitive before adding photo support
4. **Plan the photos feature**: Involve design on file layout, cache management, and the export/import story for photos

---

Generated: 2026-09-04  
Design proposal: https://claude.ai/code/artifact/cd682044-962b-4c0d-82c1-696e5ccbd37f
