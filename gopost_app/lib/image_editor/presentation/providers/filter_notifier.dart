import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/entities/filter_entity.dart';
import 'package:gopost_app/image_editor/domain/repositories/filter_repository.dart';
import 'package:gopost_app/image_editor/presentation/providers/canvas_notifier.dart';

class FilterState {
  final List<FilterCategory> categories;
  final int? activePresetIndex;
  final double intensity;
  final bool isLoading;
  final String? error;

  const FilterState({
    this.categories = const [],
    this.activePresetIndex,
    this.intensity = 100,
    this.isLoading = false,
    this.error,
  });

  FilterState copyWith({
    List<FilterCategory>? categories,
    int? activePresetIndex,
    double? intensity,
    bool? isLoading,
    String? error,
  }) => FilterState(
    categories: categories ?? this.categories,
    activePresetIndex: activePresetIndex ?? this.activePresetIndex,
    intensity: intensity ?? this.intensity,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  FilterState clearActive() => FilterState(
    categories: categories,
    activePresetIndex: null,
    intensity: 100,
    isLoading: false,
    error: null,
  );
}

/// SRP: Manages preset filter browsing and application.
class FilterNotifier extends StateNotifier<FilterState> {
  final EffectQueryRepository _queryRepo;
  final PresetFilterRepository _presetRepo;
  final CanvasNotifier _canvasNotifier;

  FilterNotifier(this._queryRepo, this._presetRepo, this._canvasNotifier)
      : super(const FilterState());

  Future<void> loadPresets() async {
    if (state.categories.isNotEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cats = await _queryRepo.getPresetCategories();
      state = state.copyWith(categories: cats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectPreset(
      int canvasId, int layerId, int presetIndex) async {
    if (state.activePresetIndex == presetIndex) {
      state = state.clearActive();
      return;
    }
    state = state.copyWith(activePresetIndex: presetIndex, intensity: 100);
    try {
      final result = await _presetRepo.applyPreset(
          canvasId, layerId, presetIndex, state.intensity);
      if (result != null) {
        await _canvasNotifier.replaceWithImage(result);
      }
    } catch (e) {
      // Revert selection so UI does not stay in broken state; surface error.
      state = state.clearActive().copyWith(error: e.toString());
    }
  }

  Future<void> setIntensity(
      int canvasId, int layerId, double intensity) async {
    if (state.activePresetIndex == null) return;
    final previousIntensity = state.intensity;
    state = state.copyWith(intensity: intensity);
    try {
      final result = await _presetRepo.applyPreset(
          canvasId, layerId, state.activePresetIndex!, intensity);
      if (result != null) {
        await _canvasNotifier.replaceWithImage(result);
      }
    } catch (e) {
      debugPrint('FilterNotifier.setIntensity failed: $e');
      state = state.copyWith(intensity: previousIntensity, error: e.toString());
    }
  }

  void clearFilter() {
    state = state.clearActive();
  }
}
