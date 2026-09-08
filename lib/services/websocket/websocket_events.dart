class WebSocketEvent {
  final String type;
  final Map<String, dynamic> data;

  const WebSocketEvent({required this.type, required this.data});

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String? ?? 'unknown',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
    );
  }

  bool get isTelemetryUpdate => type == 'telemetry_update' || type == 'telemetry';
  bool get isAlert => type == 'alert';
}
