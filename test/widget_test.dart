import 'package:eatapp/core/l10n/generated/app_localizations.dart';
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

  testWidgets('the app starts on the test locale (English)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EatApp());

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull, reason: 'a fresh install follows the device');
    expect(app.supportedLocales, AppLocalizations.supportedLocales);
    // The gallery's own copy, which only renders once the delegate loaded.
    expect(find.text('Garden'), findsOneWidget);
    expect(find.text('Spanish'), findsOneWidget);
  });

  testWidgets('choosing a language re-renders every localized label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EatApp());

    await tester.tap(find.text('Spanish'));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('es'));
    // The same pickers, now read from the Spanish ARB instead: language names
    // are shown in their own locale, and the palette names are translated.
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Inglés'), findsOneWidget);
    expect(find.text('Mercado fresco'), findsOneWidget);
    expect(find.text('Huerto'), findsOneWidget);
    expect(find.text('Garden'), findsNothing);
  });
}
