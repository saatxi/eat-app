import 'package:eatapp/core/utils/address_formatter.dart';
import 'package:eatapp/core/utils/search_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeForSearch', () {
    test('lowercases and strips accents', () {
      expect(normalizeForSearch('Mediterránea'), 'mediterranea');
      expect(normalizeForSearch('PAELLA'), 'paella');
      expect(normalizeForSearch('Índia'), 'india');
      expect(normalizeForSearch('Sant Julià de Lòria'), 'sant julia de loria');
      // The Catalan middle dot is part of the word, not a diacritic, so it
      // stays — the same thing the Android app's NFD folding does.
      expect(normalizeForSearch('Col·legi'), 'col·legi');
    });

    test('leaves already-folded text alone', () {
      expect(normalizeForSearch('can ferran'), 'can ferran');
    });
  });

  group('buildSearchText', () {
    test('joins the present fields, folded', () {
      expect(
        buildSearchText(
          name: 'Can Ferran',
          cuisineType: 'mediterranean',
          streetAddress: 'Carrer Nou',
          city: 'Mataró',
        ),
        'can ferran mediterranean carrer nou mataro',
      );
    });

    test('omits absent fields rather than leaving gaps', () {
      expect(
        buildSearchText(name: 'Alpha', cuisineType: 'italian'),
        'alpha italian',
      );
    });
  });

  group('escapeLikeWildcards', () {
    test('escapes the LIKE metacharacters and the escape char itself', () {
      expect(escapeLikeWildcards('100%'), r'100\%');
      expect(escapeLikeWildcards('a_b'), r'a\_b');
      expect(escapeLikeWildcards(r'a\b'), r'a\\b');
      expect(escapeLikeWildcards(r'50%_\'), r'50\%\_\\');
    });

    test('leaves ordinary text alone', () {
      expect(escapeLikeWildcards('bar ferran'), 'bar ferran');
    });
  });

  group('formatAddress', () {
    test('joins the non-blank components in order', () {
      expect(
        formatAddress(
          streetAddress: 'Carrer Nou 1',
          city: 'Mataró',
          region: 'Maresme',
          country: 'Spain',
        ),
        'Carrer Nou 1, Mataró, Maresme, Spain',
      );
    });

    test('skips blank and absent components', () {
      expect(
        formatAddress(streetAddress: '  ', city: 'Mataró', country: ''),
        'Mataró',
      );
    });

    test('returns null when nothing is left', () {
      expect(formatAddress(), isNull);
      expect(formatAddress(streetAddress: ' ', city: '\t'), isNull);
    });
  });
}
