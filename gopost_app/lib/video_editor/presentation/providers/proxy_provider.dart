import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/data/services/proxy_generation_service.dart';
import 'package:gopost_app/video_editor/domain/services/proxy_service.dart';

/// DIP: Provider exposes the abstract [ProxyService] type so callers don't
/// depend on the concrete [ProxyGenerationService].
final proxyGenerationServiceProvider = Provider<ProxyService>((ref) {
  return ProxyGenerationService.instance;
});
