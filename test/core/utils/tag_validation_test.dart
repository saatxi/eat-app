import 'package:eatapp/core/utils/tag_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeTagName', () {
    test('trims and keeps an ordinary name', () {
      expect(normalizeTagName('Terraza'), 'Terraza');
      expect(normalizeTagName('  Terraza  '), 'Terraza');
      expect(normalizeTagName('Para grupos'), 'Para grupos');
    });

    test('treats blank as no tag at all', () {
      expect(normalizeTagName(''), isNull);
      expect(normalizeTagName('   '), isNull);
    });

    test('is exactly as long as the limit, and not a character longer', () {
      final String allowed = 'a' * maxTagNameLength;
      final String tooLong = 'a' * (maxTagNameLength + 1);

      expect(normalizeTagName(allowed), allowed);
      expect(normalizeTagName(tooLong), isNull);
    });

    test('refuses a comma, which is what keeps a joined list splittable', () {
      expect(normalizeTagName('a,b'), isNull);
      expect(normalizeTagName('a, b'), isNull);
      expect(normalizeTagName('Terraza, para grupos'), isNull);
    });
  });

  group('normalizeTagNames', () {
    test('drops what a single name would be dropped for', () {
      expect(
        normalizeTagNames(<String>['Terraza', '', '  ', 'a,b', 'Celiac']),
        <String>['Terraza', 'Celiac'],
      );
    });

    test('folds duplicates case-insensitively, keeping the first spelling', () {
      expect(
        normalizeTagNames(<String>['Terraza', 'terraza', 'TERRAZA', 'Vegà']),
        <String>['Terraza', 'Vegà'],
      );
    });

    test('caps the list so one untrusted row cannot create unbounded junk', () {
      final List<String> tooMany = <String>[
        for (int i = 0; i < maxTagsPerRestaurant + 5; i++) 'tag $i',
      ];

      final List<String> normalized = normalizeTagNames(tooMany);

      expect(normalized, hasLength(maxTagsPerRestaurant));
      expect(normalized.first, 'tag 0');
      expect(normalized.last, 'tag ${maxTagsPerRestaurant - 1}');
    });

    test('keeps the order it was given', () {
      expect(
        normalizeTagNames(<String>['zeta', 'Alpha', 'medio']),
        <String>['zeta', 'Alpha', 'medio'],
      );
    });

    test('an empty list stays empty', () {
      expect(normalizeTagNames(const <String>[]), isEmpty);
    });
  });
}
