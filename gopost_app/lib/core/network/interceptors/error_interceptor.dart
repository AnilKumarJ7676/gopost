import 'package:dio/dio.dart';
import 'package:gopost_app/core/error/exceptions.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        throw const NetworkException(message: 'Connection timed out');
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final data = err.response?.data;
        String message = 'Server error';
        String? code;
        if (data is Map<String, dynamic>) {
          final errorObj = data['error'];
          if (errorObj is Map<String, dynamic>) {
            message = (errorObj['message'] as String?) ?? 'Server error';
            code = errorObj['code'] as String?;
          }
        }
        throw ServerException(
          message: message,
          statusCode: statusCode,
          code: code,
        );
      default:
        throw ServerException(message: err.message ?? 'Unknown error');
    }
  }
}
