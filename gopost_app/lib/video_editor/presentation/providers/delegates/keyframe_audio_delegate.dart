import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/delegates/timeline_operations.dart';

/// SRP: Handles keyframe management and audio controls.
class KeyframeAudioDelegate {
  KeyframeAudioDelegate(this._ops);

  final TimelineOperations _ops;

  // -------------------------------------------------------------------------
  // Keyframes
  // -------------------------------------------------------------------------

  void addKeyframe(int clipId, KeyframeProperty property, Keyframe kf) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) {
      final track = c.keyframes.trackFor(property) ??
          KeyframeTrack(property: property);
      return c.copyWith(keyframes: c.keyframes.updateTrack(track.addKeyframe(kf)));
    });
    _ops.pushUndo('Add keyframe', before);
    _ops.engine.setClipKeyframe(
      project.timelineId, clipId,
      property.index, kf.time, kf.value, kf.interpolation.index,
    );
    _ops.renderCurrentFrame();
  }

  void removeKeyframe(int clipId, KeyframeProperty property, double time) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) {
      final track = c.keyframes.trackFor(property);
      if (track == null) return c;
      return c.copyWith(keyframes: c.keyframes.updateTrack(track.removeKeyframeAt(time)));
    });
    _ops.pushUndo('Remove keyframe', before);
    _ops.engine.removeClipKeyframe(project.timelineId, clipId, property.index, time).catchError((_) {});
    _ops.renderCurrentFrame();
  }

  void moveKeyframe(int clipId, KeyframeProperty property, double oldTime, double newTime, double newValue) {
    final project = _ops.currentState.project;
    if (project == null) return;
    _ops.updateClip(clipId, (c) {
      final track = c.keyframes.trackFor(property);
      if (track == null) return c;
      return c.copyWith(keyframes: c.keyframes.updateTrack(track.moveKeyframe(oldTime, newTime, newValue)));
    });
    _ops.engine.removeClipKeyframe(project.timelineId, clipId, property.index, oldTime).catchError((_) {});
    _ops.engine.setClipKeyframe(project.timelineId, clipId, property.index, newTime, newValue, 0).catchError((_) {});
    _ops.debouncedRenderFrame();
  }

  void commitKeyframeMove(int clipId, VideoProject beforeMove) {
    _ops.pushUndo('Move keyframe', beforeMove);
  }

  void clearKeyframes(int clipId, KeyframeProperty property) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(keyframes: c.keyframes.removeTrack(property)));
    _ops.pushUndo('Clear keyframes', before);
    _ops.engine.clearClipKeyframes(project.timelineId, clipId, property.index).catchError((_) {});
    _ops.renderCurrentFrame();
  }

  // -------------------------------------------------------------------------
  // Audio controls
  // -------------------------------------------------------------------------

  Future<void> setClipVolume(int clipId, double volume) async {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    try {
      await _ops.engine.setClipVolume(project.timelineId, clipId, volume);
    } catch (_) {}
    _ops.updateClip(clipId, (c) => c.copyWith(
      audio: c.audio.copyWith(volume: volume),
    ));
    _ops.pushUndo('Set volume', before);
  }

  Future<double> getClipVolume(int clipId) async {
    final project = _ops.currentState.project;
    if (project == null) return 1.0;
    try {
      return await _ops.engine.getClipVolume(project.timelineId, clipId);
    } catch (_) {
      return project.findClip(clipId)?.audio.volume ?? 1.0;
    }
  }

  void setClipAudioSettings(int clipId, ClipAudioSettings settings) {
    _ops.updateClip(clipId, (c) => c.copyWith(audio: settings));
  }

  void commitAudioSettings(int clipId, VideoProject beforeAudio) {
    _ops.pushUndo('Audio settings', beforeAudio);
    _syncAudioSettingsToEngine(clipId);
  }

  void _syncAudioSettingsToEngine(int clipId) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final clip = project.allClips.where((c) => c.id == clipId).firstOrNull;
    if (clip == null) return;
    final a = clip.audio;
    _ops.engine.setClipVolume(project.timelineId, clipId, a.volume).catchError((_) {});
    _ops.engine.setClipPan(project.timelineId, clipId, a.pan).catchError((_) {});
    _ops.engine.setClipFadeIn(project.timelineId, clipId, a.fadeInSeconds).catchError((_) {});
    _ops.engine.setClipFadeOut(project.timelineId, clipId, a.fadeOutSeconds).catchError((_) {});
  }

  void setClipFadeIn(int clipId, double seconds) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(
      audio: c.audio.copyWith(fadeInSeconds: seconds),
    ));
    _ops.pushUndo('Set fade in', before);
  }

  void setClipFadeOut(int clipId, double seconds) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    _ops.updateClip(clipId, (c) => c.copyWith(
      audio: c.audio.copyWith(fadeOutSeconds: seconds),
    ));
    _ops.pushUndo('Set fade out', before);
  }

  void setTrackVolume(int trackIndex, double volume) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    final tracks = project.tracks.map((t) {
      if (t.index == trackIndex) {
        return t.copyWith(audioSettings: t.audioSettings.copyWith(volume: volume));
      }
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(project: project.copyWith(tracks: tracks));
    _ops.pushUndo('Set track volume', before);
    _ops.engine.setTrackVolume(project.timelineId, trackIndex, volume).catchError((_) {});
  }

  void setTrackPan(int trackIndex, double pan) {
    final project = _ops.currentState.project;
    if (project == null) return;
    final before = project;
    final tracks = project.tracks.map((t) {
      if (t.index == trackIndex) {
        return t.copyWith(audioSettings: t.audioSettings.copyWith(pan: pan));
      }
      return t;
    }).toList();
    _ops.currentState = _ops.currentState.copyWith(project: project.copyWith(tracks: tracks));
    _ops.pushUndo('Set track pan', before);
    _ops.engine.setTrackPan(project.timelineId, trackIndex, pan).catchError((_) {});
  }

  Future<MediaInfo?> probeMedia(String filePath) async {
    try {
      return await _ops.engine.probeMedia(filePath);
    } catch (_) {
      return null;
    }
  }

  /// Fast, non-blocking probe for instant import. Returns within ~100ms.
  Future<MediaInfo?> probeMediaFast(String filePath) async {
    try {
      return await _ops.engine.probeMediaFast(filePath);
    } catch (_) {
      return null;
    }
  }
}
