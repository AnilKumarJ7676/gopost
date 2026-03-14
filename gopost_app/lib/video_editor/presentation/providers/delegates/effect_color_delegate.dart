import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/models/video_transition.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/timeline_operations.dart';

/// SRP: Handles effects, color grading, preset filters, and transitions.
class EffectColorDelegate {
  EffectColorDelegate(this._ops);

  final TimelineOperations _ops;

  // -------------------------------------------------------------------------
  // Effects
  // -------------------------------------------------------------------------

  void addEffect(int clipId, VideoEffect effect) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) {
      final exists = c.effects.indexWhere((e) => e.type == effect.type);
      final updated = List<VideoEffect>.from(c.effects);
      if (exists >= 0) {
        updated[exists] = effect;
      } else {
        updated.add(effect);
      }
      return c.copyWith(effects: updated);
    });
    _ops.pushUndo('Add effect', before);
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void removeEffect(int clipId, EffectType type) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(
      effects: c.effects.where((e) => e.type != type).toList(),
    ));
    _ops.pushUndo('Remove effect', before);
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void toggleEffect(int clipId, EffectType type) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(
      effects: c.effects.map((e) {
        if (e.type == type) return e.copyWith(enabled: !e.enabled);
        return e;
      }).toList(),
    ));
    _ops.pushUndo('Toggle effect', before);
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void updateEffectValue(int clipId, EffectType type, double value) {
    _ops.updateClip(clipId, (c) => c.copyWith(
      effects: c.effects.map((e) {
        if (e.type == type) return e.copyWith(value: value);
        return e;
      }).toList(),
    ));
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void clearEffects(int clipId) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(effects: []));
    _ops.pushUndo('Clear effects', before);
    final p = _ops.currentState.project;
    if (p != null) _ops.engine.clearClipEffects(p.timelineId, clipId).catchError((_) {});
    _ops.debouncedRenderFrame();
  }

  // -------------------------------------------------------------------------
  // Color grading
  // -------------------------------------------------------------------------

  void setColorGrading(int clipId, ColorGrading grading) {
    _ops.updateClip(clipId, (c) => c.copyWith(colorGrading: grading));
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void commitColorGrading(int clipId, VideoProject beforeGrading) {
    _ops.pushUndo('Color grading', beforeGrading);
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void setPresetFilter(int clipId, PresetFilterId preset) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    final grading = presetToColorGrading(preset);
    _ops.updateClip(clipId, (c) => c.copyWith(
      presetFilter: preset,
      colorGrading: grading,
    ));
    _ops.pushUndo('Set preset filter', before);
    _ops.syncEffectsToEngine(clipId);
    _ops.debouncedRenderFrame();
  }

  void resetColorGrading(int clipId) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(
      colorGrading: const ColorGrading(),
      presetFilter: PresetFilterId.none,
    ));
    _ops.pushUndo('Reset color grading', before);
    _ops.engine.clearClipEffects(project.timelineId, clipId).catchError((_) {});
    _ops.debouncedRenderFrame();
  }

  /// OCP: Preset-to-grading mapping extracted as a static method so new presets
  /// can be added without modifying callers.
  static ColorGrading presetToColorGrading(PresetFilterId preset) {
    return switch (preset) {
      PresetFilterId.none => const ColorGrading(),
      PresetFilterId.natural => const ColorGrading(saturation: 10, vibrance: 10),
      PresetFilterId.daylight => const ColorGrading(temperature: 15, brightness: 5, saturation: 10),
      PresetFilterId.goldenHour => const ColorGrading(temperature: 40, saturation: 15, highlights: 10),
      PresetFilterId.overcast => const ColorGrading(temperature: -10, contrast: -10, saturation: -15),
      PresetFilterId.portrait => const ColorGrading(contrast: 10, highlights: -10, shadows: 5),
      PresetFilterId.softSkin => const ColorGrading(contrast: -10, highlights: -15, saturation: -5),
      PresetFilterId.studio => const ColorGrading(contrast: 20, brightness: 5),
      PresetFilterId.warmPortrait => const ColorGrading(temperature: 25, contrast: 10, saturation: 10),
      PresetFilterId.vintage => const ColorGrading(saturation: -25, contrast: 15, temperature: 15, hue: 10),
      PresetFilterId.polaroid => const ColorGrading(saturation: -20, contrast: 20, brightness: 10, temperature: 10),
      PresetFilterId.kodachrome => const ColorGrading(saturation: 20, contrast: 25, temperature: 10, vibrance: 15),
      PresetFilterId.retro => const ColorGrading(saturation: -30, contrast: 20, temperature: 20),
      PresetFilterId.cinematic => const ColorGrading(contrast: 20, saturation: -10, temperature: -5, shadows: -15),
      PresetFilterId.tealOrange => const ColorGrading(temperature: -20, tint: -15, saturation: 20, highlights: 15),
      PresetFilterId.noir => const ColorGrading(saturation: -100, contrast: 30),
      PresetFilterId.desaturated => const ColorGrading(saturation: -50),
      PresetFilterId.bwClassic => const ColorGrading(saturation: -100, contrast: 10),
      PresetFilterId.bwHigh => const ColorGrading(saturation: -100, contrast: 40),
      PresetFilterId.bwSelenium => const ColorGrading(saturation: -100, contrast: 15, temperature: 15),
      PresetFilterId.bwInfrared => const ColorGrading(saturation: -100, contrast: 30, highlights: 30),
    };
  }

  // -------------------------------------------------------------------------
  // Transitions
  // -------------------------------------------------------------------------

  void setTransitionIn(int clipId, ClipTransition transition) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(transitionIn: transition));
    _ops.pushUndo('Set transition in', before);
    _ops.engine.setClipTransitionIn(
      project.timelineId, clipId,
      transition.type.index, transition.durationSeconds, transition.easing.index,
    );
    _ops.renderCurrentFrame();
  }

  void setTransitionOut(int clipId, ClipTransition transition) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(transitionOut: transition));
    _ops.pushUndo('Set transition out', before);
    _ops.engine.setClipTransitionOut(
      project.timelineId, clipId,
      transition.type.index, transition.durationSeconds, transition.easing.index,
    );
    _ops.renderCurrentFrame();
  }

  void removeTransitionIn(int clipId) {
    setTransitionIn(clipId, const ClipTransition());
  }

  void removeTransitionOut(int clipId) {
    setTransitionOut(clipId, const ClipTransition());
  }

  // -------------------------------------------------------------------------
  // Clip properties
  // -------------------------------------------------------------------------

  void setClipOpacity(int clipId, double opacity) {
    final project = _ops.currentState.project;
    if (project == null) return;
    _ops.updateClip(clipId, (c) => c.copyWith(opacity: opacity.clamp(0.0, 1.0)));
    _ops.debouncedRenderFrame();
  }

  void commitClipOpacity(int clipId, VideoProject beforeOpacity) {
    _ops.pushUndo('Set opacity', beforeOpacity);
  }

  void setClipBlendMode(int clipId, int blendMode) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(blendMode: blendMode));
    _ops.pushUndo('Set blend mode', before);
    _ops.renderCurrentFrame();
  }

  // -------------------------------------------------------------------------
  // Adjustment layer clips
  // -------------------------------------------------------------------------

  /// Create an adjustment layer clip on the first available effect track,
  /// or create one if none exists. Returns the new clip's ID.
  int? createAdjustmentClip({
    required AdjustmentClipData data,
    required double atTime,
    double duration = 5.0,
  }) {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;

    var effectTrackIndex = project.tracks.indexWhere((t) => t.type == TrackType.effect);
    if (effectTrackIndex < 0) {
      final newTrackIdx = project.tracks.length;
      final newTrack = VideoTrack(
        index: newTrackIdx,
        type: TrackType.effect,
        label: 'Effects',
      );
      _ops.currentState = _ops.currentState.copyWith(
        project: project.copyWith(tracks: [...project.tracks, newTrack]),
      );
      effectTrackIndex = newTrackIdx;
    }

    final clipId = DateTime.now().microsecondsSinceEpoch % 0x7FFFFFFF;
    final resolvedData = data.copyWith(
      style: AdjustmentClipData.inferStyle(data.effects, data.preset),
      label: AdjustmentClipData.buildLabel(data.effects, data.preset),
      colorValue: AdjustmentClipData.pickColor(data.effects, data.preset),
    );

    final clip = VideoClip(
      id: clipId,
      trackIndex: effectTrackIndex,
      sourceType: ClipSourceType.adjustment,
      sourcePath: '',
      displayName: resolvedData.label,
      timelineIn: atTime,
      timelineOut: atTime + duration,
      sourceIn: 0,
      sourceOut: duration,
      adjustmentData: resolvedData,
    );

    final currentProject = _ops.currentState.project!;
    final tracks = currentProject.tracks.map((track) {
      if (track.index == effectTrackIndex) {
        return track.copyWith(clips: [...track.clips, clip]);
      }
      return track;
    }).toList();

    _ops.currentState = _ops.currentState.copyWith(
      project: currentProject.copyWith(tracks: tracks),
      selectedClipId: clipId,
    );
    _ops.pushUndo('Add adjustment clip', before);
    _ops.debouncedRenderFrame();
    return clipId;
  }

  /// Update the adjustment data for an existing adjustment clip.
  void updateAdjustmentClipData(int clipId, AdjustmentClipData data) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null || !clip.isAdjustmentLayer) return;

    final resolvedData = data.copyWith(
      style: AdjustmentClipData.inferStyle(data.effects, data.preset),
      label: AdjustmentClipData.buildLabel(data.effects, data.preset),
      colorValue: AdjustmentClipData.pickColor(data.effects, data.preset),
    );

    _ops.updateClip(clipId, (c) => c.copyWith(adjustmentData: resolvedData));
    _ops.debouncedRenderFrame();
  }

  /// Collect all adjustment layers active at a given time position,
  /// ordered by track index (higher tracks applied later, like Premiere).
  List<AdjustmentClipData> adjustmentLayersAtTime(double time) {
    final project = _ops.currentState.project;
    if (project == null) return const [];
    final results = <AdjustmentClipData>[];
    for (final track in project.tracks) {
      if (track.type != TrackType.effect) continue;
      for (final clip in track.clips) {
        if (!clip.isAdjustmentLayer) continue;
        if (clip.adjustmentData == null) continue;
        if (time >= clip.timelineIn && time < clip.timelineOut) {
          results.add(clip.adjustmentData!);
        }
      }
    }
    return results;
  }

  /// Merge all active adjustment layers into a single [ColorGrading] for compositing.
  ColorGrading compositeAdjustmentGrading(double time) {
    final layers = adjustmentLayersAtTime(time);
    if (layers.isEmpty) return const ColorGrading();
    var result = const ColorGrading();
    for (final layer in layers) {
      if (layer.hasColorGrading || layer.hasPreset) {
        result = _mergeGrading(result, layer.colorGrading);
      }
      for (final effect in layer.effects.where((e) => e.enabled)) {
        result = _applyEffectToGrading(result, effect);
      }
    }
    return result;
  }

  ColorGrading _mergeGrading(ColorGrading base, ColorGrading overlay) {
    return ColorGrading(
      brightness: (base.brightness + overlay.brightness).clamp(-100, 100),
      contrast: (base.contrast + overlay.contrast).clamp(-100, 100),
      saturation: (base.saturation + overlay.saturation).clamp(-100, 100),
      exposure: (base.exposure + overlay.exposure).clamp(-2, 2),
      temperature: (base.temperature + overlay.temperature).clamp(-100, 100),
      tint: (base.tint + overlay.tint).clamp(-100, 100),
      highlights: (base.highlights + overlay.highlights).clamp(-100, 100),
      shadows: (base.shadows + overlay.shadows).clamp(-100, 100),
      vibrance: (base.vibrance + overlay.vibrance).clamp(-100, 100),
      hue: (base.hue + overlay.hue).clamp(-180, 180),
    );
  }

  ColorGrading _applyEffectToGrading(ColorGrading grading, VideoEffect effect) {
    final v = effect.value * effect.mix;
    return switch (effect.type) {
      EffectType.brightness => grading.copyWith(brightness: (grading.brightness + v).clamp(-100, 100)),
      EffectType.contrast => grading.copyWith(contrast: (grading.contrast + v).clamp(-100, 100)),
      EffectType.saturation => grading.copyWith(saturation: (grading.saturation + v).clamp(-100, 100)),
      EffectType.exposure => grading.copyWith(exposure: (grading.exposure + v).clamp(-2, 2)),
      EffectType.temperature => grading.copyWith(temperature: (grading.temperature + v).clamp(-100, 100)),
      EffectType.tint => grading.copyWith(tint: (grading.tint + v).clamp(-100, 100)),
      EffectType.highlights => grading.copyWith(highlights: (grading.highlights + v).clamp(-100, 100)),
      EffectType.shadows => grading.copyWith(shadows: (grading.shadows + v).clamp(-100, 100)),
      EffectType.vibrance => grading.copyWith(vibrance: (grading.vibrance + v).clamp(-100, 100)),
      EffectType.hueRotate => grading.copyWith(hue: (grading.hue + v).clamp(-180, 180)),
      _ => grading,
    };
  }
}
