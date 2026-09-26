import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'restaurant_import_reader.dart' show maxImportBytes;

/// A file's contents read into memory, or why it could not be.
///
/// Ported from `data/share/ContentFiles.kt`: the file is untrusted input handed
/// over by another app, so it is capped before it is parsed and every failure is
/// reported as a value rather than thrown at the screen.
sealed class ContentReadResult {
  const ContentReadResult();
}

final class ContentReadSuccess extends ContentReadResult {
  const ContentReadSuccess(this.text);

  final String text;
}

final class ContentReadTooLarge extends ContentReadResult {
  const ContentReadTooLarge();
}

final class ContentReadIoError extends ContentReadResult {
  const ContentReadIoError();
}

/// How many times a failing open is retried, and how long to wait between
/// tries: a `content://` file from Gmail can briefly fail to open right after
/// "Open with" is tapped, then succeed moments later.
const int _maxAttempts = 3;
const Duration _retryDelay = Duration(milliseconds: 300);
const int _bufferSize = 8 * 1024;

/// Reads the file at [path] as UTF-8 text, capped at [maxBytes].
Future<ContentReadResult> readFileCapped(
  String path, {
  int maxBytes = maxImportBytes,
}) async {
  for (int attempt = 0; attempt < _maxAttempts; attempt++) {
    final ContentReadResult result = await _readOnce(path, maxBytes);
    if (result is! ContentReadIoError || attempt == _maxAttempts - 1) {
      return result;
    }
    await Future<void>.delayed(_retryDelay);
  }
  return const ContentReadIoError();
}

Future<ContentReadResult> _readOnce(String path, int maxBytes) async {
  RandomAccessFile? handle;
  try {
    handle = await File(path).open();
    final BytesBuilder builder = BytesBuilder(copy: false);
    final Uint8List buffer = Uint8List(_bufferSize);
    while (true) {
      final int read = await handle.readInto(buffer);
      if (read <= 0) {
        break;
      }
      builder.add(Uint8List.sublistView(buffer, 0, read));
      if (builder.length > maxBytes) {
        return const ContentReadTooLarge();
      }
    }
    // allowMalformed mirrors the Android reader, which decoded with UTF-8's
    // replacement behaviour rather than failing on a stray byte.
    return ContentReadSuccess(
      utf8.decode(builder.takeBytes(), allowMalformed: true),
    );
  } on FileSystemException {
    return const ContentReadIoError();
  } finally {
    await handle?.close();
  }
}
