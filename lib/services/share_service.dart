import 'package:flutter/services.dart';

/// Shares a URL via the Android share sheet (ACTION_SEND chooser).
class ShareService {
  static const _channel = MethodChannel('com.revance.rd_manager/installer');

  /// Opens the system share sheet for [url]. Throws [PlatformException] on
  /// failure (e.g. no activity found).
  static Future<void> shareUrl(String url) async {
    await _channel.invokeMethod('shareUrl', {'url': url});
  }
}
