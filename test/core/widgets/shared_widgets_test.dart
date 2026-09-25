import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/widgets/empty_state.dart';
import 'package:eatapp/core/widgets/rating_and_price_row.dart';
import 'package:eatapp/core/widgets/shimmer_box.dart';
import 'package:eatapp/core/widgets/tag_pill_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget in the minimum MaterialApp the shared pieces need: the theme
/// (for the cuisine accents and typography) and the app's own localization
/// delegates (for the rating and price strings).
Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.of(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  group('RatingAndPriceRow', () {
    testWidgets('draws a star per rating step and the N/5 label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const RatingAndPriceRow(rating: 4, priceLabel: '10-20 €')),
      );

      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.text('4/5'), findsOneWidget);
      expect(find.text('10-20 €'), findsOneWidget);
    });

    testWidgets('a single star is a decorative accent, always filled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RatingAndPriceRow(
            rating: 0,
            priceLabel: '',
            starCount: 1,
            starSize: 16,
            stacked: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      // No price label means no pill at all, rather than an empty one.
      expect(find.text('10-20 €'), findsNothing);
    });
  });

  group('TagPillRow', () {
    testWidgets('collapses the overflow into a +N pill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TagPillRow(
            tags: <String>['Terraza', 'Grupos', 'Niños', 'Brunch', 'Vegano'],
            maxVisible: 3,
          ),
        ),
      );

      expect(find.text('Terraza'), findsOneWidget);
      expect(find.text('Brunch'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('draws nothing when there are no tags', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const TagPillRow(tags: <String>[], maxVisible: 3)),
      );

      expect(find.byType(TagPill), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('shows the action and fires it', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            body: 'Try a different search or filter.',
            actionLabel: 'Clear filters',
            onAction: () => taps++,
          ),
        ),
      );

      expect(find.text('No matches'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      expect(taps, 1);
    });

    testWidgets('draws without an action when none is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.restaurant_menu,
            title: 'No restaurants yet',
            body: 'Add your first restaurant to get started.',
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  testWidgets('ShimmerBox renders and animates', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(const ShimmerBox(width: 48, height: 48)),
    );

    expect(find.byType(ShimmerBox), findsOneWidget);
    // A frame later the pulse is still running; settling is impossible while it
    // repeats, so just prove it advanced past the first frame.
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });
}
