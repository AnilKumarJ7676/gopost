import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/config/app_environment.dart';
import 'package:gopost_app/core/network/http_client.dart';
import 'package:gopost_app/core/network/interceptors/auth_interceptor.dart';
import 'package:gopost_app/core/security/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageServiceImpl();
});

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(
    secureStorage: ref.watch(secureStorageProvider),
    baseUrl: EnvironmentConfig.baseUrl,
    pinnedCertFingerprints: EnvironmentConfig.sslPinnedFingerprints,
  );
});

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(
    authInterceptor: ref.watch(authInterceptorProvider),
    pinnedCertFingerprints: EnvironmentConfig.sslPinnedFingerprints,
  );
});
