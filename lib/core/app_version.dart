import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The running app's own version.
///
/// On Android it is `git describe --tags --always` with its leading `v`
/// stripped, which `android/app/build.gradle.kts` stamps into the manifest at
/// build time; on iOS it is the bundle's `CFBundleShortVersionString`. Either
/// way the platform is carrying it, and this reads it back rather than keeping
/// a copy in Dart that could disagree with the build it is running in.
///
/// What `describe` adds past the tag — how many commits, which sha, a `-dirty`
/// for a modified working tree — is build detail rather than version, so
/// [releaseVersion] drops it: the settings screen says "3.0.1" whether it is
/// running the tagged build or `3.0.1-13-ge7d973b-dirty`.
@immutable
class AppVersion {
  const AppVersion(this.version);

  /// Reads what the platform reports for the app that is running.
  static Future<AppVersion> load() async =>
      AppVersion((await PackageInfo.fromPlatform()).version);

  /// The string as the platform holds it, describe suffix and all.
  final String version;

  /// The bare semantic version: everything before the first `-`, so `3.0.1`
  /// comes out of `3.0.1`, of `3.0.1-13-ge7d973b` and of
  /// `3.0.1-13-ge7d973b-dirty` alike. A checkout with no tag in reach reads as
  /// its own short sha, and one with no git at all as `0.0.0`.
  String get releaseVersion => version.split('-').first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppVersion && other.version == version;

  @override
  int get hashCode => version.hashCode;

  @override
  String toString() => 'AppVersion($version)';
}
