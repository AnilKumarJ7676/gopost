import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Callback type for external crash reporting services
/// (Sentry, Firebase Crashlytics, etc.).
typedef CrashReportCallback = FutureOr<void> Function(
  dynamic error,
  StackTrace? stackTrace, {
  Map<String, dynamic>? extra,
});

class AppLogger {
  AppLogger._();

  static late final Logger _logger;

  /// Optional hook for forwarding errors to an external crash reporting
  /// service. Set this before calling [init] or immediately after.
  static CrashReportCallback? onCrashReport;

  static void init() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);

  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _reportCrash(error ?? message, stackTrace);
  }

  /// Report a fatal error that caused the app to crash.
  static void fatal(dynamic error, StackTrace? stackTrace) {
    _logger.f('FATAL', error: error, stackTrace: stackTrace);
    _reportCrash(error, stackTrace, fatal: true);
  }

  static void _reportCrash(
    dynamic error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) {
    if (onCrashReport == null) return;
    try {
      onCrashReport!(error, stackTrace, extra: {'fatal': fatal});
    } catch (_) {
      // Never let crash reporting itself crash the app.
      if (kDebugMode) rethrow;
    }
  }
}
