import 'package:flutter/services.dart';

/// Read-only view of an app installed on the device.
class InstalledApp {
  final String packageName;
  final String versionName;

  const InstalledApp({required this.packageName, required this.versionName});
}

/// Queries the device's installed packages (name + version) via the
/// `com.revance.rd_manager/installer` platform channel.
class InstalledAppsService {
  static const _channel = MethodChannel('com.revance.rd_manager/installer');

  /// Returns every user-visible installed package with its version.
  /// Returns an empty map on any platform error (best-effort).
  static Future<Map<String, String>> getInstalledVersions() async {
    try {
      final result = await _channel
          .invokeMethod<List<dynamic>>('getInstalledApps');
      if (result == null) return {};

      return {
        for (final item in result)
          if (item is Map &&
              item['packageName'] is String &&
              item['versionName'] is String)
            item['packageName'] as String: item['versionName'] as String,
      };
    } on PlatformException {
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  /// Looks up the installed version for a single [packageName], or null.
  static Future<String?> getInstalledVersion(String packageName) async {
    final all = await getInstalledVersions();
    return all[packageName];
  }
}

/// Extracts the Android package name from a release-asset file name like
/// `app-revanced_v5.4.0_arm64-v8a.apk` (heuristic, mirrors the asset naming
/// used by ReVanced builds; falls back to hyphen-based prefixes).
String? packageNameFromAssetName(String assetName) {
  final base = assetName
      .replaceAll(RegExp(r'\.(apk|aab)$', caseSensitive: false), '');
  final parts = base.split('_');
  if (parts.isEmpty) return null;

  final head = parts.first.toLowerCase();
  // Strip a leading "app-" prefix ("app-revanced" -> "revanced").
  final candidate = head.startsWith('app-') ? head.substring(4) : head;
  if (candidate.isEmpty || candidate.length < 3) return null;
  return candidate;
}
