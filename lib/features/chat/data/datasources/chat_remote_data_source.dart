import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatix/core/utils/logger.dart';

/// ⚠️ **Placeholder — still the template's echo-server demo.**
///
/// The real chat WebSocket protocol (api-docs §7: `ws.*` service frames,
/// heartbeat, `new_message` / `attachment_success` domain events, resume by
/// `last_seq`) is deliberately **out of scope for the REST prompt** and will
/// replace this file wholesale.
///
/// Only one thing changed here versus the template: the stream used to emit
/// `MessageModel.fromText(...)`, a helper that belonged to the old flat
/// `MessageModel {text}`. That model is now the real `MessageDTO` (§6.4) —
/// `id`, `seq`, `attachments`, nested `reply_to` — and cannot be conjured from
/// a bare echo string, so the demo now surfaces raw frames as [String].
/// Nothing in the REST feature imports this class.
abstract class ChatRemoteDataSource {
  /// Raw text frames, exactly as received. Prompt 5 replaces this with a
  /// stream of parsed §7.4 events.
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
          // Expecting simple text echo from this server
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
