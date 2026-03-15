import 'dart:typed_data';

import 'package:gopost_app/image_editor/domain/entities/layer_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// SRP: Adds an image layer from raw RGBA pixels.
class AddImageLayerUseCase {
  final LayerRepository _repository;
  const AddImageLayerUseCase(this._repository);

  Future<LayerEntity> call(
      int canvasId, Uint8List pixels, int width, int height,
      {int index = -1}) {
    return _repository.addImageLayer(canvasId, pixels, width, height,
        index: index);
  }
}

/// SRP: Adds a solid-color fill layer.
class AddSolidLayerUseCase {
  final LayerRepository _repository;
  const AddSolidLayerUseCase(this._repository);

  Future<LayerEntity> call(int canvasId, double r, double g, double b,
      double a, int width, int height,
      {int index = -1}) {
    return _repository.addSolidColorLayer(canvasId, r, g, b, a, width, height,
        index: index);
  }
}

/// SRP: Removes a layer by ID.
class RemoveLayerUseCase {
  final LayerRepository _repository;
  const RemoveLayerUseCase(this._repository);

  Future<void> call(int canvasId, int layerId) {
    return _repository.removeLayer(canvasId, layerId);
  }
}

/// SRP: Reorders a layer to a new position.
class ReorderLayerUseCase {
  final LayerRepository _repository;
  const ReorderLayerUseCase(this._repository);

  Future<void> call(int canvasId, int layerId, int newIndex) {
    return _repository.reorderLayer(canvasId, layerId, newIndex);
  }
}

/// SRP: Duplicates an existing layer.
class DuplicateLayerUseCase {
  final LayerRepository _repository;
  const DuplicateLayerUseCase(this._repository);

  Future<LayerEntity> call(int canvasId, int layerId) {
    return _repository.duplicateLayer(canvasId, layerId);
  }
}

/// SRP: Updates a single layer property (opacity, visibility, blend mode, etc.).
class UpdateLayerPropertyUseCase {
  final LayerPropertyRepository _repository;
  const UpdateLayerPropertyUseCase(this._repository);

  Future<void> setOpacity(int canvasId, int layerId, double opacity) =>
      _repository.setOpacity(canvasId, layerId, opacity);

  Future<void> setVisible(int canvasId, int layerId, bool visible) =>
      _repository.setVisible(canvasId, layerId, visible);

  Future<void> setLocked(int canvasId, int layerId, bool locked) =>
      _repository.setLocked(canvasId, layerId, locked);

  Future<void> setBlendMode(
          int canvasId, int layerId, BlendMode mode) =>
      _repository.setBlendMode(canvasId, layerId, mode);

  Future<void> setName(int canvasId, int layerId, String name) =>
      _repository.setName(canvasId, layerId, name);
}

/// SRP: Fetches all layers for a canvas.
class GetAllLayersUseCase {
  final LayerRepository _repository;
  const GetAllLayersUseCase(this._repository);

  Future<List<LayerEntity>> call(int canvasId) {
    return _repository.getAllLayers(canvasId);
  }
}
