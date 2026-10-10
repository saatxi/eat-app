import 'package:eatapp/core/widgets/restaurant_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stored photo is 1600px across; the thumbnail must not decode it at that
/// size, or a long list holds a full-size bitmap for every row.
void main() {
  testWidgets('decodes a photo at twice its box, not at full size', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RestaurantThumbnail(
            cuisineKey: 'catalan',
            // Never read: the test only inspects the provider the widget built.
            photoPath: '/nonexistent/photo.jpg',
            size: 48,
          ),
        ),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    final ResizeImage provider = image.image as ResizeImage;
    expect(provider.width, 48 * 3 * 2);
    expect(provider.height, isNull, reason: 'the aspect ratio is kept');
  });
}
