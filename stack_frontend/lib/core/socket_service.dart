import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _connected = false;

  String get serverUrl {
    if (kIsWeb) return '';
    return 'http://localhost:3001';
  }

  void connect(String userId) {
    if (_connected) return;

    _socket = io.io(
      serverUrl.isEmpty ? null : serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('🔌 Socket connected');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('🔌 Socket disconnected');
    });

    _socket!.onError((error) {
      debugPrint('Socket error: $error');
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _connected = false;
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  bool get isConnected => _connected;
}

final socketService = SocketService();
