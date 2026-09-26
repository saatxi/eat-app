// Regenerates every launcher icon and splash logo from the Android vector
// drawables, which are the artwork's single source of truth:
//
//     android/app/src/main/res/drawable/ic_launcher_background.xml
//     android/app/src/main/res/drawable/ic_launcher_foreground.xml
//
// Run it by hand after touching either of those:
//
//     flutter test scripts/generate_app_icons.dart
//
// It rasterises through `dart:ui`, which only exists inside the Flutter engine,
// which is why it runs as a test rather than under `dart run`. The filename
// deliberately does not end in `_test.dart`: `flutter test` on its own skips it,
// because it writes files and the suite must not.
//
// What it writes:
//   android/app/src/main/res/mipmap-*/ic_launcher.png   (API 23 to 25, which
//                                                        have no adaptive icon)
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png (every size Contents.json
//                                                        asks for)
//   ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png (the logo the launch
//                                                        storyboard centres)
//
// Android 26 and up draws `mipmap-anydpi-v26/ic_launcher.xml` instead, and the
// pre-12 splash is the layer-list in `drawable/launch_background.xml`: both take
// these same two vectors directly, so nothing here needs to touch them.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// One filled shape of the artwork, in the drawables' own 108x108 space.
class _Shape {
  const _Shape(this.path, this.color);

  final Path path;
  final Color color;
}

/// The artwork the icon is built from: the plate, and the cutlery over it.
class _Artwork {
  const _Artwork({
    required this.plateColor,
    required this.pivotX,
    required this.pivotY,
    required this.adaptiveScale,
    required this.cutlery,
  });

  final Color plateColor;
  final double pivotX;
  final double pivotY;

  /// The `<group>` scale the foreground vector carries, which is what keeps the
  /// cutlery inside the safe circle an Android launcher mask is guaranteed to
  /// leave visible.
  final double adaptiveScale;

  final List<_Shape> cutlery;

  /// The scale a *flat* icon needs for its cutlery to read the same size as the
  /// masked one does: the mask crops the 108x108 artwork to its inner 72x72, so
  /// the artwork only appears that big when the plate is the mask.
  double get flatScale => adaptiveScale * 108 / 72;
}

const String _resDirectory = 'android/app/src/main/res';
const String _backgroundVector = '$_resDirectory/drawable/ic_launcher_background.xml';
const String _foregroundVector = '$_resDirectory/drawable/ic_launcher_foreground.xml';
const String _iosAssets = 'ios/Runner/Assets.xcassets';

/// Every launcher size Android asks for below API 26, in pixels.
const Map<String, int> _androidLegacySizes = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// Every size `AppIcon.appiconset/Contents.json` asks for, in pixels.
const Map<String, int> _iosIconSizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

/// The launch screen's logo, at the three scales the imageset carries.
const Map<String, int> _iosLaunchSizes = <String, int>{
  'LaunchImage.png': 120,
  'LaunchImage@2x.png': 240,
  'LaunchImage@3x.png': 360,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('regenerates every launcher icon and splash logo', () async {
    final _Artwork artwork = _readArtwork();

    for (final MapEntry<String, int> entry in _androidLegacySizes.entries) {
      await _write(
        '$_resDirectory/${entry.key}/ic_launcher.png',
        artwork,
        entry.value,
      );
    }
    for (final MapEntry<String, int> entry in _iosIconSizes.entries) {
      await _write(
        '$_iosAssets/AppIcon.appiconset/${entry.key}',
        artwork,
        entry.value,
      );
    }
    for (final MapEntry<String, int> entry in _iosLaunchSizes.entries) {
      await _write(
        '$_iosAssets/LaunchImage.imageset/${entry.key}',
        artwork,
        entry.value,
      );
    }
  });
}

/// Paints one flat icon of [size] pixels and writes it to [path].
///
/// Flat means what a launcher shows below API 26 and what iOS masks with its own
/// squircle itself: the plate as the whole square, with the cutlery over it at
/// [flatScale]. No transparency anywhere — neither store accepts it.
Future<void> _write(String path, _Artwork artwork, int size) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.scale(size / 108);

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 108, 108),
    Paint()..color = artwork.plateColor,
  );

  canvas.save();
  canvas.translate(artwork.pivotX, artwork.pivotY);
  canvas.scale(artwork.flatScale);
  canvas.translate(-artwork.pivotX, -artwork.pivotY);
  for (final _Shape shape in artwork.cutlery) {
    canvas.drawPath(shape.path, Paint()..color = shape.color);
  }
  canvas.restore();

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(size, size);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  if (bytes == null) {
    throw StateError('the engine produced no PNG for $path');
  }

  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
}

