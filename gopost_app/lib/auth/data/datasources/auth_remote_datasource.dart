import 'package:dio/dio.dart';
import 'package:gopost_app/auth/data/models/auth_response_model.dart';
import 'package:gopost_app/core/error/exceptions.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  });
  Future<AuthResponseModel> login({required String email, required String password});
  Future<AuthResponseModel> refreshToken(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<AuthResponseModel> oauthLogin({required String provider, required String idToken});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  const AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: _extractMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractCode(e),
      );
    }
  }

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: _extractMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractCode(e),
      );
    }
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: _extractMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractCode(e),
      );
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post('/auth/logout', data: {
        'refresh_token': refreshToken,
      });
    } on DioException catch (e) {
      throw ServerException(
        message: _extractMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractCode(e),
      );
    }
  }

  @override
  Future<AuthResponseModel> oauthLogin({
    required String provider,
    required String idToken,
  }) async {
    try {
      final response = await _dio.post('/auth/oauth/$provider', data: {
        'id_token': idToken,
      });
      return AuthResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: _extractMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractCode(e),
      );
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) return (error['message'] as String?) ?? 'Server error';
    }
    return 'Server error';
  }

  String? _extractCode(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) return error['code'] as String?;
    }
    return null;
  }
}
