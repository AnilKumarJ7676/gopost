import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/entities/filter_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/filter_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

class AdjustmentState {
  final List<AdjustmentValue> adjustments;
  final Map<String, int> instanceIds;
  final bool isLoading;
  final String? error;

  const AdjustmentState({
    this.adjustments = const [],
    this.instanceIds = const {},
    this.isLoading = false,
    this.error,
  });

  AdjustmentState copyWith({
    List<AdjustmentValue>? adjustments,
    Map<String, int>? instanceIds,
    bool? isLoading,
    String? error,
  }) => AdjustmentState(
    adjustments: adjustments ?? this.adjustments,
    instanceIds: instanceIds ?? this.instanceIds,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  bool get hasChanges => adjustments.any((a) => !a.isDefault);
}

/// SRP: Manages adjustment slider values and engine synchronization.
class AdjustmentNotifier extends StateNotifier<AdjustmentState> {
  final EffectQueryRepository _queryRepo;
  final AdjustmentRepository _adjustRepo;

  AdjustmentNotifier(this._queryRepo, this._adjustRepo)
      : super(const AdjustmentState());

  Future<void> loadAdjustments() async {
    if (state.adjustments.isNotEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final defs = await _queryRepo.getAdjustmentEffects();
      final adjustments = defs.map((d) {
        final param = d.params.isNotEmpty ? d.params.first : null;
        return AdjustmentValue(
          effectId: d.id,
          displayName: d.displayName,
          value: param?.defaultValue ?? 0,
          defaultValue: param?.defaultValue ?? 0,
          minValue: param?.minValue ?? -100,
          maxValue: param?.maxValue ?? 100,
        );
      }).toList();
      state = state.copyWith(adjustments: adjustments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setAdjustment(
      int canvasId, int layerId, String effectId, double value) async {
    final idx = state.adjustments.indexWhere((a) => a.effectId == effectId);
    if (idx < 0) return;

    final updated = List<AdjustmentValue>.from(state.adjustments);
    updated[idx] = updated[idx].copyWith(value: value);
    state = state.copyWith(adjustments: updated);

    try {
      int? instanceId = state.instanceIds[effectId];
      if (instanceId == null) {
        instanceId = await _adjustRepo.addAdjustment(
            canvasId, layerId, effectId);
        final ids = Map<String, int>.from(state.instanceIds);
        ids[effectId] = instanceId;
        state = state.copyWith(instanceIds: ids);
      }
      final adj = updated[idx];
      final paramId = adj.effectId.split('.').last;
      await _adjustRepo.setAdjustmentParam(
          canvasId, layerId, instanceId, paramId, value);
    } catch (e) {
      debugPrint('AdjustmentNotifier.setAdjustment failed: $e');
    }
  }

  Future<void> resetAdjustment(
      int canvasId, int layerId, String effectId) async {
    final idx = state.adjustments.indexWhere((a) => a.effectId == effectId);
    if (idx < 0) return;

    final updated = List<AdjustmentValue>.from(state.adjustments);
    updated[idx] = updated[idx].copyWith(value: updated[idx].defaultValue);
    state = state.copyWith(adjustments: updated);

    final instanceId = state.instanceIds[effectId];
    if (instanceId != null) {
      try {
        await _adjustRepo.removeAdjustment(canvasId, layerId, instanceId);
        final ids = Map<String, int>.from(state.instanceIds);
        ids.remove(effectId);
        state = state.copyWith(instanceIds: ids);
      } catch (e) {
        debugPrint('AdjustmentNotifier.resetAdjustment failed: $e');
      }
    }
  }

  Future<void> resetAll(int canvasId, int layerId) async {
    for (final entry in state.instanceIds.entries) {
      try {
        await _adjustRepo.removeAdjustment(canvasId, layerId, entry.value);
      } catch (_) {}
    }
    final reset = state.adjustments
        .map((a) => a.copyWith(value: a.defaultValue))
        .toList();
    state = state.copyWith(adjustments: reset, instanceIds: {});
  }
}
