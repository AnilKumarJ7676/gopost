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
  Future<MediaInfo?> probeMediaFast(String filePath) => probeMedia(filePath);

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
  // Phase 2: NLE Edit Operations — fully wired to native C API
  // =========================================================================

  /// Marshal a [ClipDescriptor] into a native struct, call [fn], then free.
  Future<T> _withDescriptor<T>(ClipDescriptor clip, T Function(Pointer<NativeGopostClipDescriptor>) fn) async {
    final descPtr = calloc<NativeGopostClipDescriptor>();
    try {
      descPtr.ref.trackIndex = clip.trackIndex;
      descPtr.ref.sourceType = _toClipSourceType(clip.sourceType);
      final pathLen = clip.sourcePath.length > 1023 ? 1023 : clip.sourcePath.length;
      for (var i = 0; i < pathLen; i++) {
        descPtr.ref.sourcePath[i] = clip.sourcePath.codeUnitAt(i);
      }
      descPtr.ref.sourcePath[pathLen] = 0;
      descPtr.ref.timelineInTime = clip.timelineRange.inTime;
      descPtr.ref.timelineOutTime = clip.timelineRange.outTime;
      descPtr.ref.sourceIn = clip.sourceRange.sourceIn;
      descPtr.ref.sourceOut = clip.sourceRange.sourceOut;
      descPtr.ref.speed = clip.speed;
      descPtr.ref.opacity = clip.opacity;
      descPtr.ref.blendMode = clip.blendMode;
      descPtr.ref.effectHash = clip.effectHash;
      return fn(descPtr);
    } finally {
      calloc.free(descPtr);
    }
  }

  @override
  Future<int> insertEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    return _withDescriptor(clip, (descPtr) {
      final outId = calloc<Int32>();
      try {
        _checkErr(_b.gopost_timeline_insert_edit(ptr, trackIndex, atTime, descPtr, outId));
        return outId.value;
      } finally {
        calloc.free(outId);
      }
    });
  }

  @override
  Future<int> overwriteEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    return _withDescriptor(clip, (descPtr) {
      final outId = calloc<Int32>();
      try {
        _checkErr(_b.gopost_timeline_overwrite_edit(ptr, trackIndex, atTime, descPtr, outId));
        return outId.value;
      } finally {
        calloc.free(outId);
      }
    });
  }

  @override
  Future<void> rollEdit(int timelineId, int clipId, double deltaSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_roll_edit(ptr, clipId, deltaSec));
  }

  @override
  Future<void> slipEdit(int timelineId, int clipId, double deltaSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_slip_edit(ptr, clipId, deltaSec));
  }

  @override
  Future<void> slideEdit(int timelineId, int clipId, double deltaSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_slide_edit(ptr, clipId, deltaSec));
  }

  @override
  Future<void> rateStretch(int timelineId, int clipId, double newDurationSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_rate_stretch(ptr, clipId, newDurationSec));
  }

  @override
  Future<int> duplicateClip(int timelineId, int clipId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outId = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_duplicate_clip(ptr, clipId, outId));
      return outId.value;
    } finally {
      calloc.free(outId);
    }
  }

  @override
  Future<List<double>> getSnapPoints(int timelineId, double timeSec, double thresholdSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    const maxPoints = 64;
    final outPoints = calloc<Double>(maxPoints);
    final outCount = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_get_snap_points(
          ptr, timeSec, thresholdSec, outPoints, maxPoints, outCount));
      final count = outCount.value;
      return List<double>.generate(count, (i) => outPoints[i]);
    } finally {
      calloc.free(outPoints);
      calloc.free(outCount);
    }
  }

  @override
  Future<void> reorderTracks(int timelineId, List<int> newOrder) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final orderPtr = calloc<Int32>(newOrder.length);
    try {
      for (var i = 0; i < newOrder.length; i++) {
        orderPtr[i] = newOrder[i];
      }
      _checkErr(_b.gopost_timeline_reorder_tracks(ptr, orderPtr, newOrder.length));
    } finally {
      calloc.free(orderPtr);
    }
  }

  // =========================================================================
  // Phase 3: Effect DAG & Registry — wired to native C stubs
  // =========================================================================

  @override
  Future<List<EngineEffectDef>> listEffects({String? category}) async {
    // Native C stubs return OK with no-op; return empty list until implemented.
    return const [];
  }

  @override
  Future<int> addClipEffect(int timelineId, int clipId, String effectDefId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final defIdPtr = effectDefId.toNativeUtf8();
    final outId = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_add_clip_effect(ptr, clipId, defIdPtr.cast(), outId));
      return outId.value;
    } finally {
      calloc.free(defIdPtr);
      calloc.free(outId);
    }
  }

  @override
  Future<void> removeClipEffect(int timelineId, int clipId, int effectInstanceId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_clip_effect(ptr, clipId, effectInstanceId));
  }

  @override
  Future<void> reorderClipEffects(int timelineId, int clipId, List<int> instanceIds) async {
    // No native function for reorder — client-side reorder via remove+add.
  }

  @override
  Future<void> setEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final paramPtr = paramId.toNativeUtf8();
    try {
      _checkErr(_b.gopost_timeline_set_clip_effect_param(
          ptr, clipId, effectInstanceId, paramPtr.cast(), value));
    } finally {
      calloc.free(paramPtr);
    }
  }

  @override
  Future<void> setEffectEnabled(int timelineId, int clipId, int effectInstanceId, bool enabled) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_effect_enabled(
        ptr, clipId, effectInstanceId, enabled ? 1 : 0));
  }

  @override
  Future<void> setEffectMix(int timelineId, int clipId, int effectInstanceId, double mix) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_clip_effect_mix(ptr, clipId, effectInstanceId, mix));
  }

  // =========================================================================
  // Phase 4: Masking & Tracking — wired to native C stubs
  // =========================================================================

  @override
  Future<int> addClipMask(int timelineId, int clipId, MaskData mask) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final maskDesc = calloc<NativeGopostMaskDesc>();
    final pointsPtr = mask.points.isNotEmpty
        ? calloc<NativeGopostMaskPoint>(mask.points.length)
        : nullptr;
    try {
      maskDesc.ref.type = mask.type.index;
      maskDesc.ref.feather = mask.feather;
      maskDesc.ref.opacity = mask.opacity;
      maskDesc.ref.inverted = mask.inverted ? 1 : 0;
      maskDesc.ref.expansion = mask.expansion;
      maskDesc.ref.pointCount = mask.points.length;
      for (var i = 0; i < mask.points.length; i++) {
        final p = mask.points[i];
        pointsPtr![i].x = p.x;
        pointsPtr[i].y = p.y;
        pointsPtr[i].handleInX = p.handleInX;
        pointsPtr[i].handleInY = p.handleInY;
        pointsPtr[i].handleOutX = p.handleOutX;
        pointsPtr[i].handleOutY = p.handleOutY;
      }
      final outId = calloc<Int32>();
      try {
        _checkErr(_b.gopost_timeline_add_clip_mask(
            ptr, clipId, maskDesc, pointsPtr ?? Pointer.fromAddress(0), outId));
        return outId.value;
      } finally {
        calloc.free(outId);
      }
    } finally {
      calloc.free(maskDesc);
      if (pointsPtr != null) calloc.free(pointsPtr);
    }
  }

  @override
  Future<void> updateClipMask(int timelineId, int clipId, int maskId, MaskData mask) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final maskDesc = calloc<NativeGopostMaskDesc>();
    final pointsPtr = mask.points.isNotEmpty
        ? calloc<NativeGopostMaskPoint>(mask.points.length)
        : nullptr;
    try {
      maskDesc.ref.type = mask.type.index;
      maskDesc.ref.feather = mask.feather;
      maskDesc.ref.opacity = mask.opacity;
      maskDesc.ref.inverted = mask.inverted ? 1 : 0;
      maskDesc.ref.expansion = mask.expansion;
      maskDesc.ref.pointCount = mask.points.length;
      for (var i = 0; i < mask.points.length; i++) {
        final p = mask.points[i];
        pointsPtr![i].x = p.x;
        pointsPtr[i].y = p.y;
        pointsPtr[i].handleInX = p.handleInX;
        pointsPtr[i].handleInY = p.handleInY;
        pointsPtr[i].handleOutX = p.handleOutX;
        pointsPtr[i].handleOutY = p.handleOutY;
      }
      _checkErr(_b.gopost_timeline_update_clip_mask(
          ptr, clipId, maskId, maskDesc, pointsPtr ?? Pointer.fromAddress(0)));
    } finally {
      calloc.free(maskDesc);
      if (pointsPtr != null) calloc.free(pointsPtr);
    }
  }

  @override
  Future<void> removeClipMask(int timelineId, int clipId, int maskId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_clip_mask(ptr, clipId, maskId));
  }

  @override
  Future<int> startTracking(int timelineId, int clipId, double x, double y, double timeSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outId = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_start_tracking(ptr, clipId, x, y, timeSec, outId));
      return outId.value;
    } finally {
      calloc.free(outId);
    }
  }

  @override
  Future<List<TrackPoint>> getTrackingData(int timelineId, int trackerId) async {
    // No native getter yet — tracking data is returned via event stream when ready.
    return const [];
  }

  @override
  Future<void> stabilizeClip(int timelineId, int clipId, StabilizationConfig config) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_stabilize_clip(
        ptr, clipId, config.method.index, config.smoothness, config.cropToStable ? 1 : 0));
  }

  // =========================================================================
  // Phase 5: Text, Shapes, Audio Effects — wired to native C stubs
  // =========================================================================

  @override
  Future<void> setClipText(int timelineId, int clipId, TextLayerData textData) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final desc = calloc<NativeGopostTextLayerDesc>();
    try {
      _writeFixedString(desc.ref.text, textData.text, 512);
      _writeFixedString(desc.ref.fontFamily, textData.fontFamily, 128);
      _writeFixedString(desc.ref.fontStyle, textData.fontStyle, 64);
      desc.ref.fontSize = textData.fontSize;
      desc.ref.fillColor = textData.fillColor;
      desc.ref.fillEnabled = textData.fillEnabled ? 1 : 0;
      desc.ref.strokeColor = textData.strokeColor;
      desc.ref.strokeWidth = textData.strokeWidth;
      desc.ref.strokeEnabled = textData.strokeEnabled ? 1 : 0;
      desc.ref.alignment = textData.alignment.index;
      desc.ref.tracking = textData.tracking;
      desc.ref.leading = textData.leading;
      desc.ref.positionX = textData.positionX;
      desc.ref.positionY = textData.positionY;
      desc.ref.rotation = textData.rotation;
      desc.ref.scaleX = textData.scaleX;
      desc.ref.scaleY = textData.scaleY;
      _checkErr(_b.gopost_timeline_set_clip_text(ptr, clipId, desc));
    } finally {
      calloc.free(desc);
    }
  }

  /// Write a Dart string into a fixed-size native char array.
  void _writeFixedString(Array<Int8> dest, String src, int maxLen) {
    final len = src.length > maxLen - 1 ? maxLen - 1 : src.length;
    for (var i = 0; i < len; i++) {
      dest[i] = src.codeUnitAt(i);
    }
    dest[len] = 0;
  }

  @override
  Future<int> addClipShape(int timelineId, int clipId, ShapeData shape) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final desc = calloc<NativeGopostShapeDesc>();
    final outId = calloc<Int32>();
    try {
      desc.ref.type = shape.type.index;
      desc.ref.x = shape.x;
      desc.ref.y = shape.y;
      desc.ref.width = shape.width;
      desc.ref.height = shape.height;
      desc.ref.rotation = shape.rotation;
      desc.ref.fillColor = shape.fillColor;
      desc.ref.fillEnabled = shape.fillEnabled ? 1 : 0;
      desc.ref.strokeColor = shape.strokeColor;
      desc.ref.strokeWidth = shape.strokeWidth;
      desc.ref.strokeEnabled = shape.strokeEnabled ? 1 : 0;
      desc.ref.cornerRadius = shape.cornerRadius;
      desc.ref.sides = shape.sides;
      desc.ref.innerRadius = shape.innerRadius;
      _checkErr(_b.gopost_timeline_add_clip_shape(ptr, clipId, desc, outId));
      return outId.value;
    } finally {
      calloc.free(desc);
      calloc.free(outId);
    }
  }

  @override
  Future<void> updateClipShape(int timelineId, int clipId, int shapeId, ShapeData shape) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final desc = calloc<NativeGopostShapeDesc>();
    try {
      desc.ref.type = shape.type.index;
      desc.ref.x = shape.x;
      desc.ref.y = shape.y;
      desc.ref.width = shape.width;
      desc.ref.height = shape.height;
      desc.ref.rotation = shape.rotation;
      desc.ref.fillColor = shape.fillColor;
      desc.ref.fillEnabled = shape.fillEnabled ? 1 : 0;
      desc.ref.strokeColor = shape.strokeColor;
      desc.ref.strokeWidth = shape.strokeWidth;
      desc.ref.strokeEnabled = shape.strokeEnabled ? 1 : 0;
      desc.ref.cornerRadius = shape.cornerRadius;
      desc.ref.sides = shape.sides;
      desc.ref.innerRadius = shape.innerRadius;
      _checkErr(_b.gopost_timeline_update_clip_shape(ptr, clipId, shapeId, desc));
    } finally {
      calloc.free(desc);
    }
  }

  @override
  Future<void> removeClipShape(int timelineId, int clipId, int shapeId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_clip_shape(ptr, clipId, shapeId));
  }

  @override
  Future<int> addAudioEffect(int timelineId, int clipId, String audioEffectDefId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final defIdPtr = audioEffectDefId.toNativeUtf8();
    final outId = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_add_audio_effect(ptr, clipId, defIdPtr.cast(), outId));
      return outId.value;
    } finally {
      calloc.free(defIdPtr);
      calloc.free(outId);
    }
  }

  @override
  Future<void> setAudioEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final paramPtr = paramId.toNativeUtf8();
    try {
      _checkErr(_b.gopost_timeline_set_audio_effect_param(
          ptr, clipId, effectInstanceId, paramPtr.cast(), value));
    } finally {
      calloc.free(paramPtr);
    }
  }

  @override
  Future<void> removeAudioEffect(int timelineId, int clipId, int effectInstanceId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_remove_audio_effect(ptr, clipId, effectInstanceId));
  }

  @override
  Future<List<AudioEffectDef>> listAudioEffects() async {
    // Native C stubs return OK with no-op; return empty list until implemented.
    return const [];
  }

  // =========================================================================
  // Phase 6: AI, Proxy, Multi-Cam — wired to native C stubs
  // =========================================================================

  @override
  Future<int> startAiSegmentation(int timelineId, int clipId, AiSegmentationConfig config) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outId = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_start_ai_segmentation(
          ptr, clipId, config.type.index, config.edgeFeather, config.refineEdges ? 1 : 0, outId));
      return outId.value;
    } finally {
      calloc.free(outId);
    }
  }

  @override
  Future<double> getAiSegmentationProgress(int jobId) async {
    return _b.gopost_ai_segmentation_get_progress(jobId);
  }

  @override
  Future<void> cancelAiSegmentation(int jobId) async {
    _checkErr(_b.gopost_ai_segmentation_cancel(jobId));
  }

  @override
  Future<void> enableProxyMode(int timelineId, ProxyConfig config) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_enable_proxy_mode(
        ptr, config.resolution.index, config.videoCodec, config.bitrateBps));
  }

  @override
  Future<void> disableProxyMode(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_disable_proxy_mode(ptr));
  }

  @override
  Future<bool> isProxyModeActive(int timelineId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final out = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_is_proxy_active(ptr, out));
      return out.value != 0;
    } finally {
      calloc.free(out);
    }
  }

  @override
  Future<int> createMultiCamClip(int timelineId, int trackIndex, MultiCamConfig config) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final anglesPtr = calloc<NativeGopostCameraAngle>(config.angles.length);
    final outId = calloc<Int32>();
    try {
      for (var i = 0; i < config.angles.length; i++) {
        final a = config.angles[i];
        _writeFixedString(anglesPtr[i].name, a.name, 128);
        _writeFixedString(anglesPtr[i].sourcePath, a.sourcePath, 1024);
        anglesPtr[i].syncOffset = a.syncOffset;
      }
      _checkErr(_b.gopost_timeline_create_multicam_clip(
          ptr, trackIndex, config.name.toNativeUtf8().cast(),
          anglesPtr, config.angles.length, config.durationSec, outId));
      return outId.value;
    } finally {
      calloc.free(anglesPtr);
      calloc.free(outId);
    }
  }

  @override
  Future<void> switchMultiCamAngle(int timelineId, int clipId, int angleIndex, double atTimeSec) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_switch_multicam_angle(ptr, clipId, angleIndex, atTimeSec));
  }

  @override
  Future<void> flattenMultiCam(int timelineId, int clipId) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_flatten_multicam(ptr, clipId));
  }

  // =========================================================================
  // Phase 7: Extended Clip Engine — multi-clip, collision, sync-lock
  // =========================================================================

  @override
  Future<void> moveMultipleClips(int timelineId, List<int> clipIds, double deltaTime, int deltaTrack) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final idsPtr = calloc<Int32>(clipIds.length);
    try {
      for (var i = 0; i < clipIds.length; i++) {
        idsPtr[i] = clipIds[i];
      }
      _checkErr(_b.gopost_timeline_move_multiple_clips(
          ptr, idsPtr, clipIds.length, deltaTime, deltaTrack));
    } finally {
      calloc.free(idsPtr);
    }
  }

  @override
  Future<void> swapClips(int timelineId, int clipIdA, int clipIdB) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_swap_clips(ptr, clipIdA, clipIdB));
  }

  @override
  Future<int> splitAllTracks(int timelineId, double splitTimeSeconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outCount = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_split_all_tracks(ptr, splitTimeSeconds, outCount));
      return outCount.value;
    } finally {
      calloc.free(outCount);
    }
  }

  @override
  Future<void> liftDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_lift_delete(ptr, trackIndex, rangeStartSeconds, rangeEndSeconds));
  }

  @override
  Future<int> checkOverlap(int timelineId, int trackIndex, double inTime, double outTime, {int excludeClipId = -1}) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final outResult = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_check_overlap(ptr, trackIndex, inTime, outTime, excludeClipId, outResult));
      return outResult.value;
    } finally {
      calloc.free(outResult);
    }
  }

  @override
  Future<List<int>> getOverlappingClips(int timelineId, int trackIndex, double inTime, double outTime) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    const maxIds = 128;
    final outIds = calloc<Int32>(maxIds);
    final outCount = calloc<Int32>();
    try {
      _checkErr(_b.gopost_timeline_get_overlapping_clips(
          ptr, trackIndex, inTime, outTime, outIds, maxIds, outCount));
      final count = outCount.value;
      return List<int>.generate(count, (i) => outIds[i]);
    } finally {
      calloc.free(outIds);
      calloc.free(outCount);
    }
  }

  @override
  Future<void> setTrackSyncLock(int timelineId, int trackIndex, bool locked) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_track_sync_lock(ptr, trackIndex, locked ? 1 : 0));
  }

  @override
  Future<void> setTrackHeight(int timelineId, int trackIndex, double heightPx) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    _checkErr(_b.gopost_timeline_set_track_height(ptr, trackIndex, heightPx));
  }

  @override
  Future<double> getTrackHeight(int timelineId, int trackIndex) async {
    final ptr = _timelines[timelineId];
    if (ptr == null) throw StateError('Unknown timeline $timelineId');
    final out = calloc<Float>();
    try {
      _checkErr(_b.gopost_timeline_get_track_height(ptr, trackIndex, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  // =========================================================================
  // Texture Bridge
  // =========================================================================

  Pointer<Void>? _textureBridge;
  int _textureBridgeId = -1;

  @override
  Future<int> createTextureBridge(int width, int height) async {
    if (_textureBridge != null) {
      // Already created — destroy the old one first
      await destroyTextureBridge();
    }

    final outBridge = calloc<Pointer<Void>>();
    final outId = calloc<Int64>();
    try {
      _checkErr(_b.gopost_texture_bridge_create(
          _enginePtr, width, height, outBridge, outId));
      _textureBridge = outBridge.value;
      _textureBridgeId = outId.value;
      return _textureBridgeId;
    } finally {
      calloc.free(outBridge);
      calloc.free(outId);
    }
  }

  @override
  Future<void> destroyTextureBridge() async {
    if (_textureBridge != null) {
      _b.gopost_texture_bridge_destroy(_textureBridge!);
      _textureBridge = null;
      _textureBridgeId = -1;
    }
  }

  @override
  Future<bool> renderToTextureBridge(int timelineId) async {
    final tlPtr = _timelines[timelineId];
    if (tlPtr == null || _textureBridge == null) return false;

    // Render a frame from the timeline evaluator
    final outFrame = calloc<Pointer<Void>>();
    try {
      final err = _b.gopost_timeline_render_frame(tlPtr, outFrame);
      if (err != 0) return false;
      final framePtr = outFrame.value;
      if (framePtr == nullptr) return false;

      try {
        // Push the rendered frame to the texture bridge
        final frame = framePtr.cast<NativeGopostFrame>();
        _checkErr(_b.gopost_texture_bridge_update_frame(
            _textureBridge!, frame));
        return true;
      } finally {
        _b.gopost_frame_release(_enginePtr, framePtr);
      }
    } finally {
      calloc.free(outFrame);
    }
  }

  @override
  Future<void> resizeTextureBridge(int width, int height) async {
    if (_textureBridge == null) return;
    _checkErr(_b.gopost_texture_bridge_resize(
        _textureBridge!, width, height));
  }

  @override
  Future<Uint8List?> getTextureBridgePixels() async {
    if (_textureBridge == null) return null;

    final outData = calloc<Pointer<Uint8>>();
    final outWidth = calloc<Int32>();
    final outHeight = calloc<Int32>();
    final outCounter = calloc<Int64>();
    try {
      final err = _b.gopost_texture_bridge_get_pixels(
          _textureBridge!, outData, outWidth, outHeight, outCounter);
      if (err != 0) return null;

      final dataPtr = outData.value;
      if (dataPtr == nullptr) return null;

      final w = outWidth.value;
      final h = outHeight.value;
      final byteCount = w * h * 4;
      if (byteCount <= 0) return null;

      // Copy the pixel data — the native buffer may be swapped on next update
      return Uint8List.fromList(dataPtr.asTypedList(byteCount));
    } finally {
      calloc.free(outData);
      calloc.free(outWidth);
      calloc.free(outHeight);
      calloc.free(outCounter);
    }
  }
}
