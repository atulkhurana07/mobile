class ApiEndpoints {
  // Auth
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String me = '/api/auth/me';

  // Operator Vehicles
  static const String operatorVehicles = '/api/operator/vehicles';
  static String operatorVehicle(String id) => '/api/operator/vehicles/$id';
  static String operatorVehicleTrack(String id) => '/api/operator/vehicles/$id/track';

  // Operator Alerts
  static const String operatorAlerts = '/api/operator/alerts';
  static String operatorAlertAck(String id) => '/api/operator/alerts/$id/ack';

  // Telemetry Ingest
  static const String ingestTelemetry = '/api/ingest/telemetry';

  // Public
  static const String publicChargingCenters = '/api/public/charging-centers';
  static const String publicVehicles = '/api/public/vehicles';
  static const String health = '/health';

  // WebSocket
  static String operatorWs(String token) => '/ws/operator?token=$token';
}
