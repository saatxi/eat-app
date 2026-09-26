import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/theme/app_theme_mode.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design direction keeps the app's visual identity the same on every
/// platform and adapts only the *behaviour*. On iOS that means the edge
/// swipe-back gesture, which Flutter already wires up through the framework's
/// own default `PageTransitionsTheme` — so the app deliberately overrides
/// nothing, and these tests lock that decision in rather than restating it as
/// an override someone would later duplicate.
void main() {
  final PageTransitionsTheme transitions = AppTheme.of().pageTransitionsTheme;

  test('iOS and macOS get the Cupertino transition, so swipe-back works', () {
    expect(
      transitions.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      transitions.builders[TargetPlatform.macOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  test('Android does not get the iOS transition', () {
    expect(
      transitions.builders[TargetPlatform.android],
      isNot(isA<CupertinoPageTransitionsBuilder>()),
    );
  });

  test('the dark theme makes the same choice as the light one', () {
    expect(
      AppTheme.of(
        mode: AppThemeMode.dark,
      ).pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });
}
