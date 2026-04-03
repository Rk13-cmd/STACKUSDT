import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _connected = false;

  String get serverUrl => 'http://localhost:3001';

  void connect(String userId) {
    if (_connected) return;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      print('🔌 Socket connected');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      print('🔌 Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
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
