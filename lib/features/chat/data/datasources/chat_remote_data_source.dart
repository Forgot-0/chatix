import 'dart:async';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatix/core/utils/logger.dart';

/// ⚠️ **Placeholder — the real WebSocket layer (api-docs §7) is not built yet.**
///
/// This is still the template's demo socket, pointed at a public echo server.
/// It is wired to nothing: no provider constructs it and no screen reads it.
/// The REST half of the feature (§6) is complete and lives in
/// `chat_rest_data_source.dart`; messages there arrive by request/response only.
///
/// It now emits **raw frames as `String`** rather than parsed models. The demo
/// used a flat `MessageModel{text}` built by a `fromText` factory; that model
/// has since been rewritten to match the real `MessageDTO` (§6.4), which has no
/// meaningful mapping from an echoed text frame. Rather than invent one, the
/// parsing boundary is left undefined here — the §7 implementation will decode
/// `{type, payload}` envelopes into the proper models and give this interface
/// its real shape (`chat_message`, `attachment_success`, presence, etc.).
abstract class ChatRemoteDataSource {
  /// Raw text frames, exactly as received.
  Stream<String> get messages;
  Future<void> connect();
  Future<void> sendMessage(String message);
  void disconnect();
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  WebSocketChannel? _channel;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  // Using postman-echo or similar if echo.websocket.org is down
  // wss://echo.websocket.org is often unstable.
  // Using wss://echo.websocket.events/.ws
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
          // Forwarded verbatim — decoding belongs to the §7 implementation.
          if (data is String) {
            _messageController.add(data);
          }
        },
        onError: (error) {
          Logger.error('WebSocket error', error);
          // Reconnection logic could go here
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
