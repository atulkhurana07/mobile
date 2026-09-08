import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicle/providers/vehicle_provider.dart';
import '../../alerts/models/alert_model.dart';
import '../../../services/telemetry/offline_telemetry_queue.dart';

class PitchSimulatorWaypoint {
  final String locationName;
  final double latitude;
  final double longitude;
  final double speedKph;
  final double headingDeg;
  final double socPct;

  const PitchSimulatorWaypoint({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.speedKph,
    required this.headingDeg,
    required this.socPct,
  });
}

const List<PitchSimulatorWaypoint> kCentralDelhiWaypoints = [
  PitchSimulatorWaypoint(
    locationName: 'Connaught Place Inner Circle',
    latitude: 28.6328,
    longitude: 77.2197,
    speedKph: 32.0,
    headingDeg: 175.0,
    socPct: 18.0,
  ),
  PitchSimulatorWaypoint(
    locationName: 'Janpath Road / Tolstoy Marg',
    latitude: 28.6250,
    longitude: 77.2205,
    speedKph: 42.0,
    headingDeg: 172.0,
    socPct: 15.0,
  ),
  PitchSimulatorWaypoint(
    locationName: 'Kartavya Path / Rajpath',
    latitude: 28.6145,
    longitude: 77.2260,
    speedKph: 48.0,
    headingDeg: 110.0,
    socPct: 12.0,
  ),
  PitchSimulatorWaypoint(
    locationName: 'India Gate C-Hexagon',
    latitude: 28.6129,
    longitude: 77.2295,
    speedKph: 38.0,
    headingDeg: 85.0,
    socPct: 9.5, // Depletes < 10%: Triggers dynamic critical LOW_SOC alert
  ),
  PitchSimulatorWaypoint(
    locationName: 'Pragati Maidan / Mathura Road',
    latitude: 28.6180,
    longitude: 77.2410,
    speedKph: 45.0,
    headingDeg: 45.0,
    socPct: 8.0,
  ),
  PitchSimulatorWaypoint(
    locationName: 'Supreme Court & ITO Ring Road',
    latitude: 28.6225,
    longitude: 77.2390,
    speedKph: 35.0,
    headingDeg: 330.0,
    socPct: 7.0, // Terminal waypoint (7% SoC)
  ),
];

class PitchSimulatorState {
  final bool isRunning;
  final int currentStepIndex;
  final PitchSimulatorWaypoint currentWaypoint;
  final AlertModel? activeAlert;

  const PitchSimulatorState({
    required this.isRunning,
    required this.currentStepIndex,
    required this.currentWaypoint,
    this.activeAlert,
  });

  PitchSimulatorState copyWith({
    bool? isRunning,
    int? currentStepIndex,
    PitchSimulatorWaypoint? currentWaypoint,
    AlertModel? activeAlert,
    bool clearAlert = false,
  }) {
    return PitchSimulatorState(
      isRunning: isRunning ?? this.isRunning,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentWaypoint: currentWaypoint ?? this.currentWaypoint,
      activeAlert: clearAlert ? null : (activeAlert ?? this.activeAlert),
    );
  }
}

final pitchSimulatorProvider =
    StateNotifierProvider<PitchSimulatorNotifier, PitchSimulatorState>((ref) {
  return PitchSimulatorNotifier(ref);
});

final pitchSimulatorAlertProvider = Provider<AlertModel?>((ref) {
  return ref.watch(pitchSimulatorProvider).activeAlert;
});

final isPitchSimulatorRunningProvider = Provider<bool>((ref) {
  return ref.watch(pitchSimulatorProvider).isRunning;
});

class PitchSimulatorNotifier extends StateNotifier<PitchSimulatorState> {
  final Ref _ref;
  Timer? _timer;

  PitchSimulatorNotifier(this._ref)
      : super(PitchSimulatorState(
          isRunning: false,
          currentStepIndex: 0,
          currentWaypoint: kCentralDelhiWaypoints[0],
          activeAlert: null,
        ));

  List<PitchSimulatorWaypoint> get waypoints => kCentralDelhiWaypoints;

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _applyCurrentWaypoint();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      step();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isRunning: false);
  }

  void toggle() {
    if (state.isRunning) {
      stop();
    } else {
      start();
    }
  }

  void step() {
    final nextIndex = (state.currentStepIndex + 1) % waypoints.length;
    final waypoint = waypoints[nextIndex];

    state = state.copyWith(
      currentStepIndex: nextIndex,
      currentWaypoint: waypoint,
    );

    _applyCurrentWaypoint();
  }

  void _applyCurrentWaypoint() {
    final vehicle = _ref.read(activeVehicleProvider).vehicle;
    final vehicleId = vehicle?.id ?? 'dl-01-ev-sim';
    final waypoint = state.currentWaypoint;

    AlertModel? alert;
    if (waypoint.socPct < 10.0) {
      alert = AlertModel(
        id: 'sim-alert-low-soc-${waypoint.socPct}',
        vehicleId: vehicleId,
        alertType: 'LOW_SOC',
        severity: 'critical',
        status: 'active',
        firstSeen: DateTime.now().toUtc(),
        lastSeen: DateTime.now().toUtc(),
        metadata: {
          'soc_pct': waypoint.socPct,
          'simulated': true,
          'location': waypoint.locationName,
        },
      );
    }

    state = state.copyWith(
      activeAlert: alert,
      clearAlert: alert == null,
    );

    final telemetryData = <String, dynamic>{
      'vehicle_id': vehicleId,
      'latitude': waypoint.latitude,
      'longitude': waypoint.longitude,
      'speed_kph': waypoint.speedKph,
      'heading_deg': waypoint.headingDeg,
      'soc_pct': waypoint.socPct,
      'estimated_range_km': waypoint.socPct * 2.2,
      'charging': false,
      'connectivity_status': 'online',
      'battery_temp_c': 34.5,
      'observed_at': DateTime.now().toUtc().toIso8601String(),
    };

    _ref.read(activeVehicleProvider.notifier).applyTelemetryUpdate(telemetryData);

    // Queue telemetry locally and attempt ingestion
    try {
      _ref.read(offlineTelemetryQueueProvider).enqueue({
        'device_id': 'sim-device-delhi',
        'vehicle_id': vehicleId,
        'location': {
          'lat': waypoint.latitude,
          'lng': waypoint.longitude,
          'heading': waypoint.headingDeg,
        },
        'energy': {
          'soc_pct': waypoint.socPct,
          'charging': false,
          'estimated_range_km': waypoint.socPct * 2.2,
        },
        'motion': {
          'speed_kph': waypoint.speedKph,
          'heading_deg': waypoint.headingDeg,
        },
      });
    } catch (_) {
      // Offline or network error gracefully handled by queue
    }
  }

  void reset() {
    stop();
    state = PitchSimulatorState(
      isRunning: false,
      currentStepIndex: 0,
      currentWaypoint: kCentralDelhiWaypoints[0],
      activeAlert: null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
