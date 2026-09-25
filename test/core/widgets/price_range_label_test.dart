import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/widgets/price_range_label.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  test('renders each band from the ARB', () {
    expect(priceRangeLabel(en, 1), '1-10 €');
    expect(priceRangeLabel(en, 4), '30-40 €');
    expect(priceRangeLabel(en, 6), '50 € or more');
  });

  test('is empty for "not set" and for values off the scale', () {
    expect(priceRangeLabel(en, 0), isEmpty);
    expect(priceRangeLabel(en, 7), isEmpty);
    expect(priceRangeLabel(en, -1), isEmpty);
  });
}
