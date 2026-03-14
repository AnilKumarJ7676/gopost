import 'dart:typed_data';

import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// SRP: Adapter between the domain layer and the native engine FFI.
/// DIP: Depends on abstract ImageEditorEngine, not the FFI implementation.
abstract class EngineCanvasDataSource {
  Future<int> createCanvas(CanvasConfig config);
  Future<void> destroyCanvas(int canvasId);
  Future<({int width, int height, double dpi})> getCanvasSize(int canvasId);
  Future<void> resizeCanvas(int canvasId, int width, int height);

  Future<int> addImageLayer(
      int canvasId, Uint8List pixels, int width, int height,
      {int index = -1});
  Future<int> addSolidLayer(
      int canvasId, double r, double g, double b, double a,
      int width, int height,
      {int index = -1});
  Future<int> addGroupLayer(int canvasId, String name, {int index = -1});
  Future<void> removeLayer(int canvasId, int layerId);
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex);
  Future<int> duplicateLayer(int canvasId, int layerId);

  Future<int> getLayerCount(int canvasId);
  Future<LayerInfo> getLayerInfo(int canvasId, int layerId);
  Future<List<int>> getLayerIds(int canvasId);

  Future<void> setLayerVisible(int canvasId, int layerId, bool visible);
  Future<void> setLayerLocked(int canvasId, int layerId, bool locked);
  Future<void> setLayerOpacity(int canvasId, int layerId, double opacity);
  Future<void> setLayerBlendMode(
      int canvasId, int layerId, BlendMode blendMode);
  Future<void> setLayerName(int canvasId, int layerId, String name);
  Future<void> setLayerTransform(int canvasId, int layerId,
      {double tx, double ty, double sx, double sy, double rotation});

  Future<DecodedImage> renderCanvas(int canvasId);
  Future<void> invalidateCanvas(int canvasId);

  Future<DecodedImage> decodeImageFile(String path);
  Future<DecodedImage> decodeImageBytes(Uint8List data);
  Future<void> encodeToFile(
      DecodedImage image, String path, ImageFormat format,
      {int quality = 85});
}

/// LSP: Substitutable implementation backed by ImageEditorEngine.
class EngineCanvasDataSourceImpl implements EngineCanvasDataSource {
  final ImageEditorEngine _engine;

  EngineCanvasDataSourceImpl(this._engine);

  @override
  Future<int> createCanvas(CanvasConfig config) =>
      _engine.createCanvas(config);

  @override
  Future<void> destroyCanvas(int canvasId) =>
      _engine.destroyCanvas(canvasId);

  @override
  Future<({int width, int height, double dpi})> getCanvasSize(int canvasId) =>
      _engine.getCanvasSize(canvasId);

  @override
  Future<void> resizeCanvas(int canvasId, int width, int height) =>
      _engine.resizeCanvas(canvasId, width, height);

  @override
  Future<int> addImageLayer(
          int canvasId, Uint8List pixels, int width, int height,
          {int index = -1}) =>
      _engine.addImageLayer(canvasId, pixels, width, height, index: index);

  @override
  Future<int> addSolidLayer(int canvasId, double r, double g, double b,
          double a, int width, int height,
          {int index = -1}) =>
      _engine.addSolidLayer(canvasId, r, g, b, a, width, height,
          index: index);

  @override
  Future<int> addGroupLayer(int canvasId, String name, {int index = -1}) =>
      _engine.addGroupLayer(canvasId, name, index: index);

  @override
  Future<void> removeLayer(int canvasId, int layerId) =>
      _engine.removeLayer(canvasId, layerId);

  @override
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex) =>
      _engine.reorderLayer(canvasId, layerId, newIndex);

  @override
  Future<int> duplicateLayer(int canvasId, int layerId) =>
      _engine.duplicateLayer(canvasId, layerId);

  @override
  Future<int> getLayerCount(int canvasId) =>
      _engine.getLayerCount(canvasId);

  @override
  Future<LayerInfo> getLayerInfo(int canvasId, int layerId) =>
      _engine.getLayerInfo(canvasId, layerId);

  @override
  Future<List<int>> getLayerIds(int canvasId) =>
      _engine.getLayerIds(canvasId);

  @override
  Future<void> setLayerVisible(int canvasId, int layerId, bool visible) =>
      _engine.setLayerVisible(canvasId, layerId, visible);

  @override
  Future<void> setLayerLocked(int canvasId, int layerId, bool locked) =>
      _engine.setLayerLocked(canvasId, layerId, locked);

  @override
  Future<void> setLayerOpacity(int canvasId, int layerId, double opacity) =>
      _engine.setLayerOpacity(canvasId, layerId, opacity);

  @override
  Future<void> setLayerBlendMode(
          int canvasId, int layerId, BlendMode blendMode) =>
      _engine.setLayerBlendMode(canvasId, layerId, blendMode);

  @override
  Future<void> setLayerName(int canvasId, int layerId, String name) =>
      _engine.setLayerName(canvasId, layerId, name);

  @override
  Future<void> setLayerTransform(int canvasId, int layerId,
          {double tx = 0,
          double ty = 0,
          double sx = 1,
          double sy = 1,
          double rotation = 0}) =>
      _engine.setLayerTransform(canvasId, layerId,
          tx: tx, ty: ty, sx: sx, sy: sy, rotation: rotation);

  @override
  Future<DecodedImage> renderCanvas(int canvasId) =>
      _engine.renderCanvas(canvasId);

  @override
  Future<void> invalidateCanvas(int canvasId) =>
      _engine.invalidateCanvas(canvasId);

  @override
  Future<DecodedImage> decodeImageFile(String path) =>
      _engine.decodeImageFile(path);

  @override
  Future<DecodedImage> decodeImageBytes(Uint8List data) =>
      _engine.decodeImage(data);

  @override
  Future<void> encodeToFile(
          DecodedImage image, String path, ImageFormat format,
          {int quality = 85}) =>
      _engine.encodeToFile(image, path, format, quality: quality);
}
