class VehicleModel {
  final String id;
  final String vehicleCode;
  final String vehicleType;
  final String departmentId;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final double? speedKph;
  final double? headingDeg;
  final double? socPct;
  final double? estimatedRangeKm;
  final bool? charging;
  final String? connectivityStatus;
  final DateTime? lastSeen;

  const VehicleModel({
    required this.id,
    required this.vehicleCode,
    required this.vehicleType,
    required this.departmentId,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.speedKph,
    this.headingDeg,
    this.socPct,
    this.estimatedRangeKm,
    this.charging,
    this.connectivityStatus,
    this.lastSeen,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      vehicleCode: json['vehicle_code'] as String,
      vehicleType: json['vehicle_type'] as String,
      departmentId: json['department_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      speedKph: (json['speed_kph'] as num?)?.toDouble(),
      headingDeg: (json['heading_deg'] as num?)?.toDouble(),
      socPct: (json['soc_pct'] as num?)?.toDouble(),
      estimatedRangeKm: (json['estimated_range_km'] as num?)?.toDouble(),
      charging: json['charging'] as bool?,
      connectivityStatus: json['connectivity_status'] as String?,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
    );
  }

  VehicleModel copyWith({
    String? id,
    String? vehicleCode,
    String? vehicleType,
    String? departmentId,
    bool? isActive,
    double? latitude,
    double? longitude,
    double? speedKph,
    double? headingDeg,
    double? socPct,
    double? estimatedRangeKm,
    bool? charging,
    String? connectivityStatus,
    DateTime? lastSeen,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      vehicleCode: vehicleCode ?? this.vehicleCode,
      vehicleType: vehicleType ?? this.vehicleType,
      departmentId: departmentId ?? this.departmentId,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKph: speedKph ?? this.speedKph,
      headingDeg: headingDeg ?? this.headingDeg,
      socPct: socPct ?? this.socPct,
      estimatedRangeKm: estimatedRangeKm ?? this.estimatedRangeKm,
      charging: charging ?? this.charging,
      connectivityStatus: connectivityStatus ?? this.connectivityStatus,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool isStale(Duration threshold) {
    if (lastSeen == null) return true;
    final diff = DateTime.now().toUtc().difference(lastSeen!.toUtc());
    return diff > threshold;
  }

  String get operationalStatus {
    if (charging == true) return 'CHARGING';
    if (speedKph != null && speedKph! > 0.5) return 'MOVING';
    if (connectivityStatus == 'offline') return 'OFFLINE';
    return 'IDLE';
  }

  String get vehicleTypeFormatted {
    switch (vehicleType) {
      case 'electric_bus':
        return 'Electric Bus';
      case 'fire_ev':
        return 'Fire Emergency EV';
      case 'utility_ev':
        return 'Utility Maintenance EV';
      case 'ambulance_ev':
        return 'Ambulance EV';
      default:
        return vehicleType.replaceAll('_', ' ').toUpperCase();
    }
  }
}
