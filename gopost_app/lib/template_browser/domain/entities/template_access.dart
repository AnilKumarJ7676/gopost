import 'package:equatable/equatable.dart';

class TemplateAccess extends Equatable {
  final String signedUrl;
  final String sessionKey;
  final String renderToken;
  final DateTime expiresAt;

  const TemplateAccess({
    required this.signedUrl,
    required this.sessionKey,
    required this.renderToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [signedUrl, sessionKey, renderToken, expiresAt];
}
