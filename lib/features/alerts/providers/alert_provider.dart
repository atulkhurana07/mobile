import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../repositories/alert_repository.dart';
import '../../vehicle/providers/vehicle_provider.dart';

// Alert Status Filter State
final alertFilterProvider = StateProvider<String?>((ref) => null);

// Scoped Alerts for Department
final departmentAlertsProvider = FutureProvider.autoDispose<List<AlertModel>>((ref) async {
  final repository = ref.watch(alertRepositoryProvider);
  final status = ref.watch(alertFilterProvider);
  return await repository.getAlerts(statusFilter: status);
});

// Alerts specific to the currently selected vehicle
final vehicleAlertsProvider = Provider.autoDispose<List<AlertModel>>((ref) {
  final alertsAsync = ref.watch(departmentAlertsProvider);
  final selectedVehicleId = ref.watch(selectedVehicleIdProvider);

  return alertsAsync.maybeWhen(
    data: (alerts) {
      if (selectedVehicleId == null) return alerts;
      return alerts.where((a) => a.vehicleId == selectedVehicleId).toList();
    },
    orElse: () => [],
  );
});

// Top active critical alert for the selected vehicle (displayed on dashboard banner)
final topCriticalAlertProvider = Provider.autoDispose<AlertModel?>((ref) {
  final vehicleAlerts = ref.watch(vehicleAlertsProvider);
  final activeCritical = vehicleAlerts.where((a) => a.isActive && a.isCritical).toList();
  return activeCritical.isNotEmpty ? activeCritical.first : null;
});
