import 'dart:async';

abstract class TelemetrySource {
  Future<void> start();
  Future<void> stop();
  Stream<Map<String, dynamic>> get telemetryStream;
}

class EdgeTelemetrySource implements TelemetrySource {
  final String deviceId;
  final String vehicleId;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _timer;
  int _seq = 0;

  EdgeTelemetrySource({
    required this.deviceId,
    required this.vehicleId,
  });

  @override
  Stream<Map<String, dynamic>> get telemetryStream => _controller.stream;

  @override
  Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      _seq++;
      final payload = {
        'device_id': deviceId,
        'vehicle_id': vehicleId,
        'event_id': 'mobile-${DateTime.now().millisecondsSinceEpoch}-$_seq',
        'observed_at': DateTime.now().toUtc().toIsoformat(),
        'location': {
          'lat': 28.6139,
          'lng': 77.2090,
          'accuracy_m': 5.0,
        },
        'motion': {
          'speed_kph': 35.0,
          'heading_deg': 120.0,
        },
        'energy': {
          'soc_pct': 75.0,
          'estimated_range_km': 187.5,
          'charging': false,
        },
        'connectivity': {
          'network': '4G/LTE',
          'firmware': '0.3.1-mobile',
        },
        'seq': _seq,
      };
      _controller.add(payload);
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}

extension DateTimeIso on DateTime {
  String toIsoformat() => toUtc().toIso8601String();
}
