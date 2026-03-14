/// This file is kept for backward compatibility.
///
/// Real SSL certificate pinning is now handled at the Dio HttpClientAdapter
/// level via [configureCertificatePinning] in `ssl_pinning.dart`.
/// The pinned fingerprint set is managed through [EnvironmentConfig].
@Deprecated('Use configureCertificatePinning from ssl_pinning.dart instead')
class SSLPinningInterceptor {}
