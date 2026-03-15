import 'package:dio/dio.dart';
import 'package:gopost_app/core/logging/app_logger.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    AppLogger.debug(
      '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      '✕ ${err.requestOptions.method} ${err.requestOptions.uri} - ${err.message}',
    );
    handler.next(err);
  }
}
