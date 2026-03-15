import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/ffi/native_bindings.dart';

/// FFI-backed [VideoTimelineEngine] using the native gopost video engine.
/// Requires the same [enginePtr] and [lib] as the image editor (shared engine).
class GopostVideoTimelineEngineFfi implements VideoTimelineEngine {
  GopostVideoTimelineEngineFfi(this._lib, this._enginePtr);

  final DynamicLibrary _lib;
  final Pointer<Void> _enginePtr;
  NativeBindings? _bindings;
  int _nextTimelineId = 1;
  final Map<int, Pointer<Void>> _timelines = {};

  NativeBindings get _b {
    _bindings ??= NativeBindings(_lib);
    return _bindings!;
  }

  void _checkErr(int err) {
    if (err != 0) {
      final msg = _b.gopost_error_string(err);
      throw Exception(msg.toDartString());
    }
  }

  int _toTrackType(VideoTrackType t) {
    return switch (t) {
      VideoTrackType.audio => 1,
      VideoTrackType.title => 2,
      VideoTrackType.effect => 3,
      VideoTrackType.subtitle => 4,
      VideoTrackType.video => 0,
    };
  }

  int _toClipSourceType(VideoClipSourceType t) {
    return switch (t) {
      VideoClipSourceType.image => 1,
      VideoClipSourceType.title => 2,
      VideoClipSourceType.color => 3,
      VideoClipSourceType.video => 0,
    };
  }

  @override
  Future<int> createTimeline(TimelineConfig config) async {
    final configPtr = calloc<NativeGopostTimelineConfig>();
    try {
      configPtr.ref.frameRate = config.frameRate;
      configPtr.ref.width = config.width;
      configPtr.ref.height = config.height;
      configPtr.ref.colorSpace = config.colorSpace;
      final outTimeline = calloc<Pointer<Void>>();
      try {
        _checkErr(_b.gopost_timeline_create(_enginePtr, configPtr, outTimeline));
        final ptr = outTimeline.value;
        if (ptr == nullptr) throw StateError('timeline_create returned null');
        final id = _nextTimelineId++;
        _timelines[id] = ptr;
        return id;
      } finally {
        calloc.free(outTimeline);
      }
    } finally {
      calloc.free(configPtr);
    }
  }

  @override
  Future<void> destroyTimeline(int timelineId) async {
    final ptr = _timelines.remove(timelineId);
    if (ptr == null) return;
    _b.gopost_timeline_destroy(ptr);
  }

  @override
  Future<TimelineConfig> getTimelineConfig(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final configPtr = calloc<NativeGopostTimelineConfig>();
    try {
      _checkErr(_b.gopost_timeline_get_config(ptr, configPtr));
      return TimelineConfig(
        frameRate: configPtr.ref.frameRate,
        width: configPtr.ref.width,
        height: configPtr.ref.height,
        colorSpace: configPtr.ref.colorSpace,
      );
    } finally {
      calloc.free(configPtr);
    }
  }

