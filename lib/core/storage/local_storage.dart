import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

class LocalStorage {
  static const String _keySelectedVehicleId = 'selected_vehicle_id';
  static const String _keyLastDepartmentId = 'last_department_id';

  Future<void> setSelectedVehicleId(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedVehicleId, vehicleId);
  }

  Future<String?> getSelectedVehicleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedVehicleId);
  }

  Future<void> clearSelectedVehicleId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedVehicleId);
  }

  Future<void> setLastDepartmentId(String departmentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDepartmentId, departmentId);
  }

  Future<String?> getLastDepartmentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastDepartmentId);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
