import 'package:dio/dio.dart';
import 'package:gopost_app/core/config/app_environment.dart';
import 'package:gopost_app/core/network/interceptors/auth_interceptor.dart';
import 'package:gopost_app/core/network/interceptors/error_interceptor.dart';
import 'package:gopost_app/core/network/interceptors/logging_interceptor.dart';
import 'package:gopost_app/core/network/interceptors/retry_interceptor.dart';
import 'package:gopost_app/core/network/ssl_pinning.dart';

class HttpClient {
  late final Dio _dio;
  final AuthInterceptor authInterceptor;

  Dio get dio => _dio;

  HttpClient({
    required this.authInterceptor,
    String? baseUrl,
    Set<String> pinnedCertFingerprints = const {},
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? EnvironmentConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      authInterceptor,
      LoggingInterceptor(),
      ErrorInterceptor(),
      RetryInterceptor(dio: _dio),
    ]);

    configureCertificatePinning(_dio, pinnedCertFingerprints);
  }
}
