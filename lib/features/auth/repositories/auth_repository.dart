import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/local_storage.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final localStorage = ref.watch(localStorageProvider);
  return AuthRepository(dio, secureStorage, localStorage);
});

class AuthRepository {
  final Dio _dio;
  final SecureStorage _secureStorage;
  final LocalStorage _localStorage;

  AuthRepository(this._dio, this._secureStorage, this._localStorage);

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;

      await _secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      return await getCurrentUser();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiEndpoints.me);
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      if (user.departmentId != null) {
        await _localStorage.setLastDepartmentId(user.departmentId!);
      }
      return user;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<void> logout() async {
    await _secureStorage.clearTokens();
    await _localStorage.clearSelectedVehicleId();
  }

  Future<bool> hasValidToken() async {
    final token = await _secureStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
