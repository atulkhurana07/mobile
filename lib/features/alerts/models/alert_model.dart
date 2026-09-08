class AlertModel {
  final String id;
  final String vehicleId;
  final String alertType;
  final String severity;
  final String status;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolutionNote;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AlertModel({
    required this.id,
    required this.vehicleId,
    required this.alertType,
    required this.severity,
    required this.status,
    required this.firstSeen,
    required this.lastSeen,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolutionNote,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      alertType: json['alert_type'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      firstSeen: DateTime.parse(json['first_seen'].toString()),
      lastSeen: DateTime.parse(json['last_seen'].toString()),
      acknowledgedBy: json['acknowledged_by'] as String?,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'].toString())
          : null,
      resolutionNote: json['resolution_note'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  bool get isCritical => severity.toLowerCase() == 'critical';
  bool get isHigh => severity.toLowerCase() == 'high';
  bool get isActive => status.toLowerCase() == 'active';
  bool get isAcknowledged => status.toLowerCase() == 'acknowledged';

  String get alertTypeFormatted {
    switch (alertType) {
      case 'LOW_SOC':
        return 'Critical Low Battery';
      case 'LOW_RANGE':
        return 'Low Estimated Range';
      case 'OVERSPEED':
        return 'Speed Limit Exceeded';
      case 'HIGH_BATTERY_TEMP':
        return 'High Battery Temperature';
      case 'DIAGNOSTIC_FAULT':
        return 'Diagnostic Fault Code';
      case 'CHARGING_INTERRUPTED':
        return 'Charging Interrupted';
      case 'GEOFENCE_BREACH':
        return 'Geofence Boundary Breach';
      case 'VEHICLE_OFFLINE':
        return 'Vehicle Offline';
      default:
        return alertType.replaceAll('_', ' ');
    }
  }

  String get shortExplanation {
    if (metadata != null) {
      if (metadata!.containsKey('soc_pct')) {
        return 'Current battery is at ${metadata!['soc_pct']}%.';
      }
      if (metadata!.containsKey('speed_kph')) {
        return 'Speed recorded: ${metadata!['speed_kph']} km/h.';
      }
      if (metadata!.containsKey('battery_temp_c')) {
        return 'Battery temperature reached ${metadata!['battery_temp_c']}\u00B0C.';
      }
      if (metadata!.containsKey('estimated_range_km')) {
        return 'Remaining range estimated at ${metadata!['estimated_range_km']} km.';
      }
    }
    return 'Operational threshold exceeded. Safety protocol active.';
  }
}
