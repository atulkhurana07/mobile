import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../models/vehicle_model.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return VehicleRepository(dio);
});

class VehicleRepository {
  final Dio _dio;

  VehicleRepository(this._dio);

  Future<List<VehicleModel>> getVehicles() async {
    try {
      final response = await _dio.get(ApiEndpoints.operatorVehicles);
      final list = response.data as List<dynamic>;
      return list
          .map((item) => VehicleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<VehicleModel> getVehicleById(String vehicleId) async {
    try {
      final response = await _dio.get(ApiEndpoints.operatorVehicle(vehicleId));
      return VehicleModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getVehicleTrack(
    String vehicleId, {
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.operatorVehicleTrack(vehicleId),
        queryParameters: {'limit': limit},
      );
      final list = response.data as List<dynamic>;
      return list.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
