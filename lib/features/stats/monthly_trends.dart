/// The statistics screen's two time-series, as pure functions.
///
/// Both bucket epoch-millis data into calendar months in Dart rather than SQL:
/// month-of-epoch-millis isn't a single portable SQLite expression, and this
/// data set is small enough that bucketing locally is simpler than teaching the
/// DAO about time zones.
library;

import '../../data/models/stats_projections.dart';

/// How many trailing months the trend charts show.
const int visitTrendMonths = 6;

/// One bar of the "visits per month" chart.
///
/// [monthKey] is `"YYYY-MM"`, which sorts correctly as a plain string, so the
/// chart can rely on the list's own order.
class MonthlyVisitCount {
  const MonthlyVisitCount({required this.monthKey, required this.count});

  final String monthKey;
  final int count;

  @override
  String toString() => 'MonthlyVisitCount($monthKey, $count)';

  @override
  bool operator ==(Object other) =>
      other is MonthlyVisitCount &&
      other.monthKey == monthKey &&
      other.count == count;

  @override
  int get hashCode => Object.hash(monthKey, count);
}

/// One point of the "average rating per month" trend. [average] is null for a
/// month with no visits, so the chart can skip it rather than draw a
/// misleading zero rating.
class MonthlyAverageRating {
  const MonthlyAverageRating({required this.monthKey, required this.average});

  final String monthKey;
  final double? average;

  @override
  String toString() => 'MonthlyAverageRating($monthKey, $average)';

  @override
  bool operator ==(Object other) =>
      other is MonthlyAverageRating &&
      other.monthKey == monthKey &&
      other.average == average;

  @override
  int get hashCode => Object.hash(monthKey, average);
}

/// `"YYYY-MM"` for a point in time, in the local zone — which is the zone the
/// user thinks their visits happened in.
String monthKeyFor(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

String _monthKeyForMillis(int millis) =>
    monthKeyFor(DateTime.fromMillisecondsSinceEpoch(millis));

/// The trailing [months] month keys ending with [now]'s own month, oldest
/// first.
///
/// Built by asking for day 1 of each month rather than by subtracting a month
/// from today's date, so a month that is shorter than the one before it can't
/// roll the window forward or backward.
List<String> trailingMonthKeys({required DateTime now, int months = visitTrendMonths}) {
  final List<String> keys = <String>[];
  for (int monthsAgo = months - 1; monthsAgo >= 0; monthsAgo--) {
    keys.add(monthKeyFor(DateTime(now.year, now.month - monthsAgo, 1)));
  }
  return keys;
}

/// Buckets [visitDates] (epoch millis) into the trailing [months] calendar
/// months ending with [now]'s, oldest first, zero-filled for a month with no
/// visits.
///
/// [now] is a parameter rather than read from the clock so the window is
/// testable at all.
List<MonthlyVisitCount> bucketVisitsByMonth(
  List<int> visitDates, {
  required DateTime now,
  int months = visitTrendMonths,
}) {
  final Map<String, int> countsByMonth = <String, int>{};
  for (final int visitDate in visitDates) {
    final String key = _monthKeyForMillis(visitDate);
    countsByMonth[key] = (countsByMonth[key] ?? 0) + 1;
  }

  return <MonthlyVisitCount>[
    for (final String key in trailingMonthKeys(now: now, months: months))
      MonthlyVisitCount(monthKey: key, count: countsByMonth[key] ?? 0),
  ];
}

/// The same trailing-[months] window as [bucketVisitsByMonth], averaging the
/// ratings per month instead of counting the visits.
///
/// A month with no visits gets a null average rather than 0, so the chart can
/// skip it instead of drawing a rating nobody ever gave.
List<MonthlyAverageRating> bucketRatingsByMonth(
  List<VisitDateRating> visitRatings, {
  required DateTime now,
  int months = visitTrendMonths,
}) {
  final Map<String, List<int>> ratingsByMonth = <String, List<int>>{};
  for (final VisitDateRating visit in visitRatings) {
    (ratingsByMonth[_monthKeyForMillis(visit.visitDate)] ??= <int>[]).add(
      visit.rating,
    );
  }

  return <MonthlyAverageRating>[
    for (final String key in trailingMonthKeys(now: now, months: months))
      MonthlyAverageRating(
        monthKey: key,
        average: _average(ratingsByMonth[key]),
      ),
  ];
}

double? _average(List<int>? ratings) {
  if (ratings == null || ratings.isEmpty) {
    return null;
  }
  int total = 0;
  for (final int rating in ratings) {
    total += rating;
  }
  return total / ratings.length;
}
