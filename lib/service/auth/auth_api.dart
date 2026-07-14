import 'package:anx_reader/config/api_config.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:dio/dio.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
}

class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.apiBaseUrl}/users/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        return AuthTokens.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }

      final message = _extractMessage(response.data) ?? 'Invalid credentials';
      throw AuthException(message);
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw AuthException(_dioErrorMessage(e));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> logout() async {
    final token = Prefs().accessToken;
    if (token == null || token.isEmpty) return;

    try {
      await _dio.post(
        '${ApiConfig.apiBaseUrl}/users/logout',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } on DioException {
      // Clear local session even if the network call fails
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  String _dioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Check that the API is running.';
    }
    return _extractMessage(e.response?.data) ??
        e.message ??
        'Login failed. Please try again.';
  }
}
