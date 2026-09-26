import 'package:eatapp/core/widgets/animated_counter.dart';
import 'package:eatapp/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two motion primitives the redesign added: a press that shrinks a target
/// while it is held, and a number that counts up to its value. Both are meant to
/// settle (never to keep a frame source alive), and both must stand down when the
/// platform asks for reduced motion.
void main() {
  group('PressableScale', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

    testWidgets('shrinks while held and settles back on release', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PressableScale(child: Text('press me')),
          ),
        ),
      );

      expect(scaleOf(tester), 1);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      // One frame starts the ticker and the next advances it: a single pump
      // would report elapsed zero and the child would still be at full size.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(scaleOf(tester), lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(scaleOf(tester), 1);
    });

    testWidgets('does not scale when animations are disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(
              child: PressableScale(child: Text('press me')),
            ),
          ),
        ),
      );

      // The child is still drawn — the wrapper simply steps out of the way.
      expect(find.text('press me'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
    });

    testWidgets('a disabled wrapper does not scale', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PressableScale(enabled: false, child: Text('press me')),
          ),
        ),
      );

      expect(find.text('press me'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
    });
  });

  group('AnimatedCounter', () {
    testWidgets('climbs from zero to its value and settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 8)),
      );

      // It starts from zero, so the final number is not there yet.
      expect(find.text('8'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('jumps straight to the value when animations are disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AnimatedCounter(value: 8),
          ),
        ),
      );

      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('counts up again when the value changes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 2)),
      );
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 9)),
      );
      await tester.pump();

      // Mid-count it is still short of the new target.
      expect(find.text('9'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('renders through the supplied formatter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedCounter(
            value: 4,
            format: (int value) => '$value €',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 €'), findsOneWidget);
    });
  });
}
