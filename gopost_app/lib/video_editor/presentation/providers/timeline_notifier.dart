import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/video_engine_providers.dart';
import 'package:gopost_app/video_editor/domain/models/editor_command.dart';
import 'package:gopost_app/video_editor/domain/models/playback_state.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/models/video_transition.dart';
import 'package:gopost_app/video_editor/domain/services/proxy_service.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/advanced_edit_delegate.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/effect_color_delegate.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/keyframe_audio_delegate.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/playback_delegate.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/timeline_operations.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/track_clip_delegate.dart';
import 'package:gopost_app/video_editor/presentation/providers/proxy_provider.dart';

const int kPreviewWidth = 640;
const int kPreviewHeight = 360;
const double kDefaultFps = 30.0;

final timelineNotifierProvider =
    StateNotifierProvider.autoDispose<TimelineNotifier, TimelineState>((ref) {
  final engine = ref.watch(videoTimelineEngineProvider);
  final proxyService = ref.watch(proxyGenerationServiceProvider);
  return TimelineNotifier(engine, proxyService);
});

enum TimelinePhase { idle, initializing, ready, error }
enum BottomPanelTab { timeline, effects, colorGrading, transitions, keyframes, audio, text, inspector, transform, speed, markers, adjustmentLayers }

class TimelineState {
  final TimelinePhase phase;
  final VideoProject? project;
  final PlaybackState playback;
  final int? selectedClipId;
  final double pixelsPerSecond;
  final double scrollOffset;
  final String? errorMessage;
  final bool canUndo;
  final bool canRedo;
  final BottomPanelTab activePanel;
  final bool useProxyPlayback;

  const TimelineState({
    this.phase = TimelinePhase.idle,
    this.project,
    this.playback = const PlaybackState(),
    this.selectedClipId,
    this.pixelsPerSecond = 80,
    this.scrollOffset = 0,
    this.errorMessage,
    this.canUndo = false,
    this.canRedo = false,
    this.activePanel = BottomPanelTab.timeline,
    this.useProxyPlayback = true,
  });

  bool get isReady => phase == TimelinePhase.ready;
  double get duration => project?.duration ?? 0;
  List<VideoTrack> get tracks => project?.tracks ?? [];
  VideoClip? get selectedClip => selectedClipId != null ? project?.findClip(selectedClipId!) : null;

  TimelineState copyWith({
    TimelinePhase? phase,
    VideoProject? project,
    PlaybackState? playback,
    int? selectedClipId,
    bool clearSelection = false,
    double? pixelsPerSecond,
    double? scrollOffset,
    String? errorMessage,
    bool clearError = false,
    bool? canUndo,
    bool? canRedo,
    BottomPanelTab? activePanel,
    bool? useProxyPlayback,
  }) {
    return TimelineState(
      phase: phase ?? this.phase,
      project: project ?? this.project,
      playback: playback ?? this.playback,
      selectedClipId: clearSelection ? null : (selectedClipId ?? this.selectedClipId),
      pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      activePanel: activePanel ?? this.activePanel,
      useProxyPlayback: useProxyPlayback ?? this.useProxyPlayback,
    );
  }
}

