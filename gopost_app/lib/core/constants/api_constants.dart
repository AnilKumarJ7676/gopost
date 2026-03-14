class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://localhost:8080/api/v1';
  static const String stagingUrl = 'https://api-staging.gopost.app/api/v1';
  static const String productionUrl = 'https://api.gopost.app/api/v1';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String refreshTokenKey = 'refresh_token';
}
