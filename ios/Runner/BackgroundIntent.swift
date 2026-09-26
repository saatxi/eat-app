//
//  BackgroundIntent.swift
//  Runner
//
//  The App Intent behind the widget's shuffle button on iOS 17+.
//
//  It lives in the app target rather than the widget extension because it calls
//  into the home_widget plugin, which is only linked into the app. The widget
//  extension references the type, so this file has to be a member of both
//  targets — see docs/ios-widget.md.
//

import AppIntents
import Foundation
import home_widget

@available(iOS 17, *)
struct EatAppShuffleIntent: AppIntent {
  static var title: LocalizedStringResource = "Shuffle want-to-try restaurant"

  func perform() async throws -> some IntentResult {
    // The URL is the same one the Android provider broadcasts; the Dart side
    // treats a `shuffle` host as "pick a new restaurant".
    await HomeWidgetBackgroundWorker.run(
      url: URL(string: "eatapp://shuffle"),
      appGroup: "group.com.saatxi.eatapp"
    )
    return .result()
  }
}

/// Lets the intent run even when the app is fully suspended, by being allowed to
/// bring it to the foreground first. SwiftUI/AppIntents require this to be
/// declared on the app target, not the extension.
@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension EatAppShuffleIntent: ForegroundContinuableIntent {}
