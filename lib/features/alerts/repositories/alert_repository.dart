import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../models/alert_model.dart';

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AlertRepository(dio);
});

class AlertRepository {
  final Dio _dio;

  AlertRepository(this._dio);

  Future<List<AlertModel>> getAlerts({
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (statusFilter != null && statusFilter.isNotEmpty) {
        queryParams['status_filter'] = statusFilter;
      }

      final response = await _dio.get(
        ApiEndpoints.operatorAlerts,
        queryParameters: queryParams,
      );

      final list = response.data as List<dynamic>;
      return list
          .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<AlertModel> acknowledgeAlert(
    String alertId, {
    String? resolutionNote,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.operatorAlertAck(alertId),
        data: {
          'resolution_note': resolutionNote ?? 'Acknowledged via Mobile Terminal',
        },
      );

      return AlertModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
