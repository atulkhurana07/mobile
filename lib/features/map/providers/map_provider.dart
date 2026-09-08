import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/charging_repository.dart';
import '../../vehicle/repositories/vehicle_repository.dart';
import '../../vehicle/providers/vehicle_provider.dart';

final publicChargingCentersProvider =
    FutureProvider.autoDispose<List<ChargingCenterModel>>((ref) async {
  final repository = ref.watch(chargingRepositoryProvider);
  return await repository.getChargingCenters();
});

final activeVehicleTrackProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final selectedId = ref.watch(selectedVehicleIdProvider);
  if (selectedId == null) return [];
  final repository = ref.watch(vehicleRepositoryProvider);
  return await repository.getVehicleTrack(selectedId, limit: 30);
});
