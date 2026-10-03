import 'dart:convert';

import 'package:eatapp/data/share/restaurant_import_reader.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:eatapp/data/supabase/account_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account backup', () {
    test('round-trips the account code and the restaurants', () {
      final String code = generateAccountCode();
      final String encoded = encodeAccountBackupFile(
        accountCode: code,
        restaurants: <RestaurantExport>[
          const RestaurantExport(
            name: 'Cal Ferran',
            cuisineType: 'mediterranean',
            priceRange: 2,
          ),
        ],
      );

      final Map<String, Object?> json =
          jsonDecode(encoded) as Map<String, Object?>;
      expect(json['format'], accountBackupFormat);

      final ImportOutcome outcome = readRestaurantImport(encoded);
      final ImportSuccess success = outcome as ImportSuccess;
      expect(success.accountCode, code);
      expect(success.restaurants.single.restaurant.name, 'Cal Ferran');
    });

    test('an ordinary restaurant share carries no account code', () {
      final ImportOutcome outcome = readRestaurantImport(
        encodeRestaurantShareFile(<RestaurantExport>[
          const RestaurantExport(
            name: 'Plain',
            cuisineType: 'italian',
            priceRange: 1,
          ),
        ]),
      );
      expect((outcome as ImportSuccess).accountCode, isNull);
    });

    test('a malformed code is dropped but the restaurants still import', () {
      final String encoded = jsonEncode(<String, Object?>{
        'format': accountBackupFormat,
        'account': <String, Object?>{'code': 'not-a-code'},
        'restaurants': <Object?>[
          const RestaurantExport(
            name: 'Kept',
            cuisineType: 'italian',
            priceRange: 1,
          ).toJson(),
        ],
      });

      final ImportSuccess success =
          readRestaurantImport(encoded) as ImportSuccess;
      expect(success.accountCode, isNull);
      expect(success.restaurants.single.restaurant.name, 'Kept');
    });
  });
}
