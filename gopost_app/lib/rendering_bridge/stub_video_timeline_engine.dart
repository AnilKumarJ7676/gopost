import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Stub [VideoTimelineEngine] when the native library is not available.
/// All operations throw or return safe defaults so the video editor UI can load.
class StubVideoTimelineEngine implements VideoTimelineEngine {
  final Map<int, TimelineConfig> _configs = {};
  int _nextId = 1;
  int _nextTrackIdx = 0;
  int _nextClipId = 1;

  @override
  Future<int> createTimeline(TimelineConfig config) async {
    final id = _nextId++;
    _configs[id] = config;
    return id;
  }

  @override
  Future<void> destroyTimeline(int timelineId) async {
    _configs.remove(timelineId);
  }

  @override
  Future<TimelineConfig> getTimelineConfig(int timelineId) async {
    final c = _configs[timelineId];
    if (c == null) throw StateError('Unknown timeline $timelineId');
    return c;
  }

  @override
  Future<double> getDuration(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0.0;
  }

  @override
  Future<int> addTrack(int timelineId, VideoTrackType type) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextTrackIdx++;
  }

  @override
  Future<void> removeTrack(int timelineId, int trackIndex) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<int> getTrackCount(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<int> addClip(int timelineId, ClipDescriptor descriptor) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextClipId++;
  }

  @override
  Future<void> removeClip(int timelineId, int clipId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> trimClip(int timelineId, int clipId, TimelineRange newRange, SourceRange newSource) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> moveClip(int timelineId, int clipId, int newTrackIndex, double newInTime) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<int?> splitClip(int timelineId, int clipId, double splitTimeSeconds) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextClipId++;
  }

  @override
  Future<void> rippleDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> seek(int timelineId, double positionSeconds) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<DecodedImage?> renderFrame(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return null;
  }

  @override
  Future<double> getPosition(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0.0;
  }

  @override
  Future<void> setFrameCacheSizeBytes(int timelineId, int maxBytes) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> invalidateFrameCache(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<MediaInfo?> probeMedia(String filePath) async {
    final isImage = filePath.endsWith('.jpg') ||
        filePath.endsWith('.jpeg') ||
        filePath.endsWith('.png') ||
        filePath.endsWith('.webp');
    return MediaInfo(
      durationSeconds: isImage ? 5.0 : 10.0,
      width: 1920,
      height: 1080,
      frameRate: isImage ? 1.0 : 30.0,
      frameCount: isImage ? 1 : 300,
      hasAudio: !isImage,
      audioSampleRate: isImage ? 0 : 48000,
      audioChannels: isImage ? 0 : 2,
      audioDurationSeconds: isImage ? 0 : 10.0,
    );
  }

  @override
  Future<void> setClipVolume(int timelineId, int clipId, double volume) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<double> getClipVolume(int timelineId, int clipId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 1.0;
  }

  // --- Transitions (S10) ---

  @override
  Future<void> setClipTransitionIn(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setClipTransitionOut(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // --- Keyframes (S10) ---

  @override
  Future<void> setClipKeyframe(int timelineId, int clipId,
      int property, double time, double value, int interpolation) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> removeClipKeyframe(int timelineId, int clipId,
      int property, double time) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> clearClipKeyframes(int timelineId, int clipId, int property) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // --- Effects (S10) ---

  @override
  Future<void> setClipColorGrading(int timelineId, int clipId, {
    double brightness = 0, double contrast = 0, double saturation = 0,
    double exposure = 0, double temperature = 0, double tint = 0,
    double highlights = 0, double shadows = 0, double vibrance = 0,
    double hue = 0,
  }) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> clearClipEffects(int timelineId, int clipId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // --- Audio enhancements (S10) ---

  @override
  Future<void> setClipPan(int timelineId, int clipId, double pan) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setClipFadeIn(int timelineId, int clipId, double seconds) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setClipFadeOut(int timelineId, int clipId, double seconds) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setTrackVolume(int timelineId, int trackIndex, double volume) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setTrackPan(int timelineId, int trackIndex, double pan) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setTrackMute(int timelineId, int trackIndex, bool mute) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setTrackSolo(int timelineId, int trackIndex, bool solo) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // --- Export pipeline (S11) ---

  int _nextExportId = 1;
  final Map<int, double> _exportProgress = {};

  @override
  Future<int> startExport(int timelineId, VideoExportConfig config) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    final jobId = _nextExportId++;
    _exportProgress[jobId] = 0.0;
    // Stub: simulate a quick export completion
    Future.delayed(const Duration(milliseconds: 500), () {
      _exportProgress[jobId] = 1.0;
    });
    return jobId;
  }

  @override
  Future<double> getExportProgress(int exportJobId) async {
    return _exportProgress[exportJobId] ?? -1.0;
  }

  @override
  Future<void> cancelExport(int exportJobId) async {
    _exportProgress.remove(exportJobId);
  }

  @override
  bool get supportsHardwareEncoding => false;

  // =========================================================================
  // Phase 2: NLE Edit Operations
  // =========================================================================

  @override
  Future<int> insertEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextClipId++;
  }

  @override
  Future<int> overwriteEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextClipId++;
  }

  @override
  Future<void> rollEdit(int timelineId, int clipId, double deltaSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> slipEdit(int timelineId, int clipId, double deltaSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> slideEdit(int timelineId, int clipId, double deltaSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> rateStretch(int timelineId, int clipId, double newDurationSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<int> duplicateClip(int timelineId, int clipId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextClipId++;
  }

  @override
  Future<List<double>> getSnapPoints(int timelineId, double timeSec, double thresholdSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return [];
  }

  @override
  Future<void> reorderTracks(int timelineId, List<int> newOrder) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // =========================================================================
  // Phase 3: Effect DAG & Registry
  // =========================================================================

  @override
  Future<List<EngineEffectDef>> listEffects({String? category}) async => [];

  @override
  Future<int> addClipEffect(int timelineId, int clipId, String effectDefId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<void> removeClipEffect(int timelineId, int clipId, int effectInstanceId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> reorderClipEffects(int timelineId, int clipId, List<int> instanceIds) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setEffectEnabled(int timelineId, int clipId, int effectInstanceId, bool enabled) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> setEffectMix(int timelineId, int clipId, int effectInstanceId, double mix) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // =========================================================================
  // Phase 4: Masking & Tracking
  // =========================================================================

  @override
  Future<int> addClipMask(int timelineId, int clipId, MaskData mask) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<void> updateClipMask(int timelineId, int clipId, int maskId, MaskData mask) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> removeClipMask(int timelineId, int clipId, int maskId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<int> startTracking(int timelineId, int clipId, double x, double y, double timeSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<List<TrackPoint>> getTrackingData(int timelineId, int trackerId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return [];
  }

  @override
  Future<void> stabilizeClip(int timelineId, int clipId, StabilizationConfig config) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  // =========================================================================
  // Phase 5: Text Layers, Shapes, Audio Effects
  // =========================================================================

  @override
  Future<void> setClipText(int timelineId, int clipId, TextLayerData textData) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<int> addClipShape(int timelineId, int clipId, ShapeData shape) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<void> updateClipShape(int timelineId, int clipId, int shapeId, ShapeData shape) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> removeClipShape(int timelineId, int clipId, int shapeId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<int> addAudioEffect(int timelineId, int clipId, String audioEffectDefId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<void> setAudioEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> removeAudioEffect(int timelineId, int clipId, int effectInstanceId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<List<AudioEffectDef>> listAudioEffects() async => [];

  // =========================================================================
  // Phase 6: AI, Proxy, Multi-Cam
  // =========================================================================

  @override
  Future<int> startAiSegmentation(int timelineId, int clipId, AiSegmentationConfig config) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return 0;
  }

  @override
  Future<double> getAiSegmentationProgress(int jobId) async => -1.0;

  @override
  Future<void> cancelAiSegmentation(int jobId) async {}

  @override
  Future<void> enableProxyMode(int timelineId, ProxyConfig config) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> disableProxyMode(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<bool> isProxyModeActive(int timelineId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return false;
  }

  @override
  Future<int> createMultiCamClip(int timelineId, int trackIndex, MultiCamConfig config) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
    return _nextClipId++;
  }

  @override
  Future<void> switchMultiCamAngle(int timelineId, int clipId, int angleIndex, double atTimeSec) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }

  @override
  Future<void> flattenMultiCam(int timelineId, int clipId) async {
    if (!_configs.containsKey(timelineId)) throw StateError('Unknown timeline $timelineId');
  }
}
