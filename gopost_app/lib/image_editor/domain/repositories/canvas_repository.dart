import 'dart:typed_data';

import 'package:gopost_app/image_editor/domain/entities/canvas_entity.dart';
import 'package:gopost_app/image_editor/domain/entities/layer_entity.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// ISP: Canvas lifecycle operations.
abstract class CanvasRepository {
  Future<CanvasEntity> createCanvas(CanvasConfig config);
  Future<void> destroyCanvas(int canvasId);
  Future<void> resizeCanvas(int canvasId, int width, int height);
}

/// ISP: Layer CRUD operations.
abstract class LayerRepository {
  Future<LayerEntity> addImageLayer(
      int canvasId, Uint8List rgbaPixels, int width, int height,
      {int index = -1});
  Future<LayerEntity> addSolidColorLayer(
      int canvasId, double r, double g, double b, double a,
      int width, int height,
      {int index = -1});
  Future<LayerEntity> addGroupLayer(int canvasId, String name,
      {int index = -1});
  Future<void> removeLayer(int canvasId, int layerId);
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex);
  Future<LayerEntity> duplicateLayer(int canvasId, int layerId);
  Future<List<LayerEntity>> getAllLayers(int canvasId);
  Future<LayerEntity> getLayerInfo(int canvasId, int layerId);
}

/// ISP: Layer property mutations.
abstract class LayerPropertyRepository {
  Future<void> setVisible(int canvasId, int layerId, bool visible);
  Future<void> setLocked(int canvasId, int layerId, bool locked);
  Future<void> setOpacity(int canvasId, int layerId, double opacity);
  Future<void> setBlendMode(int canvasId, int layerId, BlendMode mode);
  Future<void> setName(int canvasId, int layerId, String name);
  Future<void> setTransform(int canvasId, int layerId,
      {double tx, double ty, double sx, double sy, double rotation});
}

/// ISP: Rendering operations.
abstract class RenderRepository {
  Future<DecodedImage> renderCanvas(int canvasId);
  Future<void> invalidateCanvas(int canvasId);
}

/// ISP: Image import / codec operations.
abstract class ImageImportRepository {
  Future<DecodedImage> decodeImageFile(String path);
  Future<DecodedImage> decodeImageBytes(Uint8List data);
  Future<void> encodeToFile(
      DecodedImage image, String path, ImageFormat format,
      {int quality = 85});
}
