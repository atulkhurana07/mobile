import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/networking/api_endpoints.dart';

class ChargingCenterModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? connectors;
  final double? powerKw;

  const ChargingCenterModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.connectors,
    this.powerKw,
  });

  factory ChargingCenterModel.fromJson(Map<String, dynamic> json) {
    return ChargingCenterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      connectors: json['connectors'] as Map<String, dynamic>?,
      powerKw: (json['power_kw'] as num?)?.toDouble(),
    );
  }
}

final chargingRepositoryProvider = Provider<ChargingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChargingRepository(dio);
});

class ChargingRepository {
  final Dio _dio;

  ChargingRepository(this._dio);

  Future<List<ChargingCenterModel>> getChargingCenters() async {
    try {
      final response = await _dio.get(ApiEndpoints.publicChargingCenters);
      final list = response.data as List<dynamic>;
      return list
          .map((item) => ChargingCenterModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
