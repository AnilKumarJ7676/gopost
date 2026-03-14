import 'dart:async';
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({required this.dio, this.maxRetries = 3});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRetryable = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    if (!isRetryable) {
      return handler.next(err);
    }

    int retries = 0;
    while (retries < maxRetries) {
      retries++;
      final delay = Duration(milliseconds: 500 * (1 << retries));
      await Future<void>.delayed(delay);

      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException {
        if (retries >= maxRetries) {
          return handler.next(err);
        }
      }
    }
  }
}
