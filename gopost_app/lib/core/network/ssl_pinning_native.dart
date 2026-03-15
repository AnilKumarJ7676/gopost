import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:gopost_app/core/logging/app_logger.dart';

/// Configures Dio to enforce certificate pinning against a set of SHA-256
/// fingerprints.
///
/// Uses [SecurityContext] with `withTrustedRoots: false` so that the
/// platform's default CA store is bypassed and **every** TLS handshake
/// goes through [badCertificateCallback], where the leaf cert fingerprint
/// is validated against [fingerprints].
///
/// Fingerprints should be uppercase hex strings (with or without colons).
/// If [fingerprints] is empty the function is a no-op and standard system
/// certificate validation applies.
void configureCertificatePinning(Dio dio, Set<String> fingerprints) {
  if (fingerprints.isEmpty) return;

  final normalised =
      fingerprints.map((f) => f.toUpperCase().replaceAll(':', '')).toSet();

  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;

  adapter.createHttpClient = () {
    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context);

    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      final digest = sha256.convert(cert.der);
      final hexFingerprint = digest.toString().toUpperCase();

      final isPinned = normalised.contains(hexFingerprint);
      if (!isPinned) {
        AppLogger.warning(
          'SSL Pinning: rejected certificate for $host:$port '
          '(fingerprint: $hexFingerprint)',
        );
      }
      return isPinned;
    };

    return client;
  };
}
