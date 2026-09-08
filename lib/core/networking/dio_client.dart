import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../storage/secure_storage.dart';
import '../errors/app_exception.dart';
import 'api_endpoints.dart';

final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return DioClient(secureStorage, ref).dio;
});

class DioClient {
  final SecureStorage _secureStorage;
  final Ref _ref;
  late final Dio dio;
  bool _isRefreshing = false;

  DioClient(this._secureStorage, this._ref) {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Do not attach token for public or login/refresh calls
          final isAuthCall = options.path.contains('/api/auth/login') ||
              options.path.contains('/api/auth/refresh') ||
              options.path.contains('/api/public');

          if (!isAuthCall) {
            final token = await _secureStorage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle 401 Unauthorized token refresh
          if (e.response?.statusCode == 401 && !_isRefreshing) {
            final isAuthPath = e.requestOptions.path.contains('/api/auth/login') ||
                e.requestOptions.path.contains('/api/auth/refresh');

            if (!isAuthPath) {
              _isRefreshing = true;
              try {
                final refreshToken = await _secureStorage.getRefreshToken();
                if (refreshToken != null) {
                  final refreshDio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
                  final refreshResponse = await refreshDio.post(
                    ApiEndpoints.refresh,
                    data: {'refresh_token': refreshToken},
                  );

                  if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
                    final newAccessToken = refreshResponse.data['access_token'] as String;
                    final newRefreshToken = refreshResponse.data['refresh_token'] as String;

                    await _secureStorage.saveTokens(
                      accessToken: newAccessToken,
                      refreshToken: newRefreshToken,
                    );

                    _isRefreshing = false;

                    // Replay original request with refreshed token
                    final retryOptions = e.requestOptions;
                    retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                    final response = await dio.fetch(retryOptions);
                    return handler.resolve(response);
                  }
                }
              } catch (_) {
                _isRefreshing = false;
                await _secureStorage.clearTokens();
              }
              _isRefreshing = false;
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  static AppException handleError(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      String message = 'An unexpected error occurred.';

      if (responseData is Map && responseData.containsKey('detail')) {
        message = responseData['detail'].toString();
      } else if (error.message != null && error.message!.isNotEmpty) {
        message = error.message!;
      }

      switch (statusCode) {
        case 401:
          return UnauthorizedException(message: message);
        case 403:
          return ForbiddenException(message: message);
        case 404:
          return NotFoundException(message: message);
        case 422:
          return ValidationException(message, details: responseData);
        default:
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError) {
            return NetworkException('Server connection timed out or is warming up. Please check connection and try again.');
          }
          return AppException(message, statusCode: statusCode);
      }
    }
    return AppException(error.toString());
  }
}
