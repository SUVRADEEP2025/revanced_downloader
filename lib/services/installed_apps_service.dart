import 'package:flutter/services.dart';

/// Read-only view of an app installed on the device.
class InstalledApp {
  final String packageName;
  final String versionName;

  const InstalledApp({required this.packageName, required this.versionName});
}

class InstalledAppsService {
  static const _channel = MethodChannel('com.revance.rd_manager/installer');
  static Future<Map<String, String>> getInstalledVersions() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
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

  static Future<String?> getInstalledVersion(String packageName) async {
    final all = await getInstalledVersions();
    return all[packageName];
  }
}

String? packageNameFromAssetName(String assetName) {
  final base = assetName.replaceAll(
    RegExp(r'\.(apk|aab)$', caseSensitive: false),
    '',
  );
  final parts = base.split('_');
  if (parts.isEmpty) return null;

  final head = parts.first.toLowerCase();
  final candidate = head.startsWith('app-') ? head.substring(4) : head;
  if (candidate.isEmpty || candidate.length < 3) return null;
  return candidate;
}
