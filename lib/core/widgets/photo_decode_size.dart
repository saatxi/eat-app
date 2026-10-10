import 'package:flutter/widgets.dart';

/// The width a stored photo is decoded at, so it costs memory for the pixels
/// that are actually drawn rather than for the full 1600px it is stored at.
///
/// A full-size bitmap is roughly 7.7 MB in memory; decoding every photo of a
/// long Journal at that size, for a thumbnail a few dozen pixels across, is
/// what made the list heavy to scroll. Each is passed as an `Image.file`
/// `cacheWidth`, which bounds the width only — the height follows the photo's
/// own aspect ratio, so nothing is ever stretched.

/// For a square [size] box drawn with `BoxFit.cover`: twice the box, so a photo
/// up to 2:1 still covers it at full sharpness once its height is scaled down
/// with the width.
int thumbnailCacheWidth(BuildContext context, double size) =>
    (size * MediaQuery.devicePixelRatioOf(context) * 2).round();

/// For a photo drawn at most as wide as the screen.
int screenCacheWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
        .round();
