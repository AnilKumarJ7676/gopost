import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/image_editor/domain/repositories/mask_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

class MaskRepositoryImpl implements MaskRepository {
  final LayerMaskManager _maskManager;

  MaskRepositoryImpl(this._maskManager);

  @override
  Future<void> addMask(int canvasId, int layerId, MaskType type) async {
    try {
      await _maskManager.addMask(canvasId, layerId, type);
    } catch (e) {
      throw ServerException(message: 'Add mask failed: $e');
    }
  }

  @override
  Future<void> removeMask(int canvasId, int layerId) async {
    try {
      await _maskManager.removeMask(canvasId, layerId);
    } catch (e) {
      throw ServerException(message: 'Remove mask failed: $e');
    }
  }

  @override
  Future<bool> hasMask(int canvasId, int layerId) async {
    try {
      return await _maskManager.hasMask(canvasId, layerId);
    } catch (e) {
      throw ServerException(message: 'Query mask failed: $e');
    }
  }

  @override
  Future<void> invertMask(int canvasId, int layerId) async {
    try {
      await _maskManager.invertMask(canvasId, layerId);
    } catch (e) {
      throw ServerException(message: 'Invert mask failed: $e');
    }
  }

  @override
  Future<void> setMaskEnabled(int canvasId, int layerId, bool enabled) async {
    try {
      await _maskManager.setMaskEnabled(canvasId, layerId, enabled);
    } catch (e) {
      throw ServerException(message: 'Set mask enabled failed: $e');
    }
  }

  @override
  Future<void> paintMask(
    int canvasId, int layerId,
    double cx, double cy,
    double radius, double hardness,
    MaskBrushMode mode, double opacity,
  ) async {
    try {
      await _maskManager.maskPaint(canvasId, layerId, cx, cy, radius, hardness, mode, opacity);
    } catch (e) {
      throw ServerException(message: 'Paint mask failed: $e');
    }
  }

  @override
  Future<void> fillMask(int canvasId, int layerId, int value) async {
    try {
      await _maskManager.maskFill(canvasId, layerId, value);
    } catch (e) {
      throw ServerException(message: 'Fill mask failed: $e');
    }
  }
}
