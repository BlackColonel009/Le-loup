import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'public_content.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.installed,
    required this.url,
    required this.id,
  });
  final String version, installed, id;
  final Uri url;
}

/// Numeric comparison (0.10.0 > 0.9.0), including an optional Android build.
int? compareAppVersions(String remote, String installed, String build) {
  List<int>? parse(String s) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$').firstMatch(s);
    return m == null
        ? null
        : [for (var i = 1; i <= 4; i++) int.parse(m.group(i) ?? '0')];
  }

  final wanted = parse(remote), current = parse(installed);
  if (wanted == null || current == null) return null;
  current[3] = int.tryParse(build) ?? current[3];
  final length = remote.contains('+') ? 4 : 3;
  for (var i = 0; i < length; i++) {
    final c = wanted[i].compareTo(current[i]);
    if (c != 0) return c;
  }
  return 0;
}

Future<AppRelease?> checkAppUpdate({
  Future<Map<String, dynamic>> Function()? fetch,
  Future<PackageInfo> Function()? package,
  String? platform,
}) async {
  platform ??= defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'other';
  // The administrator's existing public link distributes an Android APK.
  // Never send a Windows/iOS player to an Android installer.
  if (platform != 'android') return null;
  final data = await (fetch?.call() ?? loadPublicContent('app-update')).timeout(
    const Duration(seconds: 4),
  );
  if (data['enabled'] != true || data['platform'] != platform) return null;
  final version = data['version'],
      rawUrl = data['download_url'],
      id = data['release_id'];
  if (version is! String ||
      rawUrl is! String ||
      id is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
    return null;
  }
  final url = Uri.tryParse(rawUrl);
  if (url == null ||
      url.scheme != 'https' ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty ||
      RegExp(r'\s').hasMatch(rawUrl)) {
    return null;
  }
  final info = await (package?.call() ?? PackageInfo.fromPlatform());
  final comparison = compareAppVersions(
    version,
    info.version,
    info.buildNumber,
  );
  if (comparison == null || comparison <= 0) return null;
  final release = AppRelease(
    version: version,
    installed: '${info.version}+${info.buildNumber}',
    url: url,
    id: id,
  );
  return release;
}
