import 'package:flutter_test/flutter_test.dart';
import 'package:chargeease_mobile/features/auth/models/user_model.dart';
import 'package:chargeease_mobile/features/vehicle/models/vehicle_model.dart';
import 'package:chargeease_mobile/features/alerts/models/alert_model.dart';
import 'package:chargeease_mobile/services/websocket/websocket_events.dart';

void main() {
  group('UserModel Tests', () {
    test('Correctly parses UserMeResponse and evaluates RBAC', () {
      final userJson = {
        'id': 'u-001',
        'email': 'transport@chargeease.gov',
        'full_name': 'Transport Officer',
        'role': 'dispatcher',
        'department_id': 'dept-001',
        'department_name': 'Transport Department',
        'is_active': true,
      };

      final user = UserModel.fromJson(userJson);
      expect(user.id, 'u-001');
      expect(user.fullName, 'Transport Officer');
      expect(user.isDispatcher, isTrue);
      expect(user.canAcknowledgeAlerts, isTrue);
    });

    test('Maintenance and Analyst roles cannot acknowledge alerts', () {
      final maintenanceUser = UserModel(
        id: 'u-002',
        email: 'tech@chargeease.gov',
        fullName: 'Field Tech',
        role: 'maintenance',
        isActive: true,
      );

      final analystUser = UserModel(
        id: 'u-003',
        email: 'analyst@chargeease.gov',
        fullName: 'Fleet Analyst',
        role: 'analyst',
        isActive: true,
      );

      expect(maintenanceUser.canAcknowledgeAlerts, isFalse);
      expect(analystUser.canAcknowledgeAlerts, isFalse);
    });
  });

  group('VehicleModel Tests', () {
    test('Calculates operational status correctly', () {
      final chargingVehicle = VehicleModel(
        id: 'v-001',
        vehicleCode: 'bus-001',
        vehicleType: 'electric_bus',
        departmentId: 'dept-001',
        isActive: true,
        socPct: 60.0,
        charging: true,
        speedKph: 0.0,
      );
      expect(chargingVehicle.operationalStatus, 'CHARGING');

      final movingVehicle = VehicleModel(
        id: 'v-002',
        vehicleCode: 'bus-002',
        vehicleType: 'electric_bus',
        departmentId: 'dept-001',
        isActive: true,
        socPct: 75.0,
        charging: false,
        speedKph: 45.0,
      );
      expect(movingVehicle.operationalStatus, 'MOVING');

      final idleVehicle = VehicleModel(
        id: 'v-003',
        vehicleCode: 'bus-003',
        vehicleType: 'electric_bus',
        departmentId: 'dept-001',
        isActive: true,
        socPct: 80.0,
        charging: false,
        speedKph: 0.0,
      );
      expect(idleVehicle.operationalStatus, 'IDLE');
    });

    test('Correctly detects stale telemetry', () {
      final freshVehicle = VehicleModel(
        id: 'v-001',
        vehicleCode: 'bus-001',
        vehicleType: 'electric_bus',
        departmentId: 'dept-001',
        isActive: true,
        lastSeen: DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
      );
      expect(freshVehicle.isStale(const Duration(seconds: 30)), isFalse);

      final staleVehicle = VehicleModel(
        id: 'v-002',
        vehicleCode: 'bus-002',
        vehicleType: 'electric_bus',
        departmentId: 'dept-001',
        isActive: true,
        lastSeen: DateTime.now().toUtc().subtract(const Duration(seconds: 45)),
      );
      expect(staleVehicle.isStale(const Duration(seconds: 30)), isTrue);
    });
  });

  group('AlertModel Tests', () {
    test('Parses AlertResponse and categorizes severity', () {
      final alertJson = {
        'id': 'a-001',
        'vehicle_id': 'v-001',
        'alert_type': 'LOW_SOC',
        'severity': 'critical',
        'status': 'active',
        'first_seen': '2026-08-31T00:00:00Z',
        'last_seen': '2026-08-31T00:05:00Z',
        'metadata': {'soc_pct': 8.5},
      };

      final alert = AlertModel.fromJson(alertJson);
      expect(alert.id, 'a-001');
      expect(alert.isCritical, isTrue);
      expect(alert.isActive, isTrue);
      expect(alert.alertTypeFormatted, 'Critical Low Battery');
      expect(alert.shortExplanation, contains('8.5%'));
    });
  });

  group('WebSocketEvent Tests', () {
    test('Correctly parses and classifies WebSocket payloads', () {
      final telemetryJson = {
        'type': 'telemetry_update',
        'data': {
          'vehicle_id': 'v-001',
          'soc_pct': 72.0,
          'speed_kph': 30.0,
        }
      };

      final event = WebSocketEvent.fromJson(telemetryJson);
      expect(event.isTelemetryUpdate, isTrue);
      expect(event.data['soc_pct'], 72.0);

      final alertJson = {
        'type': 'alert',
        'data': {
          'id': 'a-002',
          'alert_type': 'HIGH_BATTERY_TEMP',
        }
      };

      final alertEvent = WebSocketEvent.fromJson(alertJson);
      expect(alertEvent.isAlert, isTrue);
    });
  });
}
