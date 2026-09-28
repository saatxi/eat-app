# Groups Refactoring Plan

## Goal

Replace the current inline groups section in Settings with a dedicated, full-featured Groups screen that provides complete CRUD operations and fixes the join/share flow issues.

## Current Architecture Analysis

### Existing structure

```
lib/features/groups/
├── group_settings_section.dart   # Inline widget inside Settings (lines 16-88)
├── groups_controller.dart        # App-wide controller: load, select, createGroup
├── invite_controller.dart        # Owner-side: mint token, show QR
├── invite_screen.dart            # QR + share link display
├── join_controller.dart          # Joiner-side: redeem token
├── join_screen.dart              # Code entry + QR scanner
├── members_controller.dart       # Members list CRUD
└── members_screen.dart           # Roster + leave/delete/export
```

### Problems identified

1. **Groups are buried in Settings** — The only entry point is `GroupSettingsSection` embedded in [`settings_screen.dart`](lib/features/settings/settings_screen.dart:118), which offers only a dropdown selector, "New group", "Join", and sync state. There is no top-level destination for managing groups.

2. **No dedicated Groups navigation** — The bottom nav has only Journal, Roulette, Settings. Users must dig into Settings to find any group action.

3. **Join flow issues** (to be diagnosed during testing):
   - QR scanner lives inside [`_ScannerScreen`](lib/features/groups/join_screen.dart:193) pushed from [`JoinScreen`](lib/features/groups/join_screen.dart:57). The scanner uses `mobile_scanner` and extracts tokens via [`inviteTokenFromText()`](lib/data/groups/invite_link.dart:55). Known potential issues: camera permission not requested before launch, `MobileScannerController` lifecycle, barcode format filtering.
   - Manual code entry: validates through [`inviteTokenFromText()`](lib/features/groups/join_screen.dart:78) which accepts `eatapp://join/<token>`, `https://.../join/<token>` or bare 32-char codes. If a user pastes a full share URL from WhatsApp/Gmail, the parsing might fail depending on how the platform handles special characters.
   - Deep link handling: [`main.dart`](lib/main.dart:175) sets up `AppLinks` and passes `initialInviteUri` / `inviteLinkStream` to [`HomeShell._openInviteLink()`](lib/features/home/home_shell.dart:211), which calls [`inviteTokenFromUri()`](lib/data/groups/invite_link.dart:40). This chain looks correct structurally.

4. **Share link issue**: The `_share()` method in [`invite_screen.dart:183`](lib/features/groups/invite_screen.dart:183) calls `SharePlus.instance.share()`. If this fails silently, the most common causes are: missing `SharePlus` initialization, incorrect `sharePositionOrigin` calculation, or the Android app not declaring the required `<queries>` intent filter for `ACTION_SEND`.

### What the refactoring should accomplish

