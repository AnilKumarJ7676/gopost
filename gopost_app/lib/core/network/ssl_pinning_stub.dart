import 'package:dio/dio.dart';

/// No-op on platforms without dart:io (web).
void configureCertificatePinning(Dio dio, Set<String> fingerprints) {}
