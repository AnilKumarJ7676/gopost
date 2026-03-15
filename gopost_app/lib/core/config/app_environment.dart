import 'package:gopost_app/core/constants/api_constants.dart';

enum AppEnvironment { development, staging, production }

class EnvironmentConfig {
  static const _envKey = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get current {
    switch (_envKey) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  static String get baseUrl {
    switch (current) {
      case AppEnvironment.production:
        return ApiConstants.productionUrl;
      case AppEnvironment.staging:
        return ApiConstants.stagingUrl;
      case AppEnvironment.development:
        return ApiConstants.baseUrl;
    }
  }

  static bool get isProduction => current == AppEnvironment.production;
  static bool get isDevelopment => current == AppEnvironment.development;

  static Set<String> get sslPinnedFingerprints {
    switch (current) {
      case AppEnvironment.production:
        return const {
          // Leaf + intermediate cert SHA-256 fingerprints for api.gopost.app
          // Replace with actual fingerprints before production deployment
          'PLACEHOLDER_LEAF_CERT_SHA256',
          'PLACEHOLDER_INTERMEDIATE_CERT_SHA256',
        };
      case AppEnvironment.staging:
        return const {};
      case AppEnvironment.development:
        return const {};
    }
  }
}
