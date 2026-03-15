import 'package:gopost_app/image_editor/domain/entities/filter_entity.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// ISP: Queries available effects/filters from the engine.
abstract class EffectQueryRepository {
  Future<List<EffectDef>> getAdjustmentEffects();
  Future<List<FilterCategory>> getPresetCategories();
}

/// ISP: Applies adjustments to a layer.
abstract class AdjustmentRepository {
  Future<int> addAdjustment(int canvasId, int layerId, String effectId);
  Future<void> setAdjustmentParam(
      int canvasId, int layerId, int instanceId,
      String paramId, double value);
  Future<void> removeAdjustment(int canvasId, int layerId, int instanceId);
}

/// ISP: Applies preset filters.
/// Returns the filtered image when the engine produced one (caller should replace canvas with it).
abstract class PresetFilterRepository {
  Future<DecodedImage?> applyPreset(
      int canvasId, int layerId, int presetIndex, double intensity);
}