/// SRP: [TimelineNotifier] is now a thin facade that delegates to focused
/// sub-handlers. It implements [TimelineOperations] to provide shared
/// state access to all delegates.
///
/// Each delegate owns a single responsibility:
/// - [PlaybackDelegate]: play, pause, seek, render
/// - [TrackClipDelegate]: track/clip CRUD, move, trim, split
/// - [EffectColorDelegate]: effects, color grading, transitions
/// - [KeyframeAudioDelegate]: keyframes, audio controls
/// - [AdvancedEditDelegate]: NLE edits, markers, proxy, AI, speed
class TimelineNotifier extends StateNotifier<TimelineState>
    implements TimelineOperations {
  TimelineNotifier(this._engine, this._proxyService)
      : super(const TimelineState()) {
    _playback = PlaybackDelegate(this);
    _trackClip = TrackClipDelegate(this);
    _effectColor = EffectColorDelegate(this);
    _keyframeAudio = KeyframeAudioDelegate(this);
    _advancedEdit = AdvancedEditDelegate(this);
  }

  final VideoTimelineEngine _engine;
  final ProxyService _proxyService;
  final UndoRedoStack _undoRedo = UndoRedoStack();

  late final PlaybackDelegate _playback;
  late final TrackClipDelegate _trackClip;
  late final EffectColorDelegate _effectColor;
  late final KeyframeAudioDelegate _keyframeAudio;
  late final AdvancedEditDelegate _advancedEdit;

  // =========================================================================
  // TimelineOperations implementation (shared context for all delegates)
  // =========================================================================

  @override
  TimelineState get currentState => state;

  @override
  set currentState(TimelineState newState) => state = newState;

  @override
  VideoTimelineEngine get engine => _engine;

  @override
  ProxyService get proxyService => _proxyService;

  @override
  UndoRedoStack get undoRedo => _undoRedo;

  @override
  bool get isMounted => mounted;

  @override
  void pushUndo(String description, VideoProject before) {
    final after = state.project;
    if (after == null) return;
    _undoRedo.push(EditorCommand(
      description: description,
      stateBefore: before,
      stateAfter: after,
    ));
    syncUndoRedoState();
  }

  @override
  void syncUndoRedoState() {
    state = state.copyWith(
      canUndo: _undoRedo.canUndo,
      canRedo: _undoRedo.canRedo,
    );
  }

  @override
  void updateClip(int clipId, VideoClip Function(VideoClip) updater) {
    final project = state.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null) return;
    final updated = updater(clip);
    final tracks = project.tracks.map((track) {
      return track.copyWith(
        clips: track.clips.map((c) => c.id == clipId ? updated : c).toList(),
      );
    }).toList();
    state = state.copyWith(project: project.copyWith(tracks: tracks));
  }

  @override
  Future<void> renderCurrentFrame() => _playback.renderCurrentFrame();

  @override
  void debouncedRenderFrame() => _playback.debouncedRenderFrame();

  @override
  void throttledRenderFrame() => _playback.throttledRenderFrame();

  @override
  void updateActiveVideo({double? posOverride}) {
    final project = state.project;
    if (project == null) return;
    final pos = posOverride ?? state.playback.positionSeconds;
    String? activePath;
    for (final track in project.tracks) {
      if (!track.isVisible) continue;
      for (final clip in track.clips) {
        if (clip.sourceType == ClipSourceType.video &&
            pos >= clip.timelineIn &&
            pos < clip.timelineOut) {
          activePath = resolvePlaybackPath(clip);
          break;
        }
      }
      if (activePath != null) break;
    }
    if (activePath != state.playback.activeVideoPath) {
      state = state.copyWith(
        playback: state.playback.copyWith(
          activeVideoPath: activePath,
          clearVideoPath: activePath == null,
        ),
      );
    }
  }

  @override
  String resolvePlaybackPath(VideoClip clip) {
    if (state.useProxyPlayback &&
        clip.proxyStatus == ProxyStatus.ready &&
        clip.proxyPath != null) {
      return clip.proxyPath!;
    }
    return clip.sourcePath;
  }

  @override
  VideoClipSourceType toEngineSourceType(ClipSourceType type) {
    return switch (type) {
      ClipSourceType.video => VideoClipSourceType.video,
      ClipSourceType.image => VideoClipSourceType.image,
      ClipSourceType.title => VideoClipSourceType.title,
      ClipSourceType.color => VideoClipSourceType.color,
      ClipSourceType.adjustment => VideoClipSourceType.color,
    };
  }

  @override
  Future<VideoProject> syncNativeToProject(VideoProject target) async {
    final currentProject = state.project;
    if (currentProject == null) return target;
    final tlId = currentProject.timelineId;

    for (final clip in currentProject.allClips) {
      try { await _engine.removeClip(tlId, clip.id); } catch (_) {}
    }

    final oldToNewClipId = <int, int>{};
    final clipsOrdered = List<VideoClip>.from(target.allClips)
      ..sort((a, b) {
        final ti = a.trackIndex.compareTo(b.trackIndex);
        if (ti != 0) return ti;
        return a.timelineIn.compareTo(b.timelineIn);
      });

    for (final clip in clipsOrdered) {
      try {
        final newId = await _engine.addClip(tlId, ClipDescriptor(
          trackIndex: clip.trackIndex,
          sourceType: toEngineSourceType(clip.sourceType),
          sourcePath: resolvePlaybackPath(clip),
          timelineRange: TimelineRange(inTime: clip.timelineIn, outTime: clip.timelineOut),
          sourceRange: SourceRange(sourceIn: clip.sourceIn, sourceOut: clip.sourceOut),
          speed: clip.speed,
          opacity: clip.opacity,
          blendMode: clip.blendMode,
          effectHash: clip.effectHash,
        ));
        oldToNewClipId[clip.id] = newId;
      } catch (_) {}
    }

    final newTracks = target.tracks.map((t) {
      final newClips = t.clips
          .map((c) => c.copyWith(id: oldToNewClipId[c.id] ?? c.id))
          .toList();
      return t.copyWith(clips: newClips);
    }).toList();
    final remapped = VideoProject(
      timelineId: tlId,
      frameRate: target.frameRate,
      width: target.width,
      height: target.height,
      tracks: newTracks,
      markers: target.markers,
    );

    for (final clip in remapped.allClips) {
      restoreClipS10State(tlId, clip);
    }
    return remapped;
  }

  @override
  void restoreClipS10State(int tlId, VideoClip clip) {
    double brightness = clip.colorGrading.brightness;
    double contrast = clip.colorGrading.contrast;
    double saturation = clip.colorGrading.saturation;
    double exposure = clip.colorGrading.exposure;
    double temperature = clip.colorGrading.temperature;
    double tint = clip.colorGrading.tint;
    double highlights = clip.colorGrading.highlights;
    double shadows = clip.colorGrading.shadows;
    double vibrance = clip.colorGrading.vibrance;
    double hue = clip.colorGrading.hue;
    for (final fx in clip.effects) {
      if (!fx.enabled) continue;
      switch (fx.type) {
        case EffectType.brightness: brightness += fx.value; break;
        case EffectType.contrast: contrast += fx.value; break;
        case EffectType.saturation: saturation += fx.value; break;
        case EffectType.exposure: exposure += fx.value; break;
        case EffectType.temperature: temperature += fx.value; break;
        case EffectType.tint: tint += fx.value; break;
        case EffectType.highlights: highlights += fx.value; break;
        case EffectType.shadows: shadows += fx.value; break;
        case EffectType.vibrance: vibrance += fx.value; break;
        case EffectType.hueRotate: hue += fx.value; break;
        default: break;
      }
    }
    if (!clip.colorGrading.isDefault || clip.effects.isNotEmpty) {
      _engine.setClipColorGrading(tlId, clip.id,
        brightness: brightness, contrast: contrast,
        saturation: saturation, exposure: exposure,
        temperature: temperature, tint: tint,
        highlights: highlights, shadows: shadows,
        vibrance: vibrance, hue: hue,
      ).catchError((_) {});
    }
    if (!clip.transitionIn.isNone) {
      _engine.setClipTransitionIn(tlId, clip.id,
        clip.transitionIn.type.index, clip.transitionIn.durationSeconds, clip.transitionIn.easing.index)
        .catchError((_) {});
    }
    if (!clip.transitionOut.isNone) {
      _engine.setClipTransitionOut(tlId, clip.id,
        clip.transitionOut.type.index, clip.transitionOut.durationSeconds, clip.transitionOut.easing.index)
        .catchError((_) {});
    }
    for (final track in clip.keyframes.tracks) {
      for (final kf in track.keyframes) {
        _engine.setClipKeyframe(tlId, clip.id,
          track.property.index, kf.time, kf.value, kf.interpolation.index)
          .catchError((_) {});
      }
    }
    _engine.setClipVolume(tlId, clip.id, clip.audio.volume).catchError((_) {});
    _engine.setClipPan(tlId, clip.id, clip.audio.pan).catchError((_) {});
    if (clip.audio.fadeInSeconds > 0) {
      _engine.setClipFadeIn(tlId, clip.id, clip.audio.fadeInSeconds).catchError((_) {});
    }
    if (clip.audio.fadeOutSeconds > 0) {
      _engine.setClipFadeOut(tlId, clip.id, clip.audio.fadeOutSeconds).catchError((_) {});
    }
  }

  @override
  void syncEffectsToEngine(int clipId) {
    final project = state.project;
    if (project == null) return;
    final clip = project.allClips.where((c) => c.id == clipId).firstOrNull;
    if (clip == null) return;
    double brightness = clip.colorGrading.brightness;
    double contrast = clip.colorGrading.contrast;
    double saturation = clip.colorGrading.saturation;
    double exposure = clip.colorGrading.exposure;
    double temperature = clip.colorGrading.temperature;
    double tint = clip.colorGrading.tint;
    double highlights = clip.colorGrading.highlights;
    double shadows = clip.colorGrading.shadows;
    double vibrance = clip.colorGrading.vibrance;
    double hue = clip.colorGrading.hue;
    for (final fx in clip.effects) {
      if (!fx.enabled) continue;
      switch (fx.type) {
        case EffectType.brightness: brightness += fx.value; break;
        case EffectType.contrast: contrast += fx.value; break;
        case EffectType.saturation: saturation += fx.value; break;
        case EffectType.exposure: exposure += fx.value; break;
        case EffectType.temperature: temperature += fx.value; break;
        case EffectType.tint: tint += fx.value; break;
        case EffectType.highlights: highlights += fx.value; break;
        case EffectType.shadows: shadows += fx.value; break;
        case EffectType.vibrance: vibrance += fx.value; break;
        case EffectType.hueRotate: hue += fx.value; break;
        default: break;
      }
    }
    _engine.setClipColorGrading(
      project.timelineId, clipId,
      brightness: brightness, contrast: contrast,
      saturation: saturation, exposure: exposure,
      temperature: temperature, tint: tint,
      highlights: highlights, shadows: shadows,
      vibrance: vibrance, hue: hue,
    ).catchError((_) {});
  }

  // =========================================================================
  // Undo / Redo
  // =========================================================================

  Future<void> undo() async {
    final cmd = _undoRedo.undo();
    if (cmd == null) return;
    final remapped = await syncNativeToProject(cmd.stateBefore);
    state = state.copyWith(project: remapped, clearSelection: true);
    syncUndoRedoState();
    await renderCurrentFrame();
  }

  Future<void> redo() async {
    final cmd = _undoRedo.redo();
    if (cmd == null) return;
    final remapped = await syncNativeToProject(cmd.stateAfter);
    state = state.copyWith(project: remapped, clearSelection: true);
    syncUndoRedoState();
    await renderCurrentFrame();
  }

  // =========================================================================
  // Timeline lifecycle
  // =========================================================================

  Future<void> initTimeline() async {
    if (state.phase == TimelinePhase.initializing ||
        state.phase == TimelinePhase.ready) {
      return;
    }
    state = state.copyWith(phase: TimelinePhase.initializing, clearError: true);

    try {
      final id = await _engine.createTimeline(const TimelineConfig(
        frameRate: kDefaultFps,
        width: kPreviewWidth,
        height: kPreviewHeight,
      ));

      final effectTrackIdx = await _engine.addTrack(id, VideoTrackType.effect);
      final videoTrackIdx = await _engine.addTrack(id, VideoTrackType.video);
      final audioTrackIdx = await _engine.addTrack(id, VideoTrackType.audio);

      final fxLabel = _trackClip.nextTrackLabel;
      final vLabel = _trackClip.nextTrackLabel;
      final aLabel = _trackClip.nextTrackLabel;

      final project = VideoProject(
        timelineId: id,
        frameRate: kDefaultFps,
        width: kPreviewWidth,
        height: kPreviewHeight,
        tracks: [
          VideoTrack(index: effectTrackIdx, type: TrackType.effect, label: 'FX$fxLabel'),
          VideoTrack(index: videoTrackIdx, type: TrackType.video, label: 'V$vLabel'),
          VideoTrack(index: audioTrackIdx, type: TrackType.audio, label: 'A$aLabel'),
        ],
      );

      state = state.copyWith(
        phase: TimelinePhase.ready,
        project: project,
        playback: const PlaybackState(status: PlaybackStatus.stopped),
      );

      await renderCurrentFrame();
    } catch (e) {
      state = state.copyWith(
        phase: TimelinePhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadProject(VideoProject project) async {
    if (state.phase == TimelinePhase.initializing) return;
    if (project.tracks.isEmpty) return;
    state = state.copyWith(phase: TimelinePhase.initializing, clearError: true);

    try {
      final w = project.width > 0 ? project.width : kPreviewWidth;
      final h = project.height > 0 ? project.height : kPreviewHeight;
      final tlId = await _engine.createTimeline(TimelineConfig(
        frameRate: project.frameRate,
        width: w,
        height: h,
      ));

      final sortedTracks = List<VideoTrack>.from(project.tracks)
        ..sort((a, b) => a.index.compareTo(b.index));
      for (final track in sortedTracks) {
        final engineType = switch (track.type) {
          TrackType.audio => VideoTrackType.audio,
          TrackType.title => VideoTrackType.title,
          TrackType.effect => VideoTrackType.effect,
          TrackType.subtitle => VideoTrackType.subtitle,
          TrackType.video => VideoTrackType.video,
        };
        await _engine.addTrack(tlId, engineType);
      }

      final oldToNewClipId = <int, int>{};
      final clipsOrdered = List<VideoClip>.from(project.allClips)
        ..sort((a, b) {
          final ti = a.trackIndex.compareTo(b.trackIndex);
          if (ti != 0) return ti;
          return a.timelineIn.compareTo(b.timelineIn);
        });

      for (final clip in clipsOrdered) {
        final descriptor = ClipDescriptor(
          trackIndex: clip.trackIndex,
          sourceType: toEngineSourceType(clip.sourceType),
          sourcePath: resolvePlaybackPath(clip),
          timelineRange: TimelineRange(inTime: clip.timelineIn, outTime: clip.timelineOut),
          sourceRange: SourceRange(sourceIn: clip.sourceIn, sourceOut: clip.sourceOut),
          speed: clip.speed,
          opacity: clip.opacity,
          blendMode: clip.blendMode,
          effectHash: clip.effectHash,
        );
        final newId = await _engine.addClip(tlId, descriptor);
        oldToNewClipId[clip.id] = newId;
      }

      final newTracks = project.tracks.map((t) {
        final newClips = t.clips
            .map((c) => c.copyWith(id: oldToNewClipId[c.id] ?? c.id))
            .toList();
        return t.copyWith(clips: newClips);
      }).toList();
      final newProject = VideoProject(
        timelineId: tlId,
        frameRate: project.frameRate,
        width: w,
        height: h,
        tracks: newTracks,
      );

      for (final clip in newProject.allClips) {
        restoreClipS10State(tlId, clip);
      }
      for (final track in newProject.tracks) {
        if (track.isMuted) _engine.setTrackMute(tlId, track.index, true).catchError((_) {});
        if (track.isSolo) _engine.setTrackSolo(tlId, track.index, true).catchError((_) {});
      }

      state = state.copyWith(
        phase: TimelinePhase.ready,
        project: newProject,
        playback: const PlaybackState(status: PlaybackStatus.stopped),
      );
      _trackClip.autoSelectClipIfNeeded();
      await renderCurrentFrame();

      await _advancedEdit.verifyProxies();
    } catch (e) {
      state = state.copyWith(
        phase: TimelinePhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  // =========================================================================
  // Delegated: Playback
  // =========================================================================

  void play() => _playback.play();
  void pause() => _playback.pause();
  void togglePlayback() => _playback.togglePlayback();
  Future<void> seek(double seconds) => _playback.seek(seconds);
  void stepForward() => _playback.stepForward();
  void stepBackward() => _playback.stepBackward();
  void stepForwardN(int frames) => _playback.stepForwardN(frames);
  void stepBackwardN(int frames) => _playback.stepBackwardN(frames);
  void setZoom(double pps) => _playback.setZoom(pps);
  void zoomIn() => _playback.zoomIn();
  void zoomOut() => _playback.zoomOut();
  void setScrollOffset(double offset) => _playback.setScrollOffset(offset);

  // JKL shuttle
  void shuttleForward() => _playback.shuttleForward();
  void shuttleReverse() => _playback.shuttleReverse();
  void shuttleStop() => _playback.shuttleStop();

  // Jump to start / end
  void jumpToStart() => _playback.jumpToStart();
  void jumpToEnd() => _playback.jumpToEnd();

  // In / Out points
  void setInPoint() => _playback.setInPoint();
  void setOutPoint() => _playback.setOutPoint();
  void clearInOutPoints() => _playback.clearInOutPoints();

  // Scrub
  void beginScrub() => _playback.beginScrub();
  void endScrub() => _playback.endScrub();
  void scrubTo(double seconds) => _playback.scrubTo(seconds, snapPoints: _playback.snapPoints);

  // Snap points
  List<double> get snapPoints => _playback.snapPoints;
  void jumpToNextSnapPoint() => _playback.jumpToNextSnapPoint();
  void jumpToPreviousSnapPoint() => _playback.jumpToPreviousSnapPoint();

  void setActivePanel(BottomPanelTab tab) {
    state = state.copyWith(activePanel: tab);
    const clipPanels = {
      BottomPanelTab.effects, BottomPanelTab.colorGrading,
      BottomPanelTab.transitions, BottomPanelTab.transform,
      BottomPanelTab.speed, BottomPanelTab.keyframes,
      BottomPanelTab.audio, BottomPanelTab.inspector,
    };
    if (clipPanels.contains(tab)) _trackClip.autoSelectClipIfNeeded();
  }

  // =========================================================================
  // Delegated: Track / Clip
  // =========================================================================

  Future<void> addTrack(TrackType type) => _trackClip.addTrack(type);
  Future<void> removeTrack(int trackIndex) => _trackClip.removeTrack(trackIndex);
  void toggleTrackVisibility(int trackIndex) => _trackClip.toggleTrackVisibility(trackIndex);
  void toggleTrackLock(int trackIndex) => _trackClip.toggleTrackLock(trackIndex);
  void toggleTrackMute(int trackIndex) => _trackClip.toggleTrackMute(trackIndex);
  void toggleTrackSolo(int trackIndex) => _trackClip.toggleTrackSolo(trackIndex);

  Future<int?> addClip({
    required int trackIndex,
    required ClipSourceType sourceType,
    required String sourcePath,
    required String displayName,
    required double duration,
    double? atTime,
  }) => _trackClip.addClip(
    trackIndex: trackIndex, sourceType: sourceType, sourcePath: sourcePath,
    displayName: displayName, duration: duration, atTime: atTime,
  );

  Future<void> removeClip(int clipId, {bool ripple = true}) => _trackClip.removeClip(clipId, ripple: ripple);
  Future<void> moveClip(int clipId, int newTrackIndex, double newInTime) => _trackClip.moveClip(clipId, newTrackIndex, newInTime);
  void commitMove(int clipId, VideoProject beforeDrag) => _trackClip.commitMove(clipId, beforeDrag);
  Future<void> trimClip(int clipId, double newIn, double newOut) => _trackClip.trimClip(clipId, newIn, newOut);
  void commitTrim(int clipId, VideoProject beforeTrim) => _trackClip.commitTrim(clipId, beforeTrim);
  Future<int?> splitClipAtPlayhead(int clipId) => _trackClip.splitClipAtPlayhead(clipId);
  Future<void> rippleDelete(int trackIndex, double rangeStart, double rangeEnd) => _trackClip.rippleDelete(trackIndex, rangeStart, rangeEnd);
  Future<void> closeTrackGaps(int trackIndex) => _trackClip.closeTrackGaps(trackIndex);
  void selectClip(int? clipId) => _trackClip.selectClip(clipId);
  VideoClip? get clipUnderPlayhead => _trackClip.clipUnderPlayhead;
  int? ensureClipSelected() => _trackClip.ensureClipSelected();

  // =========================================================================
  // Delegated: Effects / Color / Transitions
  // =========================================================================

  void addEffect(int clipId, VideoEffect effect) => _effectColor.addEffect(clipId, effect);
  void removeEffect(int clipId, EffectType type) => _effectColor.removeEffect(clipId, type);
  void toggleEffect(int clipId, EffectType type) => _effectColor.toggleEffect(clipId, type);
  void updateEffectValue(int clipId, EffectType type, double value) => _effectColor.updateEffectValue(clipId, type, value);
  void clearEffects(int clipId) => _effectColor.clearEffects(clipId);
  void setColorGrading(int clipId, ColorGrading grading) => _effectColor.setColorGrading(clipId, grading);
  void commitColorGrading(int clipId, VideoProject beforeGrading) => _effectColor.commitColorGrading(clipId, beforeGrading);
  void setPresetFilter(int clipId, PresetFilterId preset) => _effectColor.setPresetFilter(clipId, preset);
  void resetColorGrading(int clipId) => _effectColor.resetColorGrading(clipId);
  void setTransitionIn(int clipId, ClipTransition transition) => _effectColor.setTransitionIn(clipId, transition);
  void setTransitionOut(int clipId, ClipTransition transition) => _effectColor.setTransitionOut(clipId, transition);
  void removeTransitionIn(int clipId) => _effectColor.removeTransitionIn(clipId);
  void removeTransitionOut(int clipId) => _effectColor.removeTransitionOut(clipId);
  void setClipOpacity(int clipId, double opacity) => _effectColor.setClipOpacity(clipId, opacity);
  void commitClipOpacity(int clipId, VideoProject beforeOpacity) => _effectColor.commitClipOpacity(clipId, beforeOpacity);
  void setClipBlendMode(int clipId, int blendMode) => _effectColor.setClipBlendMode(clipId, blendMode);

  // Adjustment layer clips
  int? createAdjustmentClip({required AdjustmentClipData data, required double atTime, double duration = 5.0}) =>
      _effectColor.createAdjustmentClip(data: data, atTime: atTime, duration: duration);
  void updateAdjustmentClipData(int clipId, AdjustmentClipData data) => _effectColor.updateAdjustmentClipData(clipId, data);
  List<AdjustmentClipData> adjustmentLayersAtTime(double time) => _effectColor.adjustmentLayersAtTime(time);
  ColorGrading compositeAdjustmentGrading(double time) => _effectColor.compositeAdjustmentGrading(time);

  // =========================================================================
  // Delegated: Keyframes / Audio
  // =========================================================================

  void addKeyframe(int clipId, KeyframeProperty property, Keyframe kf) => _keyframeAudio.addKeyframe(clipId, property, kf);
  void removeKeyframe(int clipId, KeyframeProperty property, double time) => _keyframeAudio.removeKeyframe(clipId, property, time);
  void moveKeyframe(int clipId, KeyframeProperty property, double oldTime, double newTime, double newValue) => _keyframeAudio.moveKeyframe(clipId, property, oldTime, newTime, newValue);
  void commitKeyframeMove(int clipId, VideoProject beforeMove) => _keyframeAudio.commitKeyframeMove(clipId, beforeMove);
  void clearKeyframes(int clipId, KeyframeProperty property) => _keyframeAudio.clearKeyframes(clipId, property);
  Future<void> setClipVolume(int clipId, double volume) => _keyframeAudio.setClipVolume(clipId, volume);
  Future<double> getClipVolume(int clipId) => _keyframeAudio.getClipVolume(clipId);
  void setClipAudioSettings(int clipId, ClipAudioSettings settings) => _keyframeAudio.setClipAudioSettings(clipId, settings);
  void commitAudioSettings(int clipId, VideoProject beforeAudio) => _keyframeAudio.commitAudioSettings(clipId, beforeAudio);
  void setClipFadeIn(int clipId, double seconds) => _keyframeAudio.setClipFadeIn(clipId, seconds);
  void setClipFadeOut(int clipId, double seconds) => _keyframeAudio.setClipFadeOut(clipId, seconds);
  void setTrackVolume(int trackIndex, double volume) => _keyframeAudio.setTrackVolume(trackIndex, volume);
  void setTrackPan(int trackIndex, double pan) => _keyframeAudio.setTrackPan(trackIndex, pan);
  Future<MediaInfo?> probeMedia(String filePath) => _keyframeAudio.probeMedia(filePath);

  // =========================================================================
  // Delegated: Advanced editing
  // =========================================================================

  Future<int?> insertEdit({required int trackIndex, required ClipSourceType sourceType, required String sourcePath, required String displayName, required double duration, required double atTime}) => _advancedEdit.insertEdit(trackIndex: trackIndex, sourceType: sourceType, sourcePath: sourcePath, displayName: displayName, duration: duration, atTime: atTime);
  Future<int?> overwriteEdit({required int trackIndex, required ClipSourceType sourceType, required String sourcePath, required String displayName, required double duration, required double atTime}) => _advancedEdit.overwriteEdit(trackIndex: trackIndex, sourceType: sourceType, sourcePath: sourcePath, displayName: displayName, duration: duration, atTime: atTime);
  Future<void> rollEdit(int clipId, double deltaSec) => _advancedEdit.rollEdit(clipId, deltaSec);
  Future<void> slipEdit(int clipId, double deltaSec) => _advancedEdit.slipEdit(clipId, deltaSec);
  Future<void> slideEdit(int clipId, double deltaSec) => _advancedEdit.slideEdit(clipId, deltaSec);
  Future<void> rateStretch(int clipId, double newDurationSec) => _advancedEdit.rateStretch(clipId, newDurationSec, setClipSpeed);
  Future<int?> duplicateClip(int clipId) => _advancedEdit.duplicateClip(clipId);
  Future<List<double>> getSnapPoints(double timeSec, {double threshold = 0.1}) => _advancedEdit.getSnapPoints(timeSec, threshold: threshold);
  Future<void> reorderTracks(List<int> newOrder) => _advancedEdit.reorderTracks(newOrder);
  Future<void> setClipSpeed(int clipId, double newSpeed) => _advancedEdit.setClipSpeed(clipId, newSpeed);
  Future<void> reverseClip(int clipId) => _advancedEdit.reverseClip(clipId);
  Future<void> freezeFrame(int clipId) => _advancedEdit.freezeFrame(clipId);
  Future<void> applySpeedRamp(int clipId, List<({double position, double speed})> rampPoints) => _advancedEdit.applySpeedRamp(clipId, rampPoints);
  Future<void> clearSpeedRamp(int clipId) => _advancedEdit.clearSpeedRamp(clipId);
  void addMarker({MarkerType type = MarkerType.chapter, String label = ''}) => _advancedEdit.addMarker(type: type, label: label);
  void removeMarker(int markerId) => _advancedEdit.removeMarker(markerId);
  void updateMarker(int markerId, {String? label, MarkerType? type}) => _advancedEdit.updateMarker(markerId, label: label, type: type);
  void navigateToMarker(int markerId) => _advancedEdit.navigateToMarker(markerId, seek);
  void navigateToNextMarker() => _advancedEdit.navigateToNextMarker(seek);
  void navigateToPreviousMarker() => _advancedEdit.navigateToPreviousMarker(seek);
  void setProjectDimensions(int width, int height) => _advancedEdit.setProjectDimensions(width, height);
  Future<List<EngineEffectDef>> listAvailableEffects({String? category}) => _advancedEdit.listAvailableEffects(category: category);
  Future<int?> addClipEngineEffect(int clipId, String effectDefId) => _advancedEdit.addClipEngineEffect(clipId, effectDefId);
  Future<void> removeClipEngineEffect(int clipId, int instanceId) => _advancedEdit.removeClipEngineEffect(clipId, instanceId);
  Future<void> setEngineEffectParam(int clipId, int instanceId, String paramId, double value) => _advancedEdit.setEngineEffectParam(clipId, instanceId, paramId, value);
  Future<void> setEngineEffectEnabled(int clipId, int instanceId, bool enabled) => _advancedEdit.setEngineEffectEnabled(clipId, instanceId, enabled);
  Future<void> setEngineEffectMix(int clipId, int instanceId, double mix) => _advancedEdit.setEngineEffectMix(clipId, instanceId, mix);
  Future<int?> addClipMask(int clipId, MaskData mask) => _advancedEdit.addClipMask(clipId, mask);
  Future<void> updateClipMask(int clipId, int maskId, MaskData mask) => _advancedEdit.updateClipMask(clipId, maskId, mask);
  Future<void> removeClipMask(int clipId, int maskId) => _advancedEdit.removeClipMask(clipId, maskId);
  Future<int?> startTracking(int clipId, double x, double y) => _advancedEdit.startTracking(clipId, x, y);
  Future<List<TrackPoint>> getTrackingData(int trackerId) => _advancedEdit.getTrackingData(trackerId);
  Future<void> stabilizeClip(int clipId, {StabilizationConfig config = const StabilizationConfig()}) => _advancedEdit.stabilizeClip(clipId, config: config);
  Future<void> setClipText(int clipId, TextLayerData textData) => _advancedEdit.setClipText(clipId, textData);
  Future<int?> addClipShape(int clipId, ShapeData shape) => _advancedEdit.addClipShape(clipId, shape);
  Future<void> updateClipShape(int clipId, int shapeId, ShapeData shape) => _advancedEdit.updateClipShape(clipId, shapeId, shape);
  Future<void> removeClipShape(int clipId, int shapeId) => _advancedEdit.removeClipShape(clipId, shapeId);
  Future<int?> addAudioEffect(int clipId, String effectDefId) => _advancedEdit.addAudioEffect(clipId, effectDefId);
  Future<void> setAudioEffectParam(int clipId, int instanceId, String paramId, double value) => _advancedEdit.setAudioEffectParam(clipId, instanceId, paramId, value);
  Future<void> removeAudioEffect(int clipId, int instanceId) => _advancedEdit.removeAudioEffect(clipId, instanceId);
  Future<List<AudioEffectDef>> listAudioEffects() => _advancedEdit.listAudioEffects();
  Future<void> startAiSegmentation(int clipId, {AiSegmentationConfig config = const AiSegmentationConfig()}) => _advancedEdit.startAiSegmentation(clipId, config: config);
  Future<double> getAiSegmentationProgress() => _advancedEdit.getAiSegmentationProgress();
  Future<void> cancelAiSegmentation() => _advancedEdit.cancelAiSegmentation();
  Future<void> toggleProxyMode() => _advancedEdit.toggleProxyMode();
  Future<void> generateProxyForClip(int clipId) => _advancedEdit.generateProxyForClip(clipId);
  Future<void> generateAllProxies() => _advancedEdit.generateAllProxies();
  Future<void> verifyProxies() => _advancedEdit.verifyProxies();
  Future<int?> createMultiCamClip(int trackIndex, MultiCamConfig config) => _advancedEdit.createMultiCamClip(trackIndex, config);
  Future<void> switchMultiCamAngle(int clipId, int angleIndex) => _advancedEdit.switchMultiCamAngle(clipId, angleIndex);
  Future<void> flattenMultiCam(int clipId) => _advancedEdit.flattenMultiCam(clipId);

  // =========================================================================
  // Dispose
  // =========================================================================

  @override
  void dispose() {
    _playback.dispose();
    state.playback.previewFrame?.dispose();
    final project = state.project;
    if (project != null) {
      _engine.destroyTimeline(project.timelineId);
    }
    super.dispose();
  }
}
