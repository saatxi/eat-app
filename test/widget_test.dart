import 'package:eatapp/core/theme/app_palette.dart';
import 'package:eatapp/core/theme/palettes/garden_palette.dart';
import 'package:eatapp/core/theme/app_theme_mode.dart';
import 'package:eatapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds on the default palette and mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EatApp());

    expect(find.text('EatApp'), findsOneWidget);
    expect(find.text('Palette'), findsOneWidget);

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme!.colorScheme.primary, AppPalette.fallback.tones.primary.t40);
  });

  testWidgets('choosing a palette rebuilds the theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EatApp());

    await tester.tap(find.text('Garden'));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, gardenTones.primary.t40);
    expect(app.darkTheme!.colorScheme.primary, gardenTones.primary.t80);
  });

  testWidgets('toggling dark mode switches MaterialApp.themeMode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EatApp());

    await tester.tap(find.byIcon(Icons.light_mode));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(AppThemeMode.dark.brightness, Brightness.dark);
  });
}
