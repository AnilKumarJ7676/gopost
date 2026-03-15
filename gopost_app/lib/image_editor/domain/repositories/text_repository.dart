import 'package:gopost_app/image_editor/domain/entities/text_entity.dart';

/// ISP: Text layer management.
abstract class TextLayerRepository {
  Future<List<String>> getAvailableFonts();
  Future<int> addTextLayer(int canvasId, TextLayerConfig config, int maxWidth,
      {int index = -1});
  Future<void> updateTextLayer(
      int canvasId, int layerId, TextLayerConfig config, int maxWidth);
}