  @override
  Future<double> getDuration(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final out = calloc<Double>();
    try {
      _checkErr(_b.gopost_timeline_get_duration(ptr, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  @override
  Future<int> addTrack(int timelineId, VideoTrackType type) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outIndex = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_add_track(ptr, _toTrackType(type), outIndex));
      return outIndex.value;
    } finally {
      calloc.free(outIndex);
    }
  }

  @override
  Future<void> removeTrack(int timelineId, int trackIndex) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_track(ptr, trackIndex));
  }

  @override
  Future<int> getTrackCount(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final out = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_get_track_count(ptr, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  @override
  Future<int> addClip(int timelineId, ClipDescriptor descriptor) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final descPtr = calloc<NativeGopostClipDescriptor>();
    try {
      descPtr.ref.trackIndex = descriptor.trackIndex;
      descPtr.ref.sourceType = _toClipSourceType(descriptor.sourceType);
      final pathLen = descriptor.sourcePath.length > 1023 ? 1023 : descriptor.sourcePath.length;
      for (var i = 0; i < pathLen; i++) {
        descPtr.ref.sourcePath[i] = descriptor.sourcePath.codeUnitAt(i);
      }
      descPtr.ref.sourcePath[pathLen] = 0;
      descPtr.ref.timelineInTime = descriptor.timelineRange.inTime;
      descPtr.ref.timelineOutTime = descriptor.timelineRange.outTime;
      descPtr.ref.sourceIn = descriptor.sourceRange.sourceIn;
      descPtr.ref.sourceOut = descriptor.sourceRange.sourceOut;
      descPtr.ref.speed = descriptor.speed;
      descPtr.ref.opacity = descriptor.opacity;
      descPtr.ref.blendMode = descriptor.blendMode;
      descPtr.ref.effectHash = descriptor.effectHash;
      final outClipId = calloc<Int32>();
      try {
        _checkErr(_b.gopost_timeline_add_clip(ptr, descPtr, outClipId));
        return outClipId.value;
      } finally {
        calloc.free(outClipId);
      }
    } finally {
      calloc.free(descPtr);
    }
  }

  @override
  Future<void> removeClip(int timelineId, int clipId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_clip(ptr, clipId));
  }

  @override
  Future<void> trimClip(int timelineId, int clipId, TimelineRange newRange, SourceRange newSource) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final rangePtr = calloc<NativeGopostTimelineRange>();
    final sourcePtr = calloc<NativeGopostSourceRange>();
    try {
      rangePtr.ref.inTime = newRange.inTime;
      rangePtr.ref.outTime = newRange.outTime;
      sourcePtr.ref.sourceIn = newSource.sourceIn;
      sourcePtr.ref.sourceOut = newSource.sourceOut;
      _checkErr(_b.gopost_timeline_trim_clip(ptr, clipId, rangePtr, sourcePtr));
    } finally {
      calloc.free(rangePtr);
      calloc.free(sourcePtr);
    }
  }

  @override
  Future<void> moveClip(int timelineId, int clipId, int newTrackIndex, double newInTime) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_move_clip(ptr, clipId, newTrackIndex, newInTime));
  }

  @override
  Future<int?> splitClip(int timelineId, int clipId, double splitTimeSeconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outId = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_split_clip(ptr, clipId, splitTimeSeconds, outId));
      return outId.value;
    } finally {
      calloc.free(outId);
    }
  }

  @override
  Future<void> rippleDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_ripple_delete(ptr, trackIndex, rangeStartSeconds, rangeEndSeconds));
  }

  @override
  Future<void> seek(int timelineId, double positionSeconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_seek(ptr, positionSeconds));
  }

  @override
  Future<DecodedImage?> renderFrame(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outFrame = calloc<Pointer<Void>>();
    try {
      final err = _b.gopost_timeline_render_frame(ptr, outFrame);
      if (err != 0) return null;
      final framePtr = outFrame.value;
      if (framePtr == nullptr) return null;
      try {
        final frame = framePtr.cast<NativeGopostFrame>();
        final w = frame.ref.width;
        final h = frame.ref.height;
        final data = frame.ref.data;
        if (w <= 0 || h <= 0 || data == nullptr) return null;
        final size = w * h * 4;
        final pixels = Uint8List(size);
        pixels.setRange(0, size, data.asTypedList(size));
        return DecodedImage(width: w, height: h, pixels: pixels);
      } finally {
        _b.gopost_frame_release(_enginePtr, framePtr);
      }
    } finally {
      calloc.free(outFrame);
    }
  }

  @override
  Future<double> getPosition(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final out = calloc<Double>();
    try {
      _checkErr(_b.gopost_timeline_get_position(ptr, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  @override
  Future<void> setFrameCacheSizeBytes(int timelineId, int maxBytes) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_frame_cache_size_bytes(ptr, maxBytes));
  }

  @override
  Future<void> invalidateFrameCache(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_invalidate_frame_cache(ptr));
  }

  @override
  Future<MediaInfo?> probeMedia(String filePath) async {
    final pathPtr = filePath.toNativeUtf8();
    final infoPtr = calloc<NativeGopostMediaInfo>();
    try {
      final err = _b.gopost_media_probe(pathPtr.cast(), infoPtr);
      if (err != 0) return null;
      return MediaInfo(
        durationSeconds: infoPtr.ref.durationSeconds,
        width: infoPtr.ref.width,
        height: infoPtr.ref.height,
        frameRate: infoPtr.ref.frameRate,
        frameCount: infoPtr.ref.frameCount,
        hasAudio: infoPtr.ref.hasAudio != 0,
        audioSampleRate: infoPtr.ref.audioSampleRate,
        audioChannels: infoPtr.ref.audioChannels,
        audioDurationSeconds: infoPtr.ref.audioDurationSeconds,
      );
    } finally {
      calloc.free(pathPtr);
      calloc.free(infoPtr);
    }
  }

  @override
  Future<void> setClipVolume(int timelineId, int clipId, double volume) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_volume(ptr, clipId, volume));
  }

  @override
  Future<double> getClipVolume(int timelineId, int clipId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final out = calloc<Float>();
    try {
      _checkErr(_b.gopost_timeline_get_clip_volume(ptr, clipId, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  // --- Transitions (S10) ---

  @override
  Future<void> setClipTransitionIn(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_transition_in(
        ptr, clipId, transitionType, durationSeconds, easingCurve));
  }

  @override
  Future<void> setClipTransitionOut(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_transition_out(
        ptr, clipId, transitionType, durationSeconds, easingCurve));
  }

  // --- Keyframes (S10) ---

  @override
  Future<void> setClipKeyframe(int timelineId, int clipId,
      int property, double time, double value, int interpolation) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_keyframe(
        ptr, clipId, property, time, value, interpolation));
  }

  @override
  Future<void> removeClipKeyframe(int timelineId, int clipId,
      int property, double time) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_clip_keyframe(
        ptr, clipId, property, time));
  }

  @override
  Future<void> clearClipKeyframes(int timelineId, int clipId, int property) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_clear_clip_keyframes(ptr, clipId, property));
  }

  // --- Effects (S10) ---

  @override
  Future<void> setClipColorGrading(int timelineId, int clipId, {
    double brightness = 0, double contrast = 0, double saturation = 0,
    double exposure = 0, double temperature = 0, double tint = 0,
    double highlights = 0, double shadows = 0, double vibrance = 0,
    double hue = 0,
  }) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_color_grading(
      ptr, clipId,
      brightness, contrast, saturation, exposure,
      temperature, tint, highlights, shadows, vibrance, hue,
    ));
  }

  @override
  Future<void> clearClipEffects(int timelineId, int clipId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_clear_clip_effects(ptr, clipId));
  }

  // --- Audio enhancements (S10) ---

  @override
  Future<void> setClipPan(int timelineId, int clipId, double pan) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_pan(ptr, clipId, pan));
  }

  @override
  Future<void> setClipFadeIn(int timelineId, int clipId, double seconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_fade_in(ptr, clipId, seconds));
  }

  @override
  Future<void> setClipFadeOut(int timelineId, int clipId, double seconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_fade_out(ptr, clipId, seconds));
  }

  @override
  Future<void> setTrackVolume(int timelineId, int trackIndex, double volume) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_track_volume(ptr, trackIndex, volume));
  }

  @override
  Future<void> setTrackPan(int timelineId, int trackIndex, double pan) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_track_pan(ptr, trackIndex, pan));
  }

  @override
  Future<void> setTrackMute(int timelineId, int trackIndex, bool mute) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_track_mute(ptr, trackIndex, mute ? 1 : 0));
  }

  @override
  Future<void> setTrackSolo(int timelineId, int trackIndex, bool solo) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_track_solo(ptr, trackIndex, solo ? 1 : 0));
  }

  // --- Export pipeline (S11) ---

  final Map<int, int> _exportJobs = {}; // jobId → native handle

  @override
  Future<int> startExport(int timelineId, VideoExportConfig config) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');

    final pathPtr = config.outputPath.toNativeUtf8();
    try {
      final jobId = _b.gopost_timeline_start_export(
        ptr,
        config.width, config.height,
        config.frameRate,
        config.videoCodec, config.videoBitrateBps,
        config.audioCodec, config.audioBitrateKbps,
        config.container,
        pathPtr,
      );
      if (jobId < 0) throw StateError('Failed to start export');
      _exportJobs[jobId] = jobId;
      return jobId;
    } finally {
      calloc.free(pathPtr);
    }
  }

  @override
  Future<double> getExportProgress(int exportJobId) async {
    return _b.gopost_export_get_progress(exportJobId);
  }

  @override
  Future<void> cancelExport(int exportJobId) async {
    _b.gopost_export_cancel(exportJobId);
    _exportJobs.remove(exportJobId);
  }

  @override
  bool get supportsHardwareEncoding => false;

  // =========================================================================
  // Phase 2–6: Stub implementations (native bindings TBD)
  // =========================================================================

  @override
  Future<int> insertEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async =>
      throw UnimplementedError('insertEdit');

  @override
  Future<int> overwriteEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async =>
      throw UnimplementedError('overwriteEdit');

  @override
  Future<void> rollEdit(int timelineId, int clipId, double deltaSec) async =>
      throw UnimplementedError('rollEdit');

  @override
  Future<void> slipEdit(int timelineId, int clipId, double deltaSec) async =>
      throw UnimplementedError('slipEdit');

  @override
  Future<void> slideEdit(int timelineId, int clipId, double deltaSec) async =>
      throw UnimplementedError('slideEdit');

  @override
  Future<void> rateStretch(int timelineId, int clipId, double newDurationSec) async =>
      throw UnimplementedError('rateStretch');

  @override
  Future<int> duplicateClip(int timelineId, int clipId) async =>
      throw UnimplementedError('duplicateClip');

  @override
  Future<List<double>> getSnapPoints(int timelineId, double timeSec, double thresholdSec) async =>
      throw UnimplementedError('getSnapPoints');

  @override
  Future<void> reorderTracks(int timelineId, List<int> newOrder) async =>
      throw UnimplementedError('reorderTracks');

  @override
  Future<List<EngineEffectDef>> listEffects({String? category}) async =>
      throw UnimplementedError('listEffects');

  @override
  Future<int> addClipEffect(int timelineId, int clipId, String effectDefId) async =>
      throw UnimplementedError('addClipEffect');

  @override
  Future<void> removeClipEffect(int timelineId, int clipId, int effectInstanceId) async =>
      throw UnimplementedError('removeClipEffect');

  @override
  Future<void> reorderClipEffects(int timelineId, int clipId, List<int> instanceIds) async =>
      throw UnimplementedError('reorderClipEffects');

  @override
  Future<void> setEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async =>
      throw UnimplementedError('setEffectParam');

  @override
  Future<void> setEffectEnabled(int timelineId, int clipId, int effectInstanceId, bool enabled) async =>
      throw UnimplementedError('setEffectEnabled');

  @override
  Future<void> setEffectMix(int timelineId, int clipId, int effectInstanceId, double mix) async =>
      throw UnimplementedError('setEffectMix');

  @override
  Future<int> addClipMask(int timelineId, int clipId, MaskData mask) async =>
      throw UnimplementedError('addClipMask');

  @override
  Future<void> updateClipMask(int timelineId, int clipId, int maskId, MaskData mask) async =>
      throw UnimplementedError('updateClipMask');

  @override
  Future<void> removeClipMask(int timelineId, int clipId, int maskId) async =>
      throw UnimplementedError('removeClipMask');

  @override
  Future<int> startTracking(int timelineId, int clipId, double x, double y, double timeSec) async =>
      throw UnimplementedError('startTracking');

  @override
  Future<List<TrackPoint>> getTrackingData(int timelineId, int trackerId) async =>
      throw UnimplementedError('getTrackingData');

  @override
  Future<void> stabilizeClip(int timelineId, int clipId, StabilizationConfig config) async =>
      throw UnimplementedError('stabilizeClip');

  @override
  Future<void> setClipText(int timelineId, int clipId, TextLayerData textData) async =>
      throw UnimplementedError('setClipText');

  @override
  Future<int> addClipShape(int timelineId, int clipId, ShapeData shape) async =>
      throw UnimplementedError('addClipShape');

  @override
  Future<void> updateClipShape(int timelineId, int clipId, int shapeId, ShapeData shape) async =>
      throw UnimplementedError('updateClipShape');

  @override
  Future<void> removeClipShape(int timelineId, int clipId, int shapeId) async =>
      throw UnimplementedError('removeClipShape');

  @override
  Future<int> addAudioEffect(int timelineId, int clipId, String audioEffectDefId) async =>
      throw UnimplementedError('addAudioEffect');

  @override
  Future<void> setAudioEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async =>
      throw UnimplementedError('setAudioEffectParam');

  @override
  Future<void> removeAudioEffect(int timelineId, int clipId, int effectInstanceId) async =>
      throw UnimplementedError('removeAudioEffect');

  @override
  Future<List<AudioEffectDef>> listAudioEffects() async =>
      throw UnimplementedError('listAudioEffects');

  @override
  Future<int> startAiSegmentation(int timelineId, int clipId, AiSegmentationConfig config) async =>
      throw UnimplementedError('startAiSegmentation');

  @override
  Future<double> getAiSegmentationProgress(int jobId) async =>
      throw UnimplementedError('getAiSegmentationProgress');

  @override
  Future<void> cancelAiSegmentation(int jobId) async =>
      throw UnimplementedError('cancelAiSegmentation');

  @override
  Future<void> enableProxyMode(int timelineId, ProxyConfig config) async =>
      throw UnimplementedError('enableProxyMode');

  @override
  Future<void> disableProxyMode(int timelineId) async =>
      throw UnimplementedError('disableProxyMode');

  @override
  Future<bool> isProxyModeActive(int timelineId) async =>
      throw UnimplementedError('isProxyModeActive');

  @override
  Future<int> createMultiCamClip(int timelineId, int trackIndex, MultiCamConfig config) async =>
      throw UnimplementedError('createMultiCamClip');

  @override
  Future<void> switchMultiCamAngle(int timelineId, int clipId, int angleIndex, double atTimeSec) async =>
      throw UnimplementedError('switchMultiCamAngle');

  @override
  Future<void> flattenMultiCam(int timelineId, int clipId) async =>
      throw UnimplementedError('flattenMultiCam');
}
