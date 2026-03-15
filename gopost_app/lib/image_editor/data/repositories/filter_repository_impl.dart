import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/image_editor/domain/entities/filter_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/filter_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

class FilterRepositoryImpl
    implements EffectQueryRepository, AdjustmentRepository, PresetFilterRepository {
  final ImageEditorEngine _engine;

  FilterRepositoryImpl(this._engine);

  @override
  Future<List<EffectDef>> getAdjustmentEffects() async {
    try {
      return await _engine.getEffectsByCategory(EffectCategory.adjustment);
    } catch (e) {
      throw ServerException(message: 'Failed to get adjustments: $e');
    }
  }

  @override
  Future<List<FilterCategory>> getPresetCategories() async {
    try {
      final presets = await _engine.getPresetFilters();
      final grouped = <String, List<FilterPreset>>{};
      for (final p in presets) {
        grouped.putIfAbsent(p.category, () => []);
        grouped[p.category]!.add(FilterPreset.fromInfo(p));
      }
      return grouped.entries
          .map((e) => FilterCategory(name: e.key, filters: e.value))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get presets: $e');
    }
  }

  @override
  Future<int> addAdjustment(int canvasId, int layerId, String effectId) async {
    try {
      return await _engine.addEffectToLayer(canvasId, layerId, effectId);
    } catch (e) {
      throw ServerException(message: 'Failed to add adjustment: $e');
    }
  }

  @override
  Future<void> setAdjustmentParam(
      int canvasId, int layerId, int instanceId,
      String paramId, double value) async {
    try {
      await _engine.setEffectParam(
          canvasId, layerId, instanceId, paramId, value);
    } catch (e) {
      throw ServerException(message: 'Failed to set adjustment: $e');
    }
  }

  @override
  Future<void> removeAdjustment(
      int canvasId, int layerId, int instanceId) async {
    try {
      await _engine.removeEffectFromLayer(canvasId, layerId, instanceId);
    } catch (e) {
      throw ServerException(message: 'Failed to remove adjustment: $e');
    }
  }

  @override
  Future<DecodedImage?> applyPreset(
      int canvasId, int layerId, int presetIndex, double intensity) async {
    try {
      return await _engine.applyPreset(
          canvasId, layerId, presetIndex, intensity);
    } catch (e) {
      throw ServerException(message: 'Failed to apply preset: $e');
    }
  }
}
