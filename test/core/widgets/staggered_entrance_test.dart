import 'package:eatapp/core/widgets/staggered_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The row's own fade. The nearest `Opacity` ancestor is the one
  /// [StaggeredEntrance] drives.
  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text('row'), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  testWidgets('holds its child back, then reveals it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaggeredEntrance(index: 3, child: Text('row')),
      ),
    );

    // The child is in the tree from the first frame — it is only faint — so a
    // finder or a tap never misses a row that is still animating in.
    expect(find.text('row'), findsOneWidget);
    expect(opacityOf(tester), lessThan(1));

    await tester.pumpAndSettle();

    expect(opacityOf(tester), 1);
  });

  testWidgets('a row past the last slot still finishes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaggeredEntrance(index: 50, child: Text('row')),
      ),
    );

    await tester.pumpAndSettle();

    expect(opacityOf(tester), 1);
  });
}