- A new **Groups tab** accessible from the bottom navigation bar (replacing Settings' group section entirely).
- Full CRUD on a single screen: list groups, create, edit name, delete, leave.
- One-tap access to members list and invite screen.
- Keep the existing `JoinScreen` and `InviteScreen` but wire them correctly.
- Fix whatever is broken in scan/code/share — add diagnostics/logging to help debug.

## Proposed New Architecture

### Navigation changes

```
Bottom Nav (3 tabs → 4 tabs):
┌─────────────────────────────────────┐
│  [Journal]  [Roulette]  [Groups]  [Settings] │
└─────────────────────────────────────┘
```

The Groups tab replaces the current inline settings section entirely. The `_SectionHeader(l10n.settingsSectionGroups)` and `GroupSettingsSection` lines in [`settings_screen.dart:118-121`](lib/features/settings/settings_screen.dart:118) are removed.

### New file structure

```
lib/features/groups/
├── groups_screen.dart              # NEW: top-level groups hub
├── groups_controller.dart          # EXISTING: extends with editGroup, renameGroup
├── group_model.dart                # RENAMED FROM: group_models.dart (or keep as-is)
├── groups_list_item.dart           # NEW: reusable group tile widget
├── groups_create_dialog.dart       # EXTRACTED FROM: _CreateGroupDialog
├── groups_edit_dialog.dart         # NEW: edit/rename dialog
├── groups_delete_confirm.dart      # EXTRACTED FROM: confirmation logic
├── join_controller.dart            # EXISTING: unchanged
├── join_screen.dart                # EXISTING: enhanced with better error feedback
├── invite_controller.dart          # EXISTING: unchanged
├── invite_screen.dart              # EXISTING: improved share diagnostics
├── members_controller.dart         # EXISTING: unchanged
└── members_screen.dart             # EXISTING: unchanged
```

### GroupsScreen design

```
┌─────────────────────────────────────┐
│  Groups                  [+ Add]    │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │  My Group         [members]   │  │  ← Tap to open MembersScreen
│  │                    [•● synced]│  │     (existing, unchanged)
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Friend's Group    [members]  │  │
│  │                    [○ offline]│  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  Join a group          [QR]   │  │  ← Opens JoinScreen
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

Each group row shows:
- Name
- Role indicator (owner/member dot)
- Sync status (synced/failed/idle)
- Trailing actions: members icon (opens MembersScreen), overflow menu (edit name, leave, delete)

### Controller extensions needed

[`GroupsController`](lib/features/groups/groups_controller.dart) needs two new methods:

```dart
/// Renames the group. Only an owner may call this.
Future<bool> renameGroup(String groupId, String newName);

/// Edits the group's display properties (currently just name).
Future<bool> editGroup(String groupId, {String? name});
```

These mirror the pattern used by [`MembersController.setDisplayName()`](lib/features/groups/members_controller.dart:100) — they call `gateway.setDisplayName()` internally but scoped to the group context. Actually, looking at the Supabase schema, there is no `groups.edit_name` endpoint — the name is updated directly on the `groups` table. So the implementation would be:

```dart
Future<bool> editGroup(String groupId, {String? name}) async {
  final GroupGateway? gateway = gateway;
  if (gateway == null) return false;
  try {
    if (name != null) {
      await _client.from('groups').update({'name': name}).eq('id', groupId);
    }
    await load();
    return true;
  } catch (error) { ... }
}
```

This requires exposing the `_client` or adding an `editGroup` method to [`GroupGateway`](lib/data/groups/group_gateway.dart:14).

### Screen integration points

#### HomeShell changes ([`home_shell.dart`](lib/features/home/home_shell.dart))

Add a fourth tab destination:

```dart
// In _bottomBar():
NavigationDestination(
  icon: const Icon(Icons.groups_outlined),
  selectedIcon: const Icon(Icons.groups_rounded),
  label: l10n.navGroups,
),

// In _sections():
IndexedStack children add:
  GroupsScreen(),

// In _railDestinations():
NavigationRailDestination(
  icon: const Icon(Icons.groups_outlined),
  selectedIcon: const Icon(Icons.groups_rounded),
  label: Text(l10n.navGroups),
),
```

Update `_index` tracking to support 4 tabs instead of 3.

#### Settings screen cleanup ([`settings_screen.dart`](lib/features/settings/settings_screen.dart))

Remove lines 114-121:
```dart
// DELETE:
if (scope.groupsController?.canUseGroups ?? false) ...<Widget>[
  _SectionHeader(l10n.settingsSectionGroups),
  GroupSettingsSection(controller: scope.groupsController!),
],
```

### Localization additions

Add these keys to all three ARB files (`app_en.arb`, `app_es.arb`, `app_ca.arb`):

| Key | English | Spanish | Catalan |
|-----|---------|---------|---------|
| `navGroups` | Groups | Grupos | Grups |
| `groupsEditTitle` | Edit group | Editar grupo | Editar grup |
| `groupsFieldName` | Group name | Nombre del grupo | Nom del grup |
| `groupsEditAction` | Save | Guardar | Desar |
| `groupsEditErrorFailed` | Couldn't update group | No se pudo actualizar el grupo | No s'ha pogut actualitzar el grup |
| `groupsTapToOpen` | Open group | Abrir grupo | Obre el grup |

### Error handling improvements for join flow

In [`JoinScreen`](lib/features/groups/join_screen.dart), add more diagnostic info:

1. When `_scan()` returns a token, log it so we know the scanner succeeded.
2. When `inviteTokenFromText()` returns null, distinguish between "not a valid token" and "looks like a URL but malformed".
3. Add a "Paste from clipboard" button next to the code field.
4. Show the parsed token before calling `controller.join()` so the user can verify.

### Share link diagnostics

In [`_Ready._share()`](lib/features/groups/invite_screen.dart:183):

1. Wrap the `SharePlus.instance.share()` call in a try-catch that logs the exact error.
2. Verify `sharePositionOriginFor(context)` returns a non-null Rect on Android.
3. Check that `<queries>` includes `android.intent.action.ACTION_SEND` in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml:116) — it currently only declares `PROCESS_TEXT`.

---

## Implementation Steps

### Phase 1: Foundation

1. **Extend GroupGateway** — Add `editGroup(String groupId, String name)` method to the abstract class and `SupabaseGroupGateway` implementation.
2. **Extend GroupsController** — Add `editGroup()` method that calls the gateway and reloads.
3. **Add localization keys** — Add all new strings to the three ARB files.

### Phase 2: New screen

4. **Create `groups_screen.dart`** — The main hub with:
   - ListenableBuilder over GroupsController
   - Group list tiles with sync indicators
   - FAB or app bar action for "Add group"
   - "Join a group" row
   - Overflow menu per group (edit name, leave, delete)
5. **Extract/create helper widgets**:
   - `groups_create_dialog.dart` — extracted from `_CreateGroupDialog`
   - `groups_edit_dialog.dart` — new dialog for renaming
   - `groups_list_item.dart` — reusable tile
6. **Integrate into HomeShell** — Add Groups tab to bottom nav, rail, and IndexedStack.
7. **Clean up Settings** — Remove the `GroupSettingsSection` import and usage.

### Phase 3: Join flow fixes

8. **Enhance JoinScreen** — Add paste-from-clipboard button, show parsed token preview, improve error messages.
9. **Fix ScannerScreen** — Ensure `MobileScannerController` is initialized with proper format options, add camera permission check before launch.
10. **Verify deep link chain** — Test `AppLinks` → `HomeShell._openInviteLink()` → `JoinScreen(initialToken:)` flow.

### Phase 4: Share fixes

11. **Check Android manifest** — Ensure `<queries>` intent filter covers `ACTION_SEND` for `share_plus`.
12. **Add share diagnostics** — Log errors from `SharePlus.instance.share()`.

### Phase 5: Tests & verification

13. **Unit tests** — For `GroupsController.editGroup()`, `inviteTokenFromText()` edge cases.
14. **Widget tests** — For `GroupsScreen` rendering, dialogs, and interaction.
15. **Run full verification** — `flutter analyze`, `flutter test`, `flutter gen-l10n`.

---

## Risk considerations

- **Breaking change**: Removing groups from Settings means users who were used to finding it there will need to learn the new location. Mitigation: keep the group selector visible in the journal/list area (it already exists via the scope chip).
- **Supabase schema**: Editing a group name does not have a dedicated Edge Function — it goes directly to the `groups` table. This requires verifying RLS policies allow it. The `groups_update_owner` policy should cover this.
- **mobile_scanner version**: The current code uses `MobileScanner` with `onDetect` callback. Newer versions use `controller.barcodes.listen()`. If there's a version mismatch, the scanner won't fire callbacks.
- **share_plus compatibility**: On Android 13+, `share_plus` sometimes fails without explicit `<queries>` in the manifest. The fix is usually:
  ```xml
  <queries>
    <intent>
      <action android:name="android.intent.action.SEND" />
    </intent>
  </queries>
  ```

## Open questions

1. Should the Groups tab appear when `canUseGroups` is false (personal mode)? If so, show "Personal mode — groups require the shared backend" message, or hide the tab entirely?
2. Should group editing include changing the group's photo/icon? Currently groups don't have photos — this could be a future enhancement.
3. The user mentioned they want to test first before fixing the specific bugs. Should this plan proceed as a pure refactoring (new screen, same join/share behavior) with separate bug-fix tickets after testing identifies the root causes?
