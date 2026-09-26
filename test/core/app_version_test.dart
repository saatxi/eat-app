import 'package:eatapp/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the platform's version string is boiled down to.
///
/// It is `git describe --tags --always` — stamped into the Android manifest by
/// `android/app/build.gradle.kts`, leading `v` stripped — so every shape that
/// build can produce is worth pinning down rather than trusting to a
/// `split('-')`. Settings shows the bare version of each and never the describe
/// suffix: how many commits past the tag, and which sha, are the build's
/// business rather than the reader's.
void main() {
  group('AppVersion', () {
    test('a tagged build reads as its own version', () {
      expect(const AppVersion('3.0.1').releaseVersion, '3.0.1');
    });

    test('a build past the tag drops the count and the sha', () {
      expect(const AppVersion('3.0.1-13-ge7d973b').releaseVersion, '3.0.1');
    });

    test('a build from a modified tree drops the dirty marker too', () {
      expect(
        const AppVersion('3.0.1-13-ge7d973b-dirty').releaseVersion,
        '3.0.1',
      );
    });

    test('before the first tag, the describe string is the version', () {
      expect(const AppVersion('559a7d4-dirty').releaseVersion, '559a7d4');
    });

    test('a checkout git could not read still reads', () {
      expect(const AppVersion('0.0.0').releaseVersion, '0.0.0');
    });
  });
}
