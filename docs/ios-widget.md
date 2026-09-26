# Home-screen widget on iOS

The Android widget is self-contained in this repository: its provider, layout
and manifest entry all live under `android/`, and a normal `flutter build apk`
picks them up with no extra step. A Dart-side service
(`lib/widget/home_widget_service.dart`) publishes the widget's data on both
platforms and needs no changes from here.

iOS is different in one specific way: a WidgetKit widget is a separate Xcode
*target*, and a target can only be created in Xcode. That is why this page
exists — the source files are all committed, but the target that compiles them
is not, and can't be, since it lives in `Runner.xcodeproj/project.pbxproj`,
which Xcode owns. Follow these steps once.

## What is already committed

- [`ios/EatAppWidget/EatAppWidget.swift`](../ios/EatAppWidget/EatAppWidget.swift)
  — the widget: its timeline, view and shuffle button.
- `ios/EatAppWidget/Info.plist` — the extension's plist, declaring the
  `com.apple.widgetkit-extension` point.
- `ios/EatAppWidget/EatAppWidget.entitlements` — the extension's App Group.
- `ios/Runner/Runner.entitlements` — the app's App Group. Both name the same
  group, `group.com.saatxi.eatapp`, which is the only channel between the app
  and the widget.
- [`ios/Runner/BackgroundIntent.swift`](../ios/Runner/BackgroundIntent.swift)
  — the App Intent the shuffle button runs on iOS 17+. It has to live in the
  app target, not the extension, because it calls the `home_widget` plugin.
- [`ios/Runner/AppDelegate.swift`](../ios/Runner/AppDelegate.swift) — already
  registers the plugin with the background worker's engine.

The App Group id appears in four places and all four must agree: the Dart
constant `homeWidgetAppGroupId`, the two entitlements files above, and the
`appGroup` in `BackgroundIntent.swift`.

## Steps

1. Open `ios/Runner.xcworkspace` in Xcode and select the `Runner` project.
2. **File → New → Target… → Widget Extension.** Name it `EatAppWidget`,
   uncheck "Include Live Activity", and set its bundle identifier to
   `com.saatxi.eatapp.EatAppWidget`. When Xcode offers to activate the new
   scheme, decline — the widget is built as part of `Runner`.
3. Replace the template files Xcode generated with the committed ones: delete
   the new target's `EatAppWidget.swift`, then add
   `ios/EatAppWidget/EatAppWidget.swift` to it (uncheck "Copy items if
   needed"). If the template produced an `Info.plist`, replace its contents
   with `ios/EatAppWidget/Info.plist`.
4. Add `ios/Runner/BackgroundIntent.swift` to **both** targets: tick both the
   `Runner` and `EatAppWidget` checkboxes in its File Inspector. The extension
   references `EatAppShuffleIntent`, and the type only exists where the file
   is compiled.
5. Give both targets the App Group. For each of `Runner` and `EatAppWidget`,
   open **Signing & Capabilities → + Capability → App Groups** and add
   `group.com.saatxi.eatapp`. Point each target's
   `CODE_SIGN_ENTITLEMENTS` build setting at that target's
   `.entitlements` file if Xcode didn't do it for you. The App Group id must
   match your provisioning profile's; if you fork this app, change it in all
   four places listed above.
6. Set the extension's deployment target to **iOS 17.0** (or higher). The
   widget compiles against iOS 14, but the shuffle button needs the iOS 17
   App Intents API — below that it degrades to an inert icon, and tapping the
   card still opens the app.
7. Leave the `kind` string in `EatAppWidget.swift` as `EatAppWidget`. The Dart
   side looks the widget up by exactly that name.

## Verifying it

Build and run the `Runner` scheme on a device or simulator, then long-press the
home screen → **+** → **EatApp** and add the widget. It should show a
want-to-try restaurant, or the "mark a restaurant want to try" message if
there is none. Tapping the card opens that restaurant's detail screen; tapping
the shuffle icon should swap the restaurant without opening the app.

If the widget stays empty, check the App Group: `UserDefaults(suiteName:)`
returns nil when the group isn't entitled on *both* targets, and both the
writer and the reader fail silently.
