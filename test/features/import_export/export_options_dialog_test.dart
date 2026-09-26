import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/features/import_export/export_options_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a button that opens the dialog and reports what it resolved to, so a
/// test can drive the dialog the way a screen does and assert on the value.
Widget _host(ValueChanged<bool?> onResult) => MaterialApp(
  theme: AppTheme.of(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () async => onResult(await showExportOptionsDialog(context)),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  group('showExportOptionsDialog', () {
    testWidgets('keeps visits by default and confirms with true', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_host((bool? value) => result = value));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Export restaurants'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('turning the switch off confirms with false', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_host((bool? value) => result = value));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('cancelling resolves to null so nothing is exported', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_host((bool? value) => result = value));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
