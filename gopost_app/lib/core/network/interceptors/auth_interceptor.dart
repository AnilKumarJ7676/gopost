import 'package:dio/dio.dart';
import 'package:gopost_app/core/constants/api_constants.dart';
import 'package:gopost_app/core/logging/app_logger.dart';
import 'package:gopost_app/core/network/ssl_pinning.dart';
import 'package:gopost_app/core/security/secure_storage_service.dart';

/// Handles Bearer token injection, automatic 401 token refresh with retry,
/// and session-expiry notification.
///
/// Extends [QueuedInterceptor] so that concurrent requests hitting 401 are
/// serialised – only one refresh call is made and the rest wait in the queue.
class AuthInterceptor extends QueuedInterceptor {
  String? _accessToken;
  final SecureStorageService _secureStorage;
  final Dio _refreshDio;

  /// Called when refresh fails or no refresh token exists.
  /// The provider layer hooks this to force-logout the user.
  void Function()? onSessionExpired;

  AuthInterceptor({
    required SecureStorageService secureStorage,
    required String baseUrl,
    Set<String> pinnedCertFingerprints = const {},
  })  : _secureStorage = secureStorage,
        _refreshDio = _buildRefreshDio(baseUrl, pinnedCertFingerprints);

  static Dio _buildRefreshDio(
    String baseUrl,
    Set<String> pinnedCertFingerprints,
  ) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    configureCertificatePinning(dio, pinnedCertFingerprints);
    return dio;
  }

  void setToken(String token) => _accessToken = token;
  void clearToken() => _accessToken = null;
  String? get accessToken => _accessToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        _isRefreshRequest(err.requestOptions)) {
      return handler.next(err);
    }

    final refreshToken =
        await _secureStorage.read(key: ApiConstants.refreshTokenKey);
    if (refreshToken == null) {
      _forceLogout();
      return handler.next(err);
    }

    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;

      _accessToken = newAccessToken;
      await _secureStorage.write(
        key: ApiConstants.refreshTokenKey,
        value: newRefreshToken,
      );

      AppLogger.debug('AuthInterceptor: token refreshed successfully');

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _refreshDio.fetch(retryOptions);
      return handler.resolve(retryResponse);
    } catch (e) {
      AppLogger.warning('AuthInterceptor: refresh failed, forcing logout');
      _forceLogout();
      return handler.next(err);
    }
  }

  bool _isRefreshRequest(RequestOptions options) =>
      options.path.contains('/auth/refresh');

  void _forceLogout() {
    _accessToken = null;
    _secureStorage.delete(key: ApiConstants.refreshTokenKey);
    onSessionExpired?.call();
  }
}
