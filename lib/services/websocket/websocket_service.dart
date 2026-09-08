import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/env.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/vehicle/providers/vehicle_provider.dart';
import '../../features/alerts/providers/alert_provider.dart';
import 'websocket_events.dart';

enum WsStatus { disconnected, connecting, connected, reconnecting }

final wsStatusProvider = StateProvider<WsStatus>((ref) => WsStatus.disconnected);

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final wsService = WebSocketService(secureStorage, ref);

  ref.onDispose(() {
    wsService.disconnect();
  });

  return wsService;
});

class WebSocketService {
  final SecureStorage _storage;
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _staleCheckTimer;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;

  WebSocketService(this._storage, this._ref) {
    _startStaleChecker();
  }

  Future<void> connect() async {
    _manualDisconnect = false;
    _reconnectTimer?.cancel();

    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      _ref.read(wsStatusProvider.notifier).state = WsStatus.disconnected;
      return;
    }

    _ref.read(wsStatusProvider.notifier).state =
        _reconnectAttempts > 0 ? WsStatus.reconnecting : WsStatus.connecting;

    try {
      final wsUri = Uri.parse('${Env.wsBaseUrl}/ws/operator?token=$token');
      _channel = WebSocketChannel.connect(wsUri);

      // Await first event or ready state
      _subscription = _channel!.stream.listen(
        (dynamic message) {
          if (_ref.read(wsStatusProvider) != WsStatus.connected) {
            _ref.read(wsStatusProvider.notifier).state = WsStatus.connected;
            _reconnectAttempts = 0;
          }
          _handleMessage(message);
        },
        onDone: () {
          _ref.read(wsStatusProvider.notifier).state = WsStatus.disconnected;
          if (!_manualDisconnect) _scheduleReconnect();
        },
        onError: (err) {
          _ref.read(wsStatusProvider.notifier).state = WsStatus.disconnected;
          if (!_manualDisconnect) _scheduleReconnect();
        },
      );
    } catch (_) {
      _ref.read(wsStatusProvider.notifier).state = WsStatus.disconnected;
      if (!_manualDisconnect) _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      try {
        final json = jsonDecode(message) as Map<String, dynamic>;
        final event = WebSocketEvent.fromJson(json);

        if (event.isTelemetryUpdate) {
          _ref
              .read(activeVehicleProvider.notifier)
              .applyTelemetryUpdate(event.data);
        } else if (event.isAlert) {
          _ref.invalidate(departmentAlertsProvider);
        }
      } catch (_) {
        // Ignore unparseable frames safely
      }
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    _reconnectAttempts++;
    _ref.read(wsStatusProvider.notifier).state = WsStatus.reconnecting;

    // Exponential backoff capped at 30 seconds
    final delaySeconds = min(30, pow(2, min(_reconnectAttempts, 5)).toInt());
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  void _startStaleChecker() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final active = _ref.read(activeVehicleProvider);
      if (active.vehicle != null) {
        final isStale = active.vehicle!.isStale(Env.staleTelemetryThreshold);
        _ref.read(activeVehicleProvider.notifier).markStale(isStale);
      }
    });
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _staleCheckTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _ref.read(wsStatusProvider.notifier).state = WsStatus.disconnected;
  }
}
