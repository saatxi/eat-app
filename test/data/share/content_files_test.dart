import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eatapp/data/share/content_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('eatapp_content_test');
  });

  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  Future<String> write(String name, List<int> bytes) async {
    final File file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('reads a small file back as UTF-8 text', () async {
    final String path = await write('share.eatapp', utf8.encode('{"format":"x"}'));
    final ContentReadResult result = await readFileCapped(path);
    expect(result, isA<ContentReadSuccess>());
    expect((result as ContentReadSuccess).text, '{"format":"x"}');
  });

  test('rejects a file that is over the cap', () async {
    final String path = await write('big.eatapp', Uint8List(64));
    final ContentReadResult result = await readFileCapped(path, maxBytes: 16);
    expect(result, isA<ContentReadTooLarge>());
  });

  test('a missing file reports an IO error once the retries run out', () async {
    final ContentReadResult result = await readFileCapped(
      '${dir.path}${Platform.pathSeparator}missing.eatapp',
    );
    expect(result, isA<ContentReadIoError>());
  });
}
