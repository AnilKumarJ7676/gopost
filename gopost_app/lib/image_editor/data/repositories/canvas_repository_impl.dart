import 'dart:typed_data';

import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/image_editor/data/datasources/engine_canvas_datasource.dart';
import 'package:gopost_app/image_editor/domain/entities/canvas_entity.dart';
import 'package:gopost_app/image_editor/domain/entities/layer_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// DIP: Implements all canvas repository interfaces.
/// SRP: Maps datasource calls to domain entities + error handling.
class CanvasRepositoryImpl
    implements
        CanvasRepository,
        LayerRepository,
        LayerPropertyRepository,
        RenderRepository,
        ImageImportRepository {
  final EngineCanvasDataSource _dataSource;

  CanvasRepositoryImpl(this._dataSource);

  // -- CanvasRepository --

  @override
  Future<CanvasEntity> createCanvas(CanvasConfig config) async {
    try {
      final canvasId = await _dataSource.createCanvas(config);
      return CanvasEntity(
        canvasId: canvasId,
        width: config.width,
        height: config.height,
        dpi: config.dpi,
        colorSpace: config.colorSpace,
        transparentBackground: config.transparentBackground,
      );
    } catch (e) {
      throw ServerException(message: 'Failed to create canvas: $e');
    }
  }

  @override
  Future<void> destroyCanvas(int canvasId) async {
    try {
      await _dataSource.destroyCanvas(canvasId);
    } catch (e) {
      throw ServerException(message: 'Failed to destroy canvas: $e');
    }
  }

  @override
  Future<void> resizeCanvas(int canvasId, int width, int height) async {
    try {
      await _dataSource.resizeCanvas(canvasId, width, height);
    } catch (e) {
      throw ServerException(message: 'Failed to resize canvas: $e');
    }
  }

  // -- LayerRepository --

  @override
  Future<LayerEntity> addImageLayer(
      int canvasId, Uint8List rgbaPixels, int width, int height,
      {int index = -1}) async {
    try {
      final layerId = await _dataSource.addImageLayer(
          canvasId, rgbaPixels, width, height,
          index: index);
      final info = await _dataSource.getLayerInfo(canvasId, layerId);
      return LayerEntity.fromLayerInfo(info);
    } catch (e) {
      throw ServerException(message: 'Failed to add image layer: $e');
    }
  }

  @override
  Future<LayerEntity> addSolidColorLayer(
      int canvasId, double r, double g, double b, double a,
      int width, int height,
      {int index = -1}) async {
    try {
      final layerId = await _dataSource.addSolidLayer(
          canvasId, r, g, b, a, width, height,
          index: index);
      final info = await _dataSource.getLayerInfo(canvasId, layerId);
      return LayerEntity.fromLayerInfo(info);
    } catch (e) {
      throw ServerException(message: 'Failed to add solid layer: $e');
    }
  }

  @override
  Future<LayerEntity> addGroupLayer(int canvasId, String name,
      {int index = -1}) async {
    try {
      final layerId =
          await _dataSource.addGroupLayer(canvasId, name, index: index);
      final info = await _dataSource.getLayerInfo(canvasId, layerId);
      return LayerEntity.fromLayerInfo(info);
    } catch (e) {
      throw ServerException(message: 'Failed to add group layer: $e');
    }
  }

  @override
  Future<void> removeLayer(int canvasId, int layerId) async {
    try {
      await _dataSource.removeLayer(canvasId, layerId);
    } catch (e) {
      throw ServerException(message: 'Failed to remove layer: $e');
    }
  }

  @override
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex) async {
    try {
      await _dataSource.reorderLayer(canvasId, layerId, newIndex);
    } catch (e) {
      throw ServerException(message: 'Failed to reorder layer: $e');
    }
  }

  @override
  Future<LayerEntity> duplicateLayer(int canvasId, int layerId) async {
    try {
      final newId = await _dataSource.duplicateLayer(canvasId, layerId);
      final info = await _dataSource.getLayerInfo(canvasId, newId);
      return LayerEntity.fromLayerInfo(info);
    } catch (e) {
      throw ServerException(message: 'Failed to duplicate layer: $e');
    }
  }

  @override
  Future<List<LayerEntity>> getAllLayers(int canvasId) async {
    try {
      final ids = await _dataSource.getLayerIds(canvasId);
      final layers = <LayerEntity>[];
      for (final id in ids) {
        final info = await _dataSource.getLayerInfo(canvasId, id);
        layers.add(LayerEntity.fromLayerInfo(info));
      }
      return layers;
    } catch (e) {
      throw ServerException(message: 'Failed to get layers: $e');
    }
  }

  @override
  Future<LayerEntity> getLayerInfo(int canvasId, int layerId) async {
    try {
      final info = await _dataSource.getLayerInfo(canvasId, layerId);
      return LayerEntity.fromLayerInfo(info);
    } catch (e) {
      throw ServerException(message: 'Failed to get layer info: $e');
    }
  }

  // -- LayerPropertyRepository --

  @override
  Future<void> setVisible(int canvasId, int layerId, bool visible) async {
    try {
      await _dataSource.setLayerVisible(canvasId, layerId, visible);
    } catch (e) {
      throw ServerException(message: 'Failed to set visibility: $e');
    }
  }

  @override
  Future<void> setLocked(int canvasId, int layerId, bool locked) async {
    try {
      await _dataSource.setLayerLocked(canvasId, layerId, locked);
    } catch (e) {
      throw ServerException(message: 'Failed to set locked: $e');
    }
  }

  @override
  Future<void> setOpacity(int canvasId, int layerId, double opacity) async {
    try {
      await _dataSource.setLayerOpacity(canvasId, layerId, opacity);
    } catch (e) {
      throw ServerException(message: 'Failed to set opacity: $e');
    }
  }

  @override
  Future<void> setBlendMode(
      int canvasId, int layerId, BlendMode mode) async {
    try {
      await _dataSource.setLayerBlendMode(canvasId, layerId, mode);
    } catch (e) {
      throw ServerException(message: 'Failed to set blend mode: $e');
    }
  }

  @override
  Future<void> setName(int canvasId, int layerId, String name) async {
    try {
      await _dataSource.setLayerName(canvasId, layerId, name);
    } catch (e) {
      throw ServerException(message: 'Failed to set name: $e');
    }
  }

  @override
  Future<void> setTransform(int canvasId, int layerId,
      {double tx = 0,
      double ty = 0,
      double sx = 1,
      double sy = 1,
      double rotation = 0}) async {
    try {
      await _dataSource.setLayerTransform(canvasId, layerId,
          tx: tx, ty: ty, sx: sx, sy: sy, rotation: rotation);
    } catch (e) {
      throw ServerException(message: 'Failed to set transform: $e');
    }
  }

  // -- RenderRepository --

  @override
  Future<DecodedImage> renderCanvas(int canvasId) async {
    try {
      return await _dataSource.renderCanvas(canvasId);
    } catch (e) {
      throw ServerException(message: 'Failed to render canvas: $e');
    }
  }

  @override
  Future<void> invalidateCanvas(int canvasId) async {
    try {
      await _dataSource.invalidateCanvas(canvasId);
    } catch (e) {
      throw ServerException(message: 'Failed to invalidate canvas: $e');
    }
  }

  // -- ImageImportRepository --

  @override
  Future<DecodedImage> decodeImageFile(String path) async {
    try {
      return await _dataSource.decodeImageFile(path);
    } catch (e) {
      throw ServerException(message: 'Failed to decode image: $e');
    }
  }

  @override
  Future<DecodedImage> decodeImageBytes(Uint8List data) async {
    try {
      return await _dataSource.decodeImageBytes(data);
    } catch (e) {
      throw ServerException(message: 'Failed to decode image bytes: $e');
    }
  }

  @override
  Future<void> encodeToFile(
      DecodedImage image, String path, ImageFormat format,
      {int quality = 85}) async {
    try {
      await _dataSource.encodeToFile(image, path, format, quality: quality);
    } catch (e) {
      throw ServerException(message: 'Failed to encode image: $e');
    }
  }
}
