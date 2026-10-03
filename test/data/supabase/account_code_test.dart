import 'dart:math';

import 'package:eatapp/data/supabase/account_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateAccountCode', () {
    test('is 16 characters drawn only from the alphabet', () {
      for (int i = 0; i < 50; i++) {
        final String code = generateAccountCode();
        expect(code.length, accountCodeLength);
        for (final String char in code.split('')) {
          expect(accountCodeAlphabet.contains(char), isTrue);
        }
      }
    });

    test('never emits the ambiguous glyphs', () {
      for (int i = 0; i < 200; i++) {
        final String code = generateAccountCode();
        for (final String glyph in <String>['O', 'I', 'L', '0', '1']) {
          expect(code.contains(glyph), isFalse);
        }
      }
    });

    test('is reproducible under a seeded generator', () {
      expect(
        generateAccountCode(random: Random(1)),
        generateAccountCode(random: Random(1)),
      );
    });
  });

  group('normalizeAccountCode', () {
    test('uppercases and drops separators', () {
      expect(normalizeAccountCode('abcd-efgh 2345'), 'ABCDEFGH2345');
    });
  });

  group('isValidAccountCode', () {
    test('accepts a generated code, grouped or not', () {
      final String code = generateAccountCode();
      expect(isValidAccountCode(code), isTrue);
      expect(isValidAccountCode(formatAccountCode(code)), isTrue);
    });

    test('rejects a wrong length or a character outside the alphabet', () {
      expect(isValidAccountCode('ABC'), isFalse);
      // 16 characters, but the trailing O is not in the alphabet.
      expect(isValidAccountCode('${'A'.padRight(15, 'A')}O'), isFalse);
    });
  });

  group('formatAccountCode', () {
    test('groups every four characters with hyphens', () {
      expect(formatAccountCode('ABCDEFGH2345WXYZ'), 'ABCD-EFGH-2345-WXYZ');
    });
  });

  group('maskAccountCode', () {
    test('keeps the ends and hides the middle groups', () {
      expect(maskAccountCode('ABCDEFGH2345WXYZ'), 'ABCD-••••-••••-WXYZ');
    });
  });
}
