//
//  EatAppWidget.swift
//  EatAppWidget
//
//  The iOS half of the "Want to try" home-screen widget. Like the Android
//  provider it is deliberately dumb: every string it draws is written into the
//  shared App Group's UserDefaults by the Dart side
//  (lib/widget/home_widget_service.dart), which is where the cuisine, the
//  language and the random pick are actually decided.
//
//  This file only takes effect once the `EatAppWidget` extension target exists
//  and shares the App Group — see docs/ios-widget.md for the one-time Xcode
//  steps, which cannot be done from a text editor.
//

import SwiftUI
import WidgetKit

/// Must match `homeWidgetAppGroupId` in lib/widget/home_widget_service.dart, the
/// App Group in `EatAppWidget.entitlements` and the one in
/// `Runner/Runner.entitlements` — it is the only channel between the app and
/// this extension.
private let appGroupId = "group.com.saatxi.eatapp"

/// Mirrors `HomeWidgetKeys` on the Dart side; the two have to stay in step.
private enum WidgetKeys {
  static let restaurantId = "restaurantId"
  static let title = "title"
  static let subtitle = "subtitle"
  static let label = "label"
  static let empty = "empty"
}

struct EatAppEntry: TimelineEntry {
  let date: Date
  let restaurantId: String
  let title: String
  let subtitle: String
  let label: String
  let empty: String

  var hasRestaurant: Bool { !restaurantId.isEmpty }
}

struct EatAppProvider: TimelineProvider {
  func placeholder(in context: Context) -> EatAppEntry {
    EatAppEntry(
      date: Date(),
      restaurantId: "preview",
      title: "Cal Ferran",
      subtitle: "Catalan · Barcelona",
      label: "EatApp · Want to try",
      empty: "Mark a restaurant \"want to try\" to see it here."
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (EatAppEntry) -> Void) {
    completion(readEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<EatAppEntry>) -> Void) {
    // `.never`: the app republishes the widget itself whenever the data moves or
    // the shuffle button is tapped, so there is no schedule to keep here.
    let entry = readEntry()
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func readEntry() -> EatAppEntry {
    let data = UserDefaults(suiteName: appGroupId)
    return EatAppEntry(
      date: Date(),
      restaurantId: data?.string(forKey: WidgetKeys.restaurantId) ?? "",
      title: data?.string(forKey: WidgetKeys.title) ?? "",
      subtitle: data?.string(forKey: WidgetKeys.subtitle) ?? "",
      label: data?.string(forKey: WidgetKeys.label) ?? "",
      empty: data?.string(forKey: WidgetKeys.empty) ?? ""
    )
  }
}

struct EatAppWidgetView: View {
  var entry: EatAppEntry

  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) { Color.widgetSurface }
    } else {
      content.padding().background(Color.widgetSurface)
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.label)
        .font(.caption2)
        .fontWeight(.bold)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      if entry.hasRestaurant {
        Text(entry.title)
          .font(.headline)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)

        if !entry.subtitle.isEmpty {
          Text(entry.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        HStack {
          Spacer()
          shuffleButton
        }
      } else {
        Text(entry.empty)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(4)
    .widgetURL(deepLink)
  }

  @ViewBuilder
  private var shuffleButton: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      // Runs EatAppShuffleIntent, which re-picks in the background without
      // opening the app. The intent lives in the app target because it needs
      // the home_widget plugin — see Runner/BackgroundIntent.swift.
      Button(intent: EatAppShuffleIntent()) {
        Image(systemName: "shuffle")
      }
      .buttonStyle(.plain)
    } else {
      // Before iOS 17 a widget can't run code on a button tap at all, so the
      // icon is drawn purely as a hint; tapping the card opens the app instead.
      Image(systemName: "shuffle").foregroundStyle(.secondary)
    }
  }

  /// A tap anywhere but the shuffle button opens that restaurant's detail
  /// screen, resolved by the app through `homeWidgetRestaurantId`.
  private var deepLink: URL? {
    guard entry.hasRestaurant else { return URL(string: "eatapp://") }
    return URL(string: "eatapp://restaurant/\(entry.restaurantId)")
  }
}

private extension Color {
  /// Mercado Fresco's light surface (neutral t98), the same paper the Android
  /// widget uses.
  static let widgetSurface = Color(red: 1.0, green: 0.992, blue: 0.968)
}

@main
struct EatAppWidget: Widget {
  /// Must match `_iOSWidgetKind` in lib/widget/home_widget_service.dart, or the
  /// app's update will never find this widget.
  let kind = "EatAppWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: EatAppProvider()) { entry in
      EatAppWidgetView(entry: entry)
    }
    .configurationDisplayName("EatApp")
    .description("A random restaurant you want to try.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
