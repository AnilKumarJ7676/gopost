import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/image_editor/domain/entities/text_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/text_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

class TextRepositoryImpl implements TextLayerRepository {
  final ImageEditorEngine _engine;

  TextRepositoryImpl(this._engine);

  @override
  Future<List<String>> getAvailableFonts() async {
    try {
      return await _engine.getAvailableFonts();
    } catch (e) {
      throw ServerException(message: 'Failed to get fonts: $e');
    }
  }

  @override
  Future<int> addTextLayer(
      int canvasId, TextLayerConfig config, int maxWidth,
      {int index = -1}) async {
    try {
      return await _engine.addTextLayer(
          canvasId, config.toEngineConfig(), maxWidth, index: index);
    } catch (e) {
      throw ServerException(message: 'Failed to add text layer: $e');
    }
  }

  @override
  Future<void> updateTextLayer(
      int canvasId, int layerId, TextLayerConfig config, int maxWidth) async {
    try {
      await _engine.updateTextLayer(
          canvasId, layerId, config.toEngineConfig(), maxWidth);
    } catch (e) {
      throw ServerException(message: 'Failed to update text layer: $e');
    }
  }
}
