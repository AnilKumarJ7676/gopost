import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/timeline_operations.dart';

/// SRP: Handles NLE edit operations, markers, proxy editing, AI segmentation,
/// multi-cam, speed controls, and other advanced editing features.
class AdvancedEditDelegate {
  AdvancedEditDelegate(this._ops);

  final TimelineOperations _ops;
  int _nextMarkerId = 1;
  int? _aiSegJobId;

  // -------------------------------------------------------------------------
  // NLE Edit Operations
  // -------------------------------------------------------------------------

  Future<int?> insertEdit({
    required int trackIndex,
    required ClipSourceType sourceType,
    required String sourcePath,
    required String displayName,
    required double duration,
    required double atTime,
  }) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    final engineSrc = _ops.toEngineSourceType(sourceType);
    final resolvedPath = sourceType == ClipSourceType.video && _ops.currentState.useProxyPlayback
        ? (await _ops.proxyService.existingProxyPath(sourcePath) ?? sourcePath)
        : sourcePath;
    final descriptor = ClipDescriptor(
      trackIndex: trackIndex,
      sourceType: engineSrc,
      sourcePath: resolvedPath,
      timelineRange: TimelineRange(inTime: atTime, outTime: atTime + duration),
      sourceRange: SourceRange(sourceIn: 0, sourceOut: duration),
    );
    try {
      final clipId = await _ops.engine.insertEdit(project.timelineId, trackIndex, atTime, descriptor);
      final clip = VideoClip(
        id: clipId,
        trackIndex: trackIndex,
        sourceType: sourceType,
        sourcePath: sourcePath,
        displayName: displayName,
        timelineIn: atTime,
        timelineOut: atTime + duration,
        sourceIn: 0,
        sourceOut: duration,
      );
      final updatedTracks = project.tracks.map((t) {
        if (t.index != trackIndex) return t;
        final shifted = t.clips.map((c) {
          if (c.timelineIn >= atTime) {
            return c.copyWith(
              timelineIn: c.timelineIn + duration,
              timelineOut: c.timelineOut + duration,
            );
          }
          return c;
        }).toList()..add(clip);
        return t.copyWith(clips: shifted);
      }).toList();
      _ops.currentState = _ops.currentState.copyWith(project: project.copyWith(tracks: updatedTracks));
      _ops.pushUndo('Insert edit', before);
      await _ops.renderCurrentFrame();
      return clipId;
    } catch (_) { return null; }
  }

  Future<int?> overwriteEdit({
    required int trackIndex,
    required ClipSourceType sourceType,
    required String sourcePath,
    required String displayName,
    required double duration,
    required double atTime,
  }) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    final engineSrc = _ops.toEngineSourceType(sourceType);
    final resolvedPath = sourceType == ClipSourceType.video && _ops.currentState.useProxyPlayback
        ? (await _ops.proxyService.existingProxyPath(sourcePath) ?? sourcePath)
        : sourcePath;
    final descriptor = ClipDescriptor(
      trackIndex: trackIndex,
      sourceType: engineSrc,
      sourcePath: resolvedPath,
      timelineRange: TimelineRange(inTime: atTime, outTime: atTime + duration),
      sourceRange: SourceRange(sourceIn: 0, sourceOut: duration),
    );
    try {
      final clipId = await _ops.engine.overwriteEdit(project.timelineId, trackIndex, atTime, descriptor);
      final clip = VideoClip(
        id: clipId,
        trackIndex: trackIndex,
        sourceType: sourceType,
        sourcePath: sourcePath,
        displayName: displayName,
        timelineIn: atTime,
        timelineOut: atTime + duration,
        sourceIn: 0,
        sourceOut: duration,
      );
      final endTime = atTime + duration;
      final updatedTracks = project.tracks.map((t) {
        if (t.index != trackIndex) return t;
        final kept = t.clips.where((c) =>
          c.timelineOut <= atTime || c.timelineIn >= endTime).toList()..add(clip);
        return t.copyWith(clips: kept);
      }).toList();
      _ops.currentState = _ops.currentState.copyWith(project: project.copyWith(tracks: updatedTracks));
      _ops.pushUndo('Overwrite edit', before);
      await _ops.renderCurrentFrame();
      return clipId;
    } catch (_) { return null; }
  }

  Future<void> rollEdit(int clipId, double deltaSec) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    final clip = project.findClip(clipId);
    if (clip == null) return;
    try {
      await _ops.engine.rollEdit(project.timelineId, clipId, deltaSec);
      final newOut = clip.timelineOut + deltaSec;
      _ops.updateClip(clipId, (c) => c.copyWith(
        timelineOut: newOut,
        sourceOut: c.sourceOut + deltaSec,
      ));
      _ops.pushUndo('Roll edit', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> slipEdit(int clipId, double deltaSec) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.slipEdit(project.timelineId, clipId, deltaSec);
      _ops.updateClip(clipId, (c) => c.copyWith(
        sourceIn: c.sourceIn + deltaSec,
        sourceOut: c.sourceOut + deltaSec,
      ));
      _ops.pushUndo('Slip edit', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> slideEdit(int clipId, double deltaSec) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.slideEdit(project.timelineId, clipId, deltaSec);
      _ops.updateClip(clipId, (c) => c.copyWith(
        timelineIn: c.timelineIn + deltaSec,
        timelineOut: c.timelineOut + deltaSec,
      ));
      _ops.pushUndo('Slide edit', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> rateStretch(int clipId, double newDurationSec, Future<void> Function(int, double) setClipSpeed) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null) return;
    if (newDurationSec <= 0.01) return;
    final sourceDur = clip.sourceOut - clip.sourceIn;
    final newSpeed = sourceDur / newDurationSec;
    if (newSpeed < 0.1 || newSpeed > 8.0) return;
    await setClipSpeed(clipId, clip.speed < 0 ? -newSpeed : newSpeed);
  }

  Future<int?> duplicateClip(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    final clip = project.findClip(clipId);
    if (clip == null) return null;
    try {
      final newId = await _ops.engine.duplicateClip(project.timelineId, clipId);
      final dup = clip.copyWith(
        id: newId,
        timelineIn: clip.timelineOut,
        timelineOut: clip.timelineOut + clip.duration,
      );
      final updatedTracks = project.tracks.map((t) {
        if (t.index == clip.trackIndex) return t.copyWith(clips: [...t.clips, dup]);
        return t;
      }).toList();
      _ops.currentState = _ops.currentState.copyWith(project: project.copyWith(tracks: updatedTracks));
      _ops.pushUndo('Duplicate clip', before);
      await _ops.renderCurrentFrame();
      return newId;
    } catch (_) { return null; }
  }

  Future<List<double>> getSnapPoints(double timeSec, {double threshold = 0.1}) async {
    final project = _ops.currentState.project;
    if (project == null) return [];
    try {
      return await _ops.engine.getSnapPoints(project.timelineId, timeSec, threshold);
    } catch (_) {
      final points = <double>[];
      for (final track in project.tracks) {
        for (final clip in track.clips) {
          if ((clip.timelineIn - timeSec).abs() < threshold) points.add(clip.timelineIn);
          if ((clip.timelineOut - timeSec).abs() < threshold) points.add(clip.timelineOut);
        }
      }
      return points;
    }
  }

  Future<void> reorderTracks(List<int> newOrder) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.reorderTracks(project.timelineId, newOrder);
      final trackMap = {for (final t in project.tracks) t.index: t};
      final reordered = <VideoTrack>[];
      for (final idx in newOrder) {
        final t = trackMap[idx];
        if (t != null) reordered.add(t);
      }
      _ops.currentState = _ops.currentState.copyWith(project: project.copyWith(tracks: reordered));
      _ops.pushUndo('Reorder tracks', before);
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Speed controls
  // -------------------------------------------------------------------------

  Future<void> setClipSpeed(int clipId, double newSpeed) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final absSpeed = newSpeed.abs();
    if (absSpeed < 0.1 || absSpeed > 8.0) return;
    final before = project;

    final clip = project.findClip(clipId);
    if (clip == null) return;

    final sourceDuration = clip.sourceOut - clip.sourceIn;
    final newTimelineDuration = sourceDuration / absSpeed;
    final newOut = clip.timelineIn + newTimelineDuration;
    final tlId = project.timelineId;

    await _ops.engine.removeClip(tlId, clipId);

    final newId = await _ops.engine.addClip(tlId, ClipDescriptor(
      trackIndex: clip.trackIndex,
      sourceType: _ops.toEngineSourceType(clip.sourceType),
      sourcePath: _ops.resolvePlaybackPath(clip),
      timelineRange: TimelineRange(inTime: clip.timelineIn, outTime: newOut),
      sourceRange: SourceRange(sourceIn: clip.sourceIn, sourceOut: clip.sourceOut),
      speed: absSpeed,
      opacity: clip.opacity,
      blendMode: clip.blendMode,
      effectHash: clip.effectHash,
    ));

    final updatedClip = clip.copyWith(id: newId, timelineOut: newOut, speed: newSpeed);
    _ops.restoreClipS10State(tlId, updatedClip);

    final updatedTracks = project.tracks.map((t) {
      return t.copyWith(
        clips: t.clips.map((c) {
          if (c.id == clipId) return updatedClip;
          return c;
        }).toList(),
      );
    }).toList();

    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(tracks: updatedTracks),
      selectedClipId: newId,
    );
    _ops.pushUndo('Change speed to ${newSpeed}x', before);
    _ops.debouncedRenderFrame();
  }

  Future<void> reverseClip(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null) return;
    final newSpeed = clip.speed < 0 ? clip.speed.abs() : -clip.speed.abs();
    await setClipSpeed(clipId, newSpeed);
  }

  Future<void> freezeFrame(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null) return;

    final pos = _ops.currentState.playback.positionSeconds;
    if (pos <= clip.timelineIn || pos >= clip.timelineOut) return;

    const freezeDuration = 2.0;
    const freezeSpeed = 0.01;
    const freezeSourceLen = freezeDuration * freezeSpeed;
    final before = project;

    final clipLocal = pos - clip.timelineIn;
    final isReverse = clip.speed < 0;
    final absSpeed = clip.speed.abs();
    final sourcePos = isReverse
        ? clip.sourceOut - clipLocal * absSpeed
        : clip.sourceIn + clipLocal * absSpeed;
    final clampedSource = sourcePos.clamp(
      clip.sourceIn,
      (clip.sourceOut - freezeSourceLen).clamp(clip.sourceIn, clip.sourceOut),
    );
    final tlId = project.timelineId;
    final existingProxy = await _ops.proxyService.existingProxyPath(clip.sourcePath);

    try {
      await _ops.engine.removeClip(tlId, clipId);

      // Part 1: original clip start → playhead
      final p1SrcIn = isReverse ? clampedSource : clip.sourceIn;
      final p1SrcOut = isReverse ? clip.sourceOut : clampedSource;
      final part1Id = await _ops.engine.addClip(tlId, ClipDescriptor(
        trackIndex: clip.trackIndex,
        sourceType: _ops.toEngineSourceType(clip.sourceType),
        sourcePath: _ops.resolvePlaybackPath(clip),
        timelineRange: TimelineRange(inTime: clip.timelineIn, outTime: pos),
        sourceRange: SourceRange(sourceIn: p1SrcIn, sourceOut: p1SrcOut),
        speed: absSpeed,
        opacity: clip.opacity,
        blendMode: clip.blendMode,
        effectHash: clip.effectHash,
      ));

      // Freeze clip: hold the frame at the playhead
      final freezeId = await _ops.engine.addClip(tlId, ClipDescriptor(
        trackIndex: clip.trackIndex,
        sourceType: _ops.toEngineSourceType(clip.sourceType),
        sourcePath: _ops.resolvePlaybackPath(clip),
        timelineRange: TimelineRange(inTime: pos, outTime: pos + freezeDuration),
        sourceRange: SourceRange(
          sourceIn: clampedSource,
          sourceOut: clampedSource + freezeSourceLen,
        ),
        speed: freezeSpeed,
        opacity: clip.opacity,
        blendMode: clip.blendMode,
        effectHash: 0,
      ));

      // Part 2: after freeze → shifted original end
      final p2TimeIn = pos + freezeDuration;
      final p2TimeOut = clip.timelineOut + freezeDuration;
      final p2SrcIn = isReverse ? clip.sourceIn : clampedSource;
      final p2SrcOut = isReverse ? clampedSource : clip.sourceOut;
      final part2Id = await _ops.engine.addClip(tlId, ClipDescriptor(
        trackIndex: clip.trackIndex,
        sourceType: _ops.toEngineSourceType(clip.sourceType),
        sourcePath: _ops.resolvePlaybackPath(clip),
        timelineRange: TimelineRange(inTime: p2TimeIn, outTime: p2TimeOut),
        sourceRange: SourceRange(sourceIn: p2SrcIn, sourceOut: p2SrcOut),
        speed: absSpeed,
        opacity: clip.opacity,
        blendMode: clip.blendMode,
        effectHash: clip.effectHash,
      ));

      final part1Clip = clip.copyWith(
        id: part1Id,
        timelineOut: pos,
        sourceIn: p1SrcIn,
        sourceOut: p1SrcOut,
      );
      final freezeClip = VideoClip(
        id: freezeId,
        trackIndex: clip.trackIndex,
        sourceType: clip.sourceType,
        sourcePath: clip.sourcePath,
        proxyPath: existingProxy,
        proxyStatus: existingProxy != null ? ProxyStatus.ready : ProxyStatus.none,
        displayName: '${clip.displayName} (freeze)',
        timelineIn: pos,
        timelineOut: pos + freezeDuration,
        sourceIn: clampedSource,
        sourceOut: clampedSource + freezeSourceLen,
        speed: freezeSpeed,
        opacity: clip.opacity,
        blendMode: clip.blendMode,
      );
      final part2Clip = clip.copyWith(
        id: part2Id,
        timelineIn: p2TimeIn,
        timelineOut: p2TimeOut,
        sourceIn: p2SrcIn,
        sourceOut: p2SrcOut,
      );

      // Rebuild tracks: replace original clip with 3 pieces, shift later clips
      final updatedTracks = project.tracks.map((t) {
        final newClips = <VideoClip>[];
        for (final c in t.clips) {
          if (c.id == clipId) {
            newClips.addAll([part1Clip, freezeClip, part2Clip]);
          } else if (c.timelineIn >= clip.timelineOut) {
            final shifted = c.copyWith(
              timelineIn: c.timelineIn + freezeDuration,
              timelineOut: c.timelineOut + freezeDuration,
            );
            newClips.add(shifted);
            _ops.engine.moveClip(tlId, c.id, c.trackIndex, shifted.timelineIn)
                .catchError((_) {});
          } else {
            newClips.add(c);
          }
        }
        return t.copyWith(clips: newClips);
      }).toList();

      double maxOut = 0;
      for (final t in updatedTracks) {
        for (final c in t.clips) {
          if (c.timelineOut > maxOut) maxOut = c.timelineOut;
        }
      }

      _ops.currentState = _ops.currentState.copyWith(
        project: project.copyWith(tracks: updatedTracks),
        selectedClipId: freezeId,
        playback: _ops.currentState.playback.copyWith(
          durationSeconds: maxOut > _ops.currentState.playback.durationSeconds
              ? maxOut
              : null,
        ),
      );
      _ops.pushUndo('Freeze frame', before);
      _ops.updateActiveVideo();
      _ops.debouncedRenderFrame();
    } catch (_) {}
  }

  Future<void> applySpeedRamp(int clipId, List<({double position, double speed})> rampPoints) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null) return;
    final before = project;
    final clipDuration = clip.timelineOut - clip.timelineIn;
    final tlId = project.timelineId;

    // Clear any existing speed ramp keyframes in the engine first.
    _ops.engine.clearClipKeyframes(tlId, clipId, KeyframeProperty.speed.index).catchError((_) {});

    var kfs = clip.keyframes;
    var speedTrack = const KeyframeTrack(property: KeyframeProperty.speed);
    for (final pt in rampPoints) {
      final time = pt.position * clipDuration;
      speedTrack = speedTrack.addKeyframe(
        Keyframe(time: time, value: pt.speed, interpolation: KeyframeInterpolation.easeInOut),
      );
      _ops.engine.setClipKeyframe(
        tlId, clipId, KeyframeProperty.speed.index,
        time, pt.speed, KeyframeInterpolation.easeInOut.index,
      ).catchError((_) {});
    }

    kfs = kfs.updateTrack(speedTrack);
    _ops.updateClip(clipId, (c) => c.copyWith(keyframes: kfs));
    _ops.pushUndo('Speed ramp', before);
    _ops.debouncedRenderFrame();
  }

  Future<void> clearSpeedRamp(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null) return;
    final before = project;
    final tlId = project.timelineId;

    _ops.engine.clearClipKeyframes(tlId, clipId, KeyframeProperty.speed.index).catchError((_) {});

    final kfs = clip.keyframes.removeTrack(KeyframeProperty.speed);
    _ops.updateClip(clipId, (c) => c.copyWith(keyframes: kfs));
    _ops.pushUndo('Clear speed ramp', before);
    _ops.debouncedRenderFrame();
  }

  // -------------------------------------------------------------------------
  // Markers
  // -------------------------------------------------------------------------

  void addMarker({MarkerType type = MarkerType.chapter, String label = ''}) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    final marker = TimelineMarker(
      id: _nextMarkerId++,
      positionSeconds: _ops.currentState.playback.positionSeconds,
      type: type,
      label: label,
    );
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(markers: [...project.markers, marker]),
    );
    _ops.pushUndo('Add marker', before);
  }

  void removeMarker(int markerId) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(
        markers: project.markers.where((m) => m.id != markerId).toList(),
      ),
    );
    _ops.pushUndo('Remove marker', before);
  }

  void updateMarker(int markerId, {String? label, MarkerType? type}) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(
        markers: project.markers.map((m) {
          if (m.id != markerId) return m;
          return TimelineMarker(
            id: m.id,
            positionSeconds: m.positionSeconds,
            type: type ?? m.type,
            label: label ?? m.label,
          );
        }).toList(),
      ),
    );
    _ops.pushUndo('Update marker', before);
  }

  void navigateToMarker(int markerId, Future<void> Function(double) seek) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final marker = project.markers.where((m) => m.id == markerId).firstOrNull;
    if (marker != null) seek(marker.positionSeconds);
  }

  void navigateToNextMarker(Future<void> Function(double) seek) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final pos = _ops.currentState.playback.positionSeconds;
    final sorted = List<TimelineMarker>.from(project.markers)
      ..sort((a, b) => a.positionSeconds.compareTo(b.positionSeconds));
    for (final m in sorted) {
      if (m.positionSeconds > pos + 0.05) {
        seek(m.positionSeconds);
        return;
      }
    }
  }

  void navigateToPreviousMarker(Future<void> Function(double) seek) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final pos = _ops.currentState.playback.positionSeconds;
    final sorted = List<TimelineMarker>.from(project.markers)
      ..sort((a, b) => b.positionSeconds.compareTo(a.positionSeconds));
    for (final m in sorted) {
      if (m.positionSeconds < pos - 0.05) {
        seek(m.positionSeconds);
        return;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Project dimensions
  // -------------------------------------------------------------------------

  void setProjectDimensions(int width, int height) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.currentState = _ops.currentState.copyWith(
      project: project.copyWith(width: width, height: height),
    );
    _ops.pushUndo('Change aspect ratio', before);
  }

  // -------------------------------------------------------------------------
  // Engine effects, masks, tracking, text, shapes, audio effects
  // -------------------------------------------------------------------------

  Future<List<EngineEffectDef>> listAvailableEffects({String? category}) async {
    try { return await _ops.engine.listEffects(category: category); } catch (_) { return []; }
  }

  Future<int?> addClipEngineEffect(int clipId, String effectDefId) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    try {
      final instanceId = await _ops.engine.addClipEffect(project.timelineId, clipId, effectDefId);
      _ops.pushUndo('Add engine effect', before);
      await _ops.renderCurrentFrame();
      return instanceId;
    } catch (_) { return null; }
  }

  Future<void> removeClipEngineEffect(int clipId, int instanceId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.removeClipEffect(project.timelineId, clipId, instanceId);
      _ops.pushUndo('Remove engine effect', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> setEngineEffectParam(int clipId, int instanceId, String paramId, double value) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try {
      await _ops.engine.setEffectParam(project.timelineId, clipId, instanceId, paramId, value);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> setEngineEffectEnabled(int clipId, int instanceId, bool enabled) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try {
      await _ops.engine.setEffectEnabled(project.timelineId, clipId, instanceId, enabled);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> setEngineEffectMix(int clipId, int instanceId, double mix) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try {
      await _ops.engine.setEffectMix(project.timelineId, clipId, instanceId, mix);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<int?> addClipMask(int clipId, MaskData mask) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    try {
      final maskId = await _ops.engine.addClipMask(project.timelineId, clipId, mask);
      _ops.pushUndo('Add mask', before);
      await _ops.renderCurrentFrame();
      return maskId;
    } catch (_) { return null; }
  }

  Future<void> updateClipMask(int clipId, int maskId, MaskData mask) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try {
      await _ops.engine.updateClipMask(project.timelineId, clipId, maskId, mask);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> removeClipMask(int clipId, int maskId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.removeClipMask(project.timelineId, clipId, maskId);
      _ops.pushUndo('Remove mask', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<int?> startTracking(int clipId, double x, double y) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    try {
      return await _ops.engine.startTracking(
        project.timelineId, clipId, x, y, _ops.currentState.playback.positionSeconds);
    } catch (_) { return null; }
  }

  Future<List<TrackPoint>> getTrackingData(int trackerId) async {
    final project = _ops.currentState.project;
    if (project == null) return [];
    try { return await _ops.engine.getTrackingData(project.timelineId, trackerId); } catch (_) { return []; }
  }

  Future<void> stabilizeClip(int clipId, {StabilizationConfig config = const StabilizationConfig()}) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.stabilizeClip(project.timelineId, clipId, config);
      _ops.pushUndo('Stabilize clip', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> setClipText(int clipId, TextLayerData textData) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.setClipText(project.timelineId, clipId, textData);
      _ops.pushUndo('Set text', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<int?> addClipShape(int clipId, ShapeData shape) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    try {
      final shapeId = await _ops.engine.addClipShape(project.timelineId, clipId, shape);
      _ops.pushUndo('Add shape', before);
      await _ops.renderCurrentFrame();
      return shapeId;
    } catch (_) { return null; }
  }

  Future<void> updateClipShape(int clipId, int shapeId, ShapeData shape) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try {
      await _ops.engine.updateClipShape(project.timelineId, clipId, shapeId, shape);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> removeClipShape(int clipId, int shapeId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.removeClipShape(project.timelineId, clipId, shapeId);
      _ops.pushUndo('Remove shape', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<int?> addAudioEffect(int clipId, String effectDefId) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    try {
      final id = await _ops.engine.addAudioEffect(project.timelineId, clipId, effectDefId);
      _ops.pushUndo('Add audio effect', before);
      return id;
    } catch (_) { return null; }
  }

  Future<void> setAudioEffectParam(int clipId, int instanceId, String paramId, double value) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try { await _ops.engine.setAudioEffectParam(project.timelineId, clipId, instanceId, paramId, value); } catch (_) {}
  }

  Future<void> removeAudioEffect(int clipId, int instanceId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.removeAudioEffect(project.timelineId, clipId, instanceId);
      _ops.pushUndo('Remove audio effect', before);
    } catch (_) {}
  }

  Future<List<AudioEffectDef>> listAudioEffects() async {
    try { return await _ops.engine.listAudioEffects(); } catch (_) { return []; }
  }

  // -------------------------------------------------------------------------
  // AI, Proxy, Multi-Cam
  // -------------------------------------------------------------------------

  Future<void> startAiSegmentation(int clipId, {AiSegmentationConfig config = const AiSegmentationConfig()}) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try { _aiSegJobId = await _ops.engine.startAiSegmentation(project.timelineId, clipId, config); } catch (_) {}
  }

  Future<double> getAiSegmentationProgress() async {
    if (_aiSegJobId == null) return -1;
    try { return await _ops.engine.getAiSegmentationProgress(_aiSegJobId!); } catch (_) { return -1; }
  }

  Future<void> cancelAiSegmentation() async {
    if (_aiSegJobId == null) return;
    try { await _ops.engine.cancelAiSegmentation(_aiSegJobId!); _aiSegJobId = null; } catch (_) {}
  }

  Future<void> toggleProxyMode() async {
    final newValue = !_ops.currentState.useProxyPlayback;
    _ops.currentState = _ops.currentState.copyWith(useProxyPlayback: newValue);
    final project = _ops.currentState.project;
    if (project != null) {
      await _ops.syncNativeToProject(project);
    }
    _ops.updateActiveVideo();
    await _ops.renderCurrentFrame();
  }

  Future<void> generateProxyForClip(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.findClip(clipId);
    if (clip == null || clip.sourceType != ClipSourceType.video) return;
    if (clip.sourcePath.isEmpty) return;
    if (clip.proxyStatus == ProxyStatus.ready || clip.proxyStatus == ProxyStatus.generating) return;

    _ops.updateClip(clipId, (c) => c.copyWith(proxyStatus: ProxyStatus.generating));

    final proxyPath = await _ops.proxyService.generateProxy(clip.sourcePath);

    if (!_ops.isMounted) return;
    if (proxyPath != null) {
      _ops.updateClip(clipId, (c) => c.copyWith(
        proxyPath: proxyPath,
        proxyStatus: ProxyStatus.ready,
      ));
      if (_ops.currentState.useProxyPlayback) {
        _ops.updateActiveVideo();
        await _ops.renderCurrentFrame();
      }
    } else {
      _ops.updateClip(clipId, (c) => c.copyWith(proxyStatus: ProxyStatus.failed));
    }
  }

  Future<void> generateAllProxies() async {
    final project = _ops.currentState.project;
    if (project == null) return;
    for (final clip in project.allClips) {
      if (clip.sourceType == ClipSourceType.video &&
          clip.proxyStatus == ProxyStatus.none &&
          clip.sourcePath.isNotEmpty) {
        await generateProxyForClip(clip.id);
      }
    }
  }

  Future<void> verifyProxies() async {
    final project = _ops.currentState.project;
    if (project == null) return;
    for (final clip in project.allClips) {
      if (clip.proxyStatus == ProxyStatus.ready && clip.proxyPath != null) {
        final exists = await _ops.proxyService.verifyProxy(clip.proxyPath!);
        if (!exists && _ops.isMounted) {
          _ops.updateClip(clip.id, (c) => c.copyWith(
            clearProxyPath: true,
            proxyStatus: ProxyStatus.none,
          ));
        }
      }
    }
  }

  Future<int?> createMultiCamClip(int trackIndex, MultiCamConfig config) async {
    final project = _ops.currentState.project;
    if (project == null) return null;
    final before = project;
    try {
      final clipId = await _ops.engine.createMultiCamClip(project.timelineId, trackIndex, config);
      _ops.pushUndo('Create multi-cam', before);
      await _ops.renderCurrentFrame();
      return clipId;
    } catch (_) { return null; }
  }

  Future<void> switchMultiCamAngle(int clipId, int angleIndex) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    try {
      await _ops.engine.switchMultiCamAngle(
        project.timelineId, clipId, angleIndex, _ops.currentState.playback.positionSeconds);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }

  Future<void> flattenMultiCam(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.flattenMultiCam(project.timelineId, clipId);
      _ops.pushUndo('Flatten multi-cam', before);
      await _ops.renderCurrentFrame();
    } catch (_) {}
  }
}
