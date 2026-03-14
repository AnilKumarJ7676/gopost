import 'package:gopost_app/template_browser/domain/entities/template_access.dart';

class TemplateAccessModel {
  final String signedUrl;
  final String sessionKey;
  final String renderToken;
  final String expiresAt;

  const TemplateAccessModel({
    required this.signedUrl,
    required this.sessionKey,
    required this.renderToken,
    required this.expiresAt,
  });

  factory TemplateAccessModel.fromJson(Map<String, dynamic> json) {
    return TemplateAccessModel(
      signedUrl: json['signed_url'] as String,
      sessionKey: json['session_key'] as String,
      renderToken: json['render_token'] as String,
      expiresAt: json['expires_at'] as String,
    );
  }

  TemplateAccess toEntity() {
    return TemplateAccess(
      signedUrl: signedUrl,
      sessionKey: sessionKey,
      renderToken: renderToken,
      expiresAt: DateTime.parse(expiresAt),
    );
  }
}
