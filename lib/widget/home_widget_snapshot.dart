import 'package:flutter/foundation.dart';

import '../core/l10n/generated/app_localizations.dart';
import '../data/db/app_database.dart';
import '../data/models/cuisine.dart';

/// The keys the home-screen widget's data is stored under.
///
/// Shared verbatim between the Dart side that writes them
/// (`lib/widget/home_widget_service.dart`) and the two native readers — the
/// Android `AppWidgetProvider` and the iOS WidgetKit extension — so all three
/// have to agree on every string here. They are plain strings rather than an
/// enum because the native side can only ever see the stored value, not the
/// name its writer used.
abstract final class HomeWidgetKeys {
  /// The shown restaurant's id, or empty when there is nothing to try.
  static const String restaurantId = 'restaurantId';

  /// The restaurant's name.
  static const String title = 'title';

  /// The cuisine (and town, when known) under the name.
  static const String subtitle = 'subtitle';

  /// The small header, so the widget can be localized without a native string
  /// per language — see the note on the language in
  /// `lib/widget/home_widget_service.dart`.
  static const String label = 'label';

  /// Shown in place of the name when nothing is want-to-try.
  static const String empty = 'empty';

  /// The shuffle button's label.
  static const String shuffle = 'shuffle';
}

/// The scheme both of the widget's deep links use — the tap-to-open one
/// (`eatapp://restaurant/<id>`) and the shuffle one (`eatapp://shuffle`).
///
/// A private scheme that belongs to the app, so a link arriving from anywhere
/// else is recognisably not one of ours; see [homeWidgetRestaurantId].
const String homeWidgetScheme = 'eatapp';

/// The link a tap on the widget's card opens the app with.
Uri homeWidgetRestaurantLink(String restaurantId) =>
    Uri(scheme: homeWidgetScheme, host: 'restaurant', path: '/$restaurantId');

/// The link the widget's shuffle button broadcasts to the background callback.
final Uri homeWidgetShuffleLink = Uri(
  scheme: homeWidgetScheme,
  host: 'shuffle',
);

/// The restaurant id in [uri] when it is one of our tap-to-open links, else
/// null.
///
/// Deliberately strict: anything that isn't exactly our scheme *and* our
/// `restaurant` host is rejected, so a stray URI — the shuffle link, a link
/// from another app, a malformed one — can never push a screen.
String? homeWidgetRestaurantId(Uri? uri) {
  if (uri == null ||
      uri.scheme != homeWidgetScheme ||
      uri.host != 'restaurant' ||
      uri.pathSegments.isEmpty) {
    return null;
  }
  final String id = uri.pathSegments.first;
  return id.isEmpty ? null : id;
}

/// What the home-screen widget draws, as plain strings.
///
/// Everything the widget shows is decided here and handed to the native side as
/// text, so neither the Android provider nor the WidgetKit extension has to
/// know about cuisines, translations or the database.
@immutable
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.restaurantId,
    required this.title,
    required this.subtitle,
  });

  /// An snapshot with nothing to show, which is what the widget renders as its
  /// "mark a restaurant want to try" state.
  static const HomeWidgetSnapshot empty = HomeWidgetSnapshot(
    restaurantId: '',
    title: '',
    subtitle: '',
  );

  /// Empty when there is nothing to try.
  final String restaurantId;

  /// The restaurant's name, or empty when there is nothing to try.
  final String title;

  /// Cuisine, with the town appended when one is known — or empty.
  final String subtitle;

  /// Whether the widget has a restaurant to draw rather than its empty state.
  bool get hasRestaurant => restaurantId.isNotEmpty;
}

/// Builds the widget's strings for [restaurant], or [HomeWidgetSnapshot.empty]
/// when it is null (nothing is want-to-try).
///
/// Pure on purpose: the platform bridge around it only runs on a device, but
/// this — the part that actually decides what the widget reads — does not, so a
/// plain unit test holds the real behaviour.
HomeWidgetSnapshot buildHomeWidgetSnapshot({
  required Restaurant? restaurant,
  required AppLocalizations l10n,
}) {
  if (restaurant == null) {
    return HomeWidgetSnapshot.empty;
  }
  // An unrecognised cuisine key (an old row after a rename) shows the raw value
  // rather than nothing, the same graceful degradation the rest of the app
  // applies — see `Cuisine.fromKey`.
  final String cuisine =
      Cuisine.fromKey(restaurant.cuisineType)?.label(l10n) ??
      restaurant.cuisineType;
  final String? city = _nonBlank(restaurant.city);
  return HomeWidgetSnapshot(
    restaurantId: restaurant.id,
    title: restaurant.name,
    subtitle: city == null ? cuisine : '$cuisine · $city',
  );
}

String? _nonBlank(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
