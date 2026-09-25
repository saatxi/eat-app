import 'package:eatapp/data/models/stats_projections.dart';
import 'package:eatapp/features/stats/monthly_trends.dart';
import 'package:flutter_test/flutter_test.dart';

int _millis(DateTime date) => date.millisecondsSinceEpoch;

void main() {
  // A fixed "now" is the whole reason these functions take one: the window is
  // otherwise untestable.
  final DateTime now = DateTime(2026, 3, 15);

  group('monthKeyFor', () {
    test('pads the month, and the year when it needs to', () {
      expect(monthKeyFor(DateTime(2026, 3, 15)), '2026-03');
      expect(monthKeyFor(DateTime(2026, 12, 1)), '2026-12');
      expect(monthKeyFor(DateTime(2026, 1, 1)), '2026-01');
    });

    test('sorts as a plain string, which is what the charts rely on', () {
      final List<String> keys = <String>[
        monthKeyFor(DateTime(2026, 12, 1)),
        monthKeyFor(DateTime(2026, 2, 1)),
        monthKeyFor(DateTime(2025, 9, 1)),
      ]..sort();

      expect(keys, <String>['2025-09', '2026-02', '2026-12']);
    });
  });

  group('trailingMonthKeys', () {
    test('ends with the current month and counts back the window', () {
      expect(trailingMonthKeys(now: now), <String>[
        '2025-10',
        '2025-11',
        '2025-12',
        '2026-01',
        '2026-02',
        '2026-03',
      ]);
    });

    test('crosses a year boundary correctly', () {
      expect(trailingMonthKeys(now: DateTime(2026, 1, 1), months: 3), <String>[
        '2025-11',
        '2025-12',
        '2026-01',
      ]);
    });

    test('a late day in a long month does not roll the window forward', () {
      // Each key is built from day 1 of its month, so March 31st cannot push
      // the February entry into March.
      expect(trailingMonthKeys(now: DateTime(2026, 3, 31), months: 3), <String>[
        '2026-01',
        '2026-02',
        '2026-03',
      ]);
    });

    test('February is present in a window that spans it', () {
      expect(
        trailingMonthKeys(now: DateTime(2026, 3, 30), months: 4),
        contains('2026-02'),
      );
    });
  });

  group('bucketVisitsByMonth', () {
    test('counts the visits in each month, oldest first', () {
      final List<MonthlyVisitCount> buckets = bucketVisitsByMonth(<int>[
        _millis(DateTime(2026, 3, 1)),
        _millis(DateTime(2026, 3, 20)),
        _millis(DateTime(2026, 1, 5)),
      ], now: now);

      expect(
        <String>[for (final MonthlyVisitCount b in buckets) b.monthKey],
        trailingMonthKeys(now: now),
      );
      expect(
        <int>[for (final MonthlyVisitCount b in buckets) b.count],
        <int>[0, 0, 0, 1, 0, 2],
      );
    });

    test('every trailing month is present even with nothing to show', () {
      final List<MonthlyVisitCount> buckets = bucketVisitsByMonth(
        const <int>[],
        now: now,
      );

      expect(buckets, hasLength(visitTrendMonths));
      expect(
        buckets.every((MonthlyVisitCount b) => b.count == 0),
        isTrue,
        reason: 'the chart draws a zero bar rather than skipping the month',
      );
    });

    test('visits older than the window are dropped, not miscounted', () {
      final List<MonthlyVisitCount> buckets = bucketVisitsByMonth(<int>[
        _millis(DateTime(2024, 5, 1)),
        _millis(DateTime(2026, 3, 2)),
      ], now: now);

      expect(
        <int>[for (final MonthlyVisitCount b in buckets) b.count],
        <int>[0, 0, 0, 0, 0, 1],
      );
    });

    test('the window length is a parameter', () {
      final List<MonthlyVisitCount> buckets = bucketVisitsByMonth(<int>[
        _millis(DateTime(2025, 3, 1)),
      ], now: now, months: 13);

      expect(buckets, hasLength(13));
      expect(buckets.first.monthKey, '2025-03');
      expect(buckets.first.count, 1);
    });
  });

  group('bucketRatingsByMonth', () {
    test('averages the ratings within each month', () {
      final List<MonthlyAverageRating> trend = bucketRatingsByMonth(
        <VisitDateRating>[
          VisitDateRating(visitDate: _millis(DateTime(2026, 3, 1)), rating: 5),
          VisitDateRating(visitDate: _millis(DateTime(2026, 3, 2)), rating: 4),
          VisitDateRating(visitDate: _millis(DateTime(2026, 2, 1)), rating: 2),
        ],
        now: now,
      );

      final Map<String, double?> byMonth = <String, double?>{
        for (final MonthlyAverageRating point in trend) point.monthKey: point.average,
      };
      expect(byMonth['2026-03'], 4.5);
      expect(byMonth['2026-02'], 2.0);
      expect(byMonth['2026-01'], isNull);
    });

    test('a month with no visits has a null average, not a zero', () {
      final List<MonthlyAverageRating> trend = bucketRatingsByMonth(
        <VisitDateRating>[
          VisitDateRating(visitDate: _millis(DateTime(2026, 3, 1)), rating: 3),
        ],
        now: now,
      );

      expect(trend.first.average, isNull);
      expect(trend.last.average, 3.0);
    });

    test('a rating of zero is a real rating, not an absent one', () {
      final List<MonthlyAverageRating> trend = bucketRatingsByMonth(
        <VisitDateRating>[
          VisitDateRating(visitDate: _millis(DateTime(2026, 3, 1)), rating: 0),
        ],
        now: now,
      );

      expect(trend.last.average, 0.0);
    });

    test('pairs every trailing month with a point', () {
      final List<MonthlyAverageRating> trend = bucketRatingsByMonth(
        const <VisitDateRating>[],
        now: now,
      );

      expect(
        <String>[for (final MonthlyAverageRating p in trend) p.monthKey],
        trailingMonthKeys(now: now),
      );
      expect(trend.every((MonthlyAverageRating p) => p.average == null), isTrue);
    });
  });
}
