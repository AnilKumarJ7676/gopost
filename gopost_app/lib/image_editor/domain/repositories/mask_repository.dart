import 'package:gopost_app/rendering_bridge/engine_api.dart';

abstract class MaskRepository {
  Future<void> addMask(int canvasId, int layerId, MaskType type);
  Future<void> removeMask(int canvasId, int layerId);
  Future<bool> hasMask(int canvasId, int layerId);
  Future<void> invertMask(int canvasId, int layerId);
  Future<void> setMaskEnabled(int canvasId, int layerId, bool enabled);
  Future<void> paintMask(
    int canvasId, int layerId,
    double cx, double cy,
    double radius, double hardness,
    MaskBrushMode mode, double opacity,
  );
  Future<void> fillMask(int canvasId, int layerId, int value);
}
