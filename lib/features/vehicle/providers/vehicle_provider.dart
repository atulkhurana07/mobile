import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage.dart';
import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository.dart';

// List of all accessible vehicles in the department
final vehicleListProvider = FutureProvider.autoDispose<List<VehicleModel>>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return await repository.getVehicles();
});

// Selected Vehicle ID Provider with LocalStorage persistence
final selectedVehicleIdProvider =
    StateNotifierProvider<SelectedVehicleIdNotifier, String?>((ref) {
  final localStorage = ref.watch(localStorageProvider);
  return SelectedVehicleIdNotifier(localStorage);
});

class SelectedVehicleIdNotifier extends StateNotifier<String?> {
  final LocalStorage _localStorage;

  SelectedVehicleIdNotifier(this._localStorage) : super(null) {
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final id = await _localStorage.getSelectedVehicleId();
    if (id != null) {
      state = id;
    }
  }

  Future<void> selectVehicle(String vehicleId) async {
    state = vehicleId;
    await _localStorage.setSelectedVehicleId(vehicleId);
  }

  Future<void> clear() async {
    state = null;
    await _localStorage.clearSelectedVehicleId();
  }
}

// Active Vehicle State (Combines REST + Realtime WebSocket updates)
class ActiveVehicleState {
  final bool isLoading;
  final VehicleModel? vehicle;
  final String? errorMessage;
  final bool isStale;

  const ActiveVehicleState({
    required this.isLoading,
    this.vehicle,
    this.errorMessage,
    this.isStale = false,
  });

  factory ActiveVehicleState.initial() =>
      const ActiveVehicleState(isLoading: false);
  factory ActiveVehicleState.loading() =>
      const ActiveVehicleState(isLoading: true);
  factory ActiveVehicleState.data(VehicleModel vehicle, {bool isStale = false}) =>
      ActiveVehicleState(isLoading: false, vehicle: vehicle, isStale: isStale);
  factory ActiveVehicleState.error(String message) =>
      ActiveVehicleState(isLoading: false, errorMessage: message);
}

final activeVehicleProvider =
    StateNotifierProvider<ActiveVehicleNotifier, ActiveVehicleState>((ref) {
  final repository = ref.watch(vehicleRepositoryProvider);
  final selectedId = ref.watch(selectedVehicleIdProvider);
  return ActiveVehicleNotifier(repository, selectedId);
});

class ActiveVehicleNotifier extends StateNotifier<ActiveVehicleState> {
  final VehicleRepository _repository;
  final String? _selectedVehicleId;

  ActiveVehicleNotifier(this._repository, this._selectedVehicleId)
      : super(ActiveVehicleState.initial()) {
    if (_selectedVehicleId != null) {
      loadVehicle();
    }
  }

  Future<void> loadVehicle() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    state = ActiveVehicleState.loading();
    try {
      final vehicle = await _repository.getVehicleById(vehicleId);
      state = ActiveVehicleState.data(vehicle);
    } catch (e) {
      state = ActiveVehicleState.error(e.toString());
    }
  }

  // Update telemetry incrementally from WebSocket stream
  void applyTelemetryUpdate(Map<String, dynamic> data) {
    if (state.vehicle == null) return;
    final vehicleId = data['vehicle_id']?.toString() ?? data['id']?.toString();
    if (vehicleId != null &&
        vehicleId != state.vehicle!.id &&
        vehicleId != state.vehicle!.vehicleCode) {
      return; // Not for this vehicle
    }

    final updated = state.vehicle!.copyWith(
      latitude: (data['latitude'] ?? data['location']?['lat'] as num?)?.toDouble() ??
          state.vehicle!.latitude,
      longitude: (data['longitude'] ?? data['location']?['lng'] as num?)?.toDouble() ??
          state.vehicle!.longitude,
      speedKph: (data['speed_kph'] ?? data['motion']?['speed_kph'] as num?)?.toDouble() ??
          state.vehicle!.speedKph,
      headingDeg: (data['heading_deg'] ?? data['motion']?['heading_deg'] as num?)?.toDouble() ??
          state.vehicle!.headingDeg,
      socPct: (data['soc_pct'] ?? data['energy']?['soc_pct'] as num?)?.toDouble() ??
          state.vehicle!.socPct,
      estimatedRangeKm: (data['estimated_range_km'] ?? data['energy']?['estimated_range_km'] as num?)
              ?.toDouble() ??
          state.vehicle!.estimatedRangeKm,
      charging: (data['charging'] ?? data['energy']?['charging'] as bool?) ??
          state.vehicle!.charging,
      connectivityStatus: (data['connectivity_status'] ?? data['connectivity']?['status'] as String?) ??
          'online',
      lastSeen: DateTime.now().toUtc(),
    );

    state = ActiveVehicleState.data(updated, isStale: false);
  }

  void markStale(bool isStale) {
    if (state.vehicle != null) {
      state = ActiveVehicleState.data(state.vehicle!, isStale: isStale);
    }
  }
}
