import 'dart:convert';
import 'package:rd_manager/notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'secrets.dart';
import 'package:rd_manager/services/logger.dart';

class WebSocketService {
  static WebSocketChannel? _channel;

  static void init() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ntfyHost));
      _channel!.stream.listen(
        (message) {
          if (message.contains('sequence_id')) {
            try {
              final Map<String, dynamic> jsonMessage = json.decode(message);
              final String? messageContent = jsonMessage['message'] as String?;
              final String title =
                  jsonMessage['title'] as String? ?? 'New Message';
              if (messageContent != null) {
                NotificationsService.showNotification(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  title: title,
                  body: messageContent,
                );
              }
            } catch (e) {
              AppLog.error('Failed to parse websocket message', exception: e);
            }
          }
        },
        onError: (error) {
          AppLog.error('Websocket error', exception: error);
        },
        onDone: () {
          AppLog.info('WebSocket Connection Closed');
        },
      );
    } catch (e) {
      AppLog.error('Failed to init websocket', exception: e);
    }
  }

  static void dispose() {
    _channel?.sink.close();
  }

  static void sendMessage(String message) {
    _channel?.sink.add(message);
  }
}
