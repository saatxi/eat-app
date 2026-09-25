import 'package:eatapp/core/utils/link_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeWebsite', () {
    test('assumes https for a bare host', () {
      expect(normalizeWebsite('example.com'), 'https://example.com');
      expect(normalizeWebsite('www.example.com/path?a=1'), 'https://www.example.com/path?a=1');
    });

    test('keeps an http or https URL as it was', () {
      expect(normalizeWebsite('https://example.com'), 'https://example.com');
      expect(normalizeWebsite('http://example.com'), 'http://example.com');
      expect(
        normalizeWebsite('HTTPS://EXAMPLE.COM'),
        'HTTPS://EXAMPLE.COM',
        reason: 'only the scheme is lowercased for the check, not the value',
      );
    });

    test('trims, and treats blank as absent', () {
      expect(normalizeWebsite('  https://example.com  '), 'https://example.com');
      expect(normalizeWebsite(null), isNull);
      expect(normalizeWebsite(''), isNull);
      expect(normalizeWebsite('   '), isNull);
    });

    test('refuses every scheme it does not recognise', () {
      // The whole point of the whitelist: these would otherwise be handed to
      // the system as an actionable URI.
      expect(normalizeWebsite('javascript:alert(1)'), isNull);
      expect(normalizeWebsite('intent://scan/#Intent;scheme=zxing;end'), isNull);
      expect(normalizeWebsite('file:///etc/passwd'), isNull);
      expect(normalizeWebsite('content://com.other.app/data'), isNull);
      expect(normalizeWebsite('mailto:someone@example.com'), isNull);
      expect(normalizeWebsite('ftp://example.com'), isNull);
      expect(normalizeWebsite('data:text/html,<script>'), isNull);
    });

    test('refuses a bare host carrying a port, as the Android app does', () {
      // Carried over deliberately rather than quietly improved: the scheme
      // pattern sees "example.com:" and reads it as an unknown scheme, so
      // "example.com:8080" is rejected. Behavioural parity matters more here
      // than fixing the wart.
      expect(normalizeWebsite('example.com:8080'), isNull);
      expect(normalizeWebsite('http://example.com:8080'), 'http://example.com:8080');
    });
  });

  group('normalizeInstagramHandle', () {
    test('accepts a handle with or without the leading @, and trims', () {
      expect(normalizeInstagramHandle('saatxi'), 'saatxi');
      expect(normalizeInstagramHandle('@saatxi'), 'saatxi');
      expect(normalizeInstagramHandle('  @saatxi  '), 'saatxi');
      expect(normalizeInstagramHandle('saatxi.dev'), 'saatxi.dev');
      expect(normalizeInstagramHandle('user_name'), 'user_name');
    });

    test('is exactly as long as Instagram allows, and not a character longer', () {
      final String thirty = 'a' * 30;
      final String thirtyOne = 'a' * 31;

      expect(normalizeInstagramHandle(thirty), thirty);
      expect(normalizeInstagramHandle(thirtyOne), isNull);
    });

    test('refuses a URL, a stray @ and any character outside the handle set', () {
      expect(normalizeInstagramHandle('https://instagram.com/saatxi'), isNull);
      expect(normalizeInstagramHandle('instagram.com/saatxi'), isNull);
      expect(normalizeInstagramHandle('@@saatxi'), isNull);
      expect(normalizeInstagramHandle('with-dash'), isNull);
      expect(normalizeInstagramHandle('with space'), isNull);
    });

    test('treats blank as absent', () {
      expect(normalizeInstagramHandle(null), isNull);
      expect(normalizeInstagramHandle(''), isNull);
      expect(normalizeInstagramHandle('@'), isNull);
      expect(normalizeInstagramHandle('   '), isNull);
    });

    test('the built URL is the base plus a handle that was already validated', () {
      expect(instagramUrl('saatxi'), 'https://instagram.com/saatxi');
    });
  });
}