/// Reads the two drawables into the shapes and transform they describe.
_Artwork _readArtwork() {
  final String background = File(_backgroundVector).readAsStringSync();
  final String foreground = File(_foregroundVector).readAsStringSync();

  return _Artwork(
    plateColor: _firstColor(background),
    pivotX: _doubleAttribute(foreground, 'pivotX'),
    pivotY: _doubleAttribute(foreground, 'pivotY'),
    adaptiveScale: _doubleAttribute(foreground, 'scaleX'),
    cutlery: _shapes(foreground),
  );
}

/// Every `<path>` in [vector], in document order, as a filled shape.
List<_Shape> _shapes(String vector) {
  final RegExp path = RegExp(r'<path\b[^>]*>');
  return <_Shape>[
    for (final Match match in path.allMatches(vector))
      _Shape(
        _path(match.group(0)!),
        _firstColor(match.group(0)!),
      ),
  ];
}

/// The first `android:fillColor="#rrggbb"` in [xml], as a colour.
Color _firstColor(String xml) {
  final Match? match = RegExp(
    r'android:fillColor="#([0-9a-fA-F]{6})"',
  ).firstMatch(xml);
  if (match == null) {
    throw StateError('no fill colour in:\n$xml');
  }
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// The value of `android:[name]` in [xml].
double _doubleAttribute(String xml, String name) {
  final Match? match = RegExp(
    'android:$name="(-?\\d+(?:\\.\\d+)?)"',
  ).firstMatch(xml);
  if (match == null) {
    throw StateError('no android:$name in:\n$xml');
  }
  return double.parse(match.group(1)!);
}

/// Builds a [Path] from one `android:pathData` string.
///
/// Only the commands the two vectors actually use, so this stays a translator
/// rather than a general SVG parser. Anything else throws, which is the point:
/// extending the artwork means teaching this about the new command.
Path _path(String pathData) {
  final RegExpMatch? match = RegExp(
    r'android:pathData="([^"]*)"',
  ).firstMatch(pathData);
  if (match == null) {
    throw StateError('no pathData in:\n$pathData');
  }
  final List<String> tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+')
      .allMatches(match.group(1)!)
      .map((Match token) => token.group(0)!)
      .toList();

  final Path path = Path();
  double x = 0;
  double y = 0;
  int index = 0;
  String command = '';
  double next() => double.parse(tokens[index++]);

  while (index < tokens.length) {
    if (RegExp(r'[A-Za-z]').hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    switch (command) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'h':
        x += next();
        path.lineTo(x, y);
      case 'v':
        y += next();
        path.lineTo(x, y);
      case 'C':
        final double x1 = next();
        final double y1 = next();
        final double x2 = next();
        final double y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'A':
        final double radius = next();
        next();
        index += 2; // x-axis rotation and the large-arc flag
        final double sweep = next();
        final double endX = next();
        final double endY = next();
        path.arcToPoint(
          Offset(endX, endY),
          radius: Radius.circular(radius),
          clockwise: sweep == 1,
        );
        x = endX;
        y = endY;
      case 'Z':
      case 'z':
        path.close();
      default:
        throw StateError('unsupported path command "$command"');
    }
  }
  return path;
}
