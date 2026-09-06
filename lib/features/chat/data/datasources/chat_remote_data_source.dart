import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatix/core/utils/logger.dart';

abstract class ChatRemoteDataSource {
  Stream<String> get messages;
  Future<void> connect();
  Future<void> sendMessage(String message);
  void disconnect();
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  WebSocketChannel? _channel;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  static const String _socketUrl = 'wss://echo.websocket.events/.ws';

  @override
  Stream<String> get messages => _messageController.stream;

  @override
  Future<void> connect() async {
    try {
      if (_channel != null) return;

      final uri = Uri.parse(_socketUrl);
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          Logger.debug('WebSocket received: $data');
          if (data is String) {
            _messageController.add(data);
          }
        },
        onError: (error) {
          Logger.error('WebSocket error', error);
        },
        onDone: () {
          Logger.info('WebSocket closed');
          _channel = null;
        },
      );
    } catch (e) {
      Logger.error('WebSocket Connection Failed', e);
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(String message) async {
    if (_channel == null) {
      await connect();
    }
    _channel?.sink.add(message);
  }

  @override
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
  }
}
