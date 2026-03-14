import 'dart:typed_data';

import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// SRP: Orchestrates the template download→decrypt→load lifecycle.
/// DIP: Depends on abstract GopostEngine, not FFI implementation.
class TemplateBridge {
  final GopostEngine _engine;

  const TemplateBridge(this._engine);

  Future<TemplateMetadata> loadEncryptedTemplate({
    required Uint8List encryptedBlob,
    required Uint8List sessionKey,
  }) async {
    if (!_engine.isInitialized) {
      await _engine.initialize(const EngineConfig());
    }
    return _engine.loadTemplate(encryptedBlob, sessionKey);
  }

  Future<void> unloadTemplate(String templateId) async {
    if (!_engine.isInitialized) return;
    return _engine.unloadTemplate(templateId);
  }

  Future<bool> get isReady async => _engine.isInitialized;
}
