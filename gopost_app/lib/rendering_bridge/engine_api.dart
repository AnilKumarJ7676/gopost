import 'dart:typed_data';

/// GPU capabilities reported by the native engine.
class GpuCapabilities {
  final String renderer;
  final bool supportsCompute;
  final int maxTextureSize;
  final int maxFramebufferSize;

  const GpuCapabilities({
    required this.renderer,
    required this.supportsCompute,
    required this.maxTextureSize,
    required this.maxFramebufferSize,
  });
}

/// Metadata extracted after loading and decrypting a template.
class TemplateMetadata {
  final String templateId;
  final String name;
  final String description;
  final int width;
  final int height;
  final int? durationMs;
  final int layerCount;
  final int version;

  const TemplateMetadata({
    required this.templateId,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    this.durationMs,
    required this.layerCount,
    required this.version,
  });
}

/// Engine configuration for initialization.
class EngineConfig {
  final int threadCount;
  final int framePoolSizeMb;
  final bool enableGpu;
  final int logLevel;

  const EngineConfig({
    this.threadCount = 4,
    this.framePoolSizeMb = 128,
    this.enableGpu = true,
    this.logLevel = 2,
  });
}

/// ISP: Core engine lifecycle operations.
abstract class EngineLifecycle {
  Future<void> initialize(EngineConfig config);
  Future<void> dispose();
  bool get isInitialized;
  Future<String> getVersion();
}

/// Hardware decoder capability info.
class HwDecoderInfo {
  final bool available;
  final String deviceName;
  final int maxWidth;
  final int maxHeight;

  const HwDecoderInfo({
    required this.available,
    this.deviceName = '',
    this.maxWidth = 0,
    this.maxHeight = 0,
  });
}

/// ISP: GPU-related queries separated from main engine.
abstract class GpuQueryable {
  Future<GpuCapabilities> queryGpuCapabilities();
  Future<HwDecoderInfo> queryHwDecoder();
}

/// ISP: Template load/unload operations.
abstract class TemplateLoader {
  Future<TemplateMetadata> loadTemplate(
      Uint8List encryptedBlob, Uint8List sessionKey);
  Future<void> unloadTemplate(String templateId);
}

// ---------------------------------------------------------------------------
// Sprint 5: Canvas & Image Codec interfaces
// ---------------------------------------------------------------------------

/// Image format for encode/decode.
enum ImageFormat { jpeg, png, webp, heic, bmp, gif, tiff, tga }

/// Probed metadata from raw image bytes.
class ImageInfo {
  final int width;
  final int height;
  final int channels;
  final ImageFormat format;
  final bool hasAlpha;

  const ImageInfo({
    required this.width,
    required this.height,
    required this.channels,
    required this.format,
    required this.hasAlpha,
  });
}

/// Decoded RGBA pixel buffer.
class DecodedImage {
  final int width;
  final int height;
  final Uint8List pixels;

  const DecodedImage({
    required this.width,
    required this.height,
    required this.pixels,
  });
}

/// ISP: Image decoding operations.
abstract class ImageDecoder {
  Future<ImageInfo> probeImage(Uint8List data);
  Future<DecodedImage> decodeImage(Uint8List data);
  Future<DecodedImage> decodeImageResized(
      Uint8List data, int maxWidth, int maxHeight);
  Future<DecodedImage> decodeImageFile(String path);
}

/// ISP: Image encoding operations.
abstract class ImageEncoder {
  Future<Uint8List> encodeJpeg(DecodedImage image, {int quality = 85});
  Future<Uint8List> encodePng(DecodedImage image);
  Future<Uint8List> encodeWebp(DecodedImage image,
      {int quality = 80, bool lossless = false});
  Future<void> encodeToFile(
      DecodedImage image, String path, ImageFormat format,
      {int quality = 85});
}

/// Blend modes supported by the composition pipeline.
enum BlendMode { normal, multiply, screen, overlay }

/// Layer types in the canvas model.
enum LayerType { image, solidColor, text, shape, group, adjustment, gradient, sticker }

/// Canvas color space.
enum CanvasColorSpace { srgb, displayP3, adobeRgb }

/// Configuration for creating a new canvas.
class CanvasConfig {
  final int width;
  final int height;
  final double dpi;
  final CanvasColorSpace colorSpace;
  final double bgR, bgG, bgB, bgA;
  final bool transparentBackground;

  const CanvasConfig({
    required this.width,
    required this.height,
    this.dpi = 72.0,
    this.colorSpace = CanvasColorSpace.srgb,
    this.bgR = 1.0,
    this.bgG = 1.0,
    this.bgB = 1.0,
    this.bgA = 1.0,
    this.transparentBackground = false,
  });
}

/// Read-only layer information returned from the engine.
class LayerInfo {
  final int id;
  final LayerType type;
  final String name;
  final double opacity;
  final BlendMode blendMode;
  final bool visible;
  final bool locked;
  final double tx, ty;
  final double sx, sy;
  final double rotation;
  final int contentWidth;
  final int contentHeight;

  const LayerInfo({
    required this.id,
    required this.type,
    required this.name,
    required this.opacity,
    required this.blendMode,
    required this.visible,
    required this.locked,
    required this.tx,
    required this.ty,
    required this.sx,
    required this.sy,
    required this.rotation,
    required this.contentWidth,
    required this.contentHeight,
  });
}

/// Viewport state for pan/zoom navigation.
class ViewportState {
  final double panX;
  final double panY;
  final double zoom;
  final double rotation;

  const ViewportState({
    this.panX = 0,
    this.panY = 0,
    this.zoom = 1.0,
    this.rotation = 0,
  });
}

/// ISP: Canvas lifecycle operations.
abstract class CanvasManager {
  Future<int> createCanvas(CanvasConfig config);
  Future<void> destroyCanvas(int canvasId);
  Future<({int width, int height, double dpi})> getCanvasSize(int canvasId);
  Future<void> resizeCanvas(int canvasId, int width, int height);
}

/// ISP: Layer management operations.
abstract class LayerManager {
  Future<int> addImageLayer(
      int canvasId, Uint8List rgbaPixels, int width, int height,
      {int index = -1});
  Future<int> addSolidLayer(
      int canvasId, double r, double g, double b, double a,
      int width, int height,
      {int index = -1});
  Future<int> addGroupLayer(int canvasId, String name, {int index = -1});
  Future<void> removeLayer(int canvasId, int layerId);
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex);
  Future<int> duplicateLayer(int canvasId, int layerId);
  Future<int> getLayerCount(int canvasId);
  Future<LayerInfo> getLayerInfo(int canvasId, int layerId);
  Future<List<int>> getLayerIds(int canvasId);
}

/// ISP: Layer property setters.
abstract class LayerPropertyEditor {
  Future<void> setLayerVisible(int canvasId, int layerId, bool visible);
  Future<void> setLayerLocked(int canvasId, int layerId, bool locked);
  Future<void> setLayerOpacity(int canvasId, int layerId, double opacity);
  Future<void> setLayerBlendMode(
      int canvasId, int layerId, BlendMode blendMode);
  Future<void> setLayerName(int canvasId, int layerId, String name);
  Future<void> setLayerTransform(int canvasId, int layerId,
      {double tx = 0,
      double ty = 0,
      double sx = 1,
      double sy = 1,
      double rotation = 0});
}

/// ISP: Canvas rendering operations.
abstract class CanvasRenderer {
  Future<DecodedImage> renderCanvas(int canvasId);
  Future<void> invalidateCanvas(int canvasId);
  Future<void> invalidateLayer(int canvasId, int layerId);
}

/// ISP: GPU texture output for Flutter Texture widget.
abstract class GpuTextureOutput {
  Future<({int textureHandle, int width, int height})> renderToGpuTexture(
      int canvasId);
  Future<void> setViewport(int canvasId, ViewportState viewport);
  Future<ViewportState> getViewport(int canvasId);
}

// ---------------------------------------------------------------------------
// Sprint 6: Effect/Filter system interfaces
// ---------------------------------------------------------------------------

/// Effect parameter definition.
class EffectParamDef {
  final String id;
  final String displayName;
  final double defaultValue;
  final double minValue;
  final double maxValue;

  const EffectParamDef({
    required this.id,
    required this.displayName,
    required this.defaultValue,
    required this.minValue,
    required this.maxValue,
  });
}

/// Effect category.
enum EffectCategory { adjustment, color, blur, stylize, distort, preset }

/// Immutable effect definition from the engine registry.
class EffectDef {
  final String id;
  final String displayName;
  final EffectCategory category;
  final List<EffectParamDef> params;
  final bool gpuAccelerated;

  const EffectDef({
    required this.id,
    required this.displayName,
    required this.category,
    required this.params,
    this.gpuAccelerated = false,
  });
}

/// Mutable effect instance applied to a layer.
class EffectInstance {
  final int instanceId;
  final String effectId;
  bool enabled;
  double mix;
  final Map<String, double> paramValues;

  EffectInstance({
    required this.instanceId,
    required this.effectId,
    this.enabled = true,
    this.mix = 1.0,
    required this.paramValues,
  });
}

/// Preset filter info.
class PresetFilterInfo {
  final int index;
  final String name;
  final String category;

  const PresetFilterInfo({
    required this.index,
    required this.name,
    required this.category,
  });
}

/// ISP: Effect registry queries.
abstract class EffectRegistry {
  Future<void> initEffects();
  Future<void> shutdownEffects();
  Future<List<EffectDef>> getAllEffects();
  Future<EffectDef?> findEffect(String effectId);
  Future<List<EffectDef>> getEffectsByCategory(EffectCategory category);
}

/// ISP: Layer effect management.
abstract class LayerEffectManager {
  Future<int> addEffectToLayer(int canvasId, int layerId, String effectId);
  Future<void> removeEffectFromLayer(int canvasId, int layerId, int instanceId);
  Future<List<EffectInstance>> getLayerEffects(int canvasId, int layerId);
  Future<void> setEffectEnabled(int canvasId, int layerId, int instanceId, bool enabled);
  Future<void> setEffectMix(int canvasId, int layerId, int instanceId, double mix);
  Future<void> setEffectParam(int canvasId, int layerId, int instanceId, String paramId, double value);
  Future<double> getEffectParam(int canvasId, int layerId, int instanceId, String paramId);
}

/// ISP: Preset filter operations.
/// [applyPreset] returns the filtered image when the engine can produce it (for UI to replace canvas).
abstract class PresetFilterEngine {
  Future<List<PresetFilterInfo>> getPresetFilters();
  Future<DecodedImage?> applyPreset(int canvasId, int layerId, int presetIndex, double intensity);
}

// ---------------------------------------------------------------------------
// Sprint 6: Text engine interfaces
// ---------------------------------------------------------------------------

/// Font style options.
enum FontStyle { normal, bold, italic, boldItalic }

/// Text alignment.
enum TextAlignment { left, center, right, justify }

/// Configuration for a text layer.
class TextConfig {
  final String text;
  final String fontFamily;
  final FontStyle style;
  final double fontSize;
  final double colorR, colorG, colorB, colorA;
  final TextAlignment alignment;
  final double lineHeight;
  final double letterSpacing;
  final bool hasShadow;
  final double shadowColorR, shadowColorG, shadowColorB, shadowColorA;
  final double shadowOffsetX, shadowOffsetY, shadowBlur;
  final bool hasOutline;
  final double outlineColorR, outlineColorG, outlineColorB, outlineColorA;
  final double outlineWidth;

  const TextConfig({
    required this.text,
    this.fontFamily = 'System',
    this.style = FontStyle.normal,
    this.fontSize = 24,
    this.colorR = 1, this.colorG = 1, this.colorB = 1, this.colorA = 1,
    this.alignment = TextAlignment.left,
    this.lineHeight = 1.2,
    this.letterSpacing = 0,
    this.hasShadow = false,
    this.shadowColorR = 0, this.shadowColorG = 0,
    this.shadowColorB = 0, this.shadowColorA = 0.5,
    this.shadowOffsetX = 2, this.shadowOffsetY = 2, this.shadowBlur = 4,
    this.hasOutline = false,
    this.outlineColorR = 0, this.outlineColorG = 0,
    this.outlineColorB = 0, this.outlineColorA = 1,
    this.outlineWidth = 1,
  });
}

/// ISP: Text engine operations.
abstract class TextEngine {
  Future<void> initText();
  Future<void> shutdownText();
  Future<List<String>> getAvailableFonts();
  Future<int> addTextLayer(int canvasId, TextConfig config, int maxWidth, {int index = -1});
  Future<void> updateTextLayer(int canvasId, int layerId, TextConfig config, int maxWidth);
}

// ---------------------------------------------------------------------------
// Sprint 7: Export pipeline interfaces
// ---------------------------------------------------------------------------

enum ExportResolution { original, res4k, res1080p, res720p, instagramSquare, instagramStory, custom }

enum ExportFormat { jpeg, png, webp }

class ExportConfig {
  final ExportFormat format;
  final int quality;
  final ExportResolution resolution;
  final int customWidth;
  final int customHeight;
  final double dpi;

  const ExportConfig({
    this.format = ExportFormat.jpeg,
    this.quality = 85,
    this.resolution = ExportResolution.original,
    this.customWidth = 0,
    this.customHeight = 0,
    this.dpi = 72,
  });
}

class ExportResult {
  final String? filePath;
  final int fileSize;
  final int width;
  final int height;

  const ExportResult({this.filePath, this.fileSize = 0, this.width = 0, this.height = 0});
}

/// ISP: Image export operations.
abstract class ImageExporter {
  Future<ExportResult> exportToFile(int canvasId, ExportConfig config, String outputPath,
      {void Function(double progress)? onProgress});
  Future<int> estimateFileSize(int canvasId, ExportConfig config);
}

// ---------------------------------------------------------------------------
// Sprint 7: Mask interfaces
// ---------------------------------------------------------------------------

enum MaskType { none, raster, vector, clipping }
enum MaskBrushMode { paint, erase }

/// ISP: Layer mask operations.
abstract class LayerMaskManager {
  Future<void> addMask(int canvasId, int layerId, MaskType type);
  Future<void> removeMask(int canvasId, int layerId);
  Future<bool> hasMask(int canvasId, int layerId);
  Future<void> invertMask(int canvasId, int layerId);
  Future<void> setMaskEnabled(int canvasId, int layerId, bool enabled);
  Future<void> maskPaint(int canvasId, int layerId,
      double cx, double cy, double radius, double hardness,
      MaskBrushMode mode, double opacity);
  Future<void> maskFill(int canvasId, int layerId, int value);
}

// ---------------------------------------------------------------------------
// Sprint 7: Project save/load interfaces
// ---------------------------------------------------------------------------

/// ISP: Project persistence.
abstract class ProjectManager {
  Future<void> saveProject(int canvasId, String filePath);
  Future<int> loadProject(String filePath);
}

/// Composite interface — OCP: extend with new capabilities
/// without modifying existing interfaces.
abstract class GopostEngine
    implements EngineLifecycle, GpuQueryable, TemplateLoader {}

/// Composite interface for image editor engine operations.
abstract class ImageEditorEngine
    implements
        CanvasManager,
        LayerManager,
        LayerPropertyEditor,
        CanvasRenderer,
        GpuTextureOutput,
        ImageDecoder,
        ImageEncoder,
        EffectRegistry,
        LayerEffectManager,
        PresetFilterEngine,
        TextEngine,
        ImageExporter,
        LayerMaskManager,
        ProjectManager {}

// ---------------------------------------------------------------------------
// Sprint 8: Video timeline engine (cross-platform, memory-managed)
// ---------------------------------------------------------------------------

enum VideoTrackType { video, audio, title, effect, subtitle }
enum VideoClipSourceType { video, image, title, color }

class TimelineConfig {
  final double frameRate;
  final int width;
  final int height;
  final int colorSpace;

  const TimelineConfig({
    this.frameRate = 30.0,
    this.width = 1920,
    this.height = 1080,
    this.colorSpace = 0,
  });
}

class TimelineRange {
  final double inTime;
  final double outTime;
  const TimelineRange({required this.inTime, required this.outTime});
}

class SourceRange {
  final double sourceIn;
  final double sourceOut;
  const SourceRange({required this.sourceIn, required this.sourceOut});
}

class ClipDescriptor {
  final int trackIndex;
  final VideoClipSourceType sourceType;
  final String sourcePath;
  final TimelineRange timelineRange;
  final SourceRange sourceRange;
  final double speed;
  final double opacity;
  final int blendMode;
  final int effectHash;

  const ClipDescriptor({
    required this.trackIndex,
    required this.sourceType,
    required this.sourcePath,
    required this.timelineRange,
    required this.sourceRange,
    this.speed = 1.0,
    this.opacity = 1.0,
    this.blendMode = 0,
    this.effectHash = 0,
  });
}

/// Metadata returned by media probe (S8-01).
class MediaInfo {
  final double durationSeconds;
  final int width;
  final int height;
  final double frameRate;
  final int frameCount;
  final bool hasAudio;
  final int audioSampleRate;
  final int audioChannels;
  final double audioDurationSeconds;

  const MediaInfo({
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.frameCount,
    required this.hasAudio,
    required this.audioSampleRate,
    required this.audioChannels,
    required this.audioDurationSeconds,
  });
}

// =========================================================================
// ISP: Segregated interfaces for the video timeline engine.
// Each interface represents a single responsibility. Implementations
// compose them via `VideoTimelineEngine`.
// =========================================================================

/// Timeline lifecycle: create, destroy, configure.
abstract class TimelineLifecycle {
  Future<int> createTimeline(TimelineConfig config);
  Future<void> destroyTimeline(int timelineId);
  Future<TimelineConfig> getTimelineConfig(int timelineId);
  Future<double> getDuration(int timelineId);
}

/// Track CRUD and configuration.
abstract class TimelineTrackOps {
  Future<int> addTrack(int timelineId, VideoTrackType type);
  Future<void> removeTrack(int timelineId, int trackIndex);
  Future<int> getTrackCount(int timelineId);
  Future<void> reorderTracks(int timelineId, List<int> newOrder);
  Future<void> setTrackSyncLock(int timelineId, int trackIndex, bool locked);
  Future<void> setTrackHeight(int timelineId, int trackIndex, double heightPx);
  Future<double> getTrackHeight(int timelineId, int trackIndex);
}

/// Clip CRUD, move, trim, split, and collision detection.
abstract class TimelineClipOps {
  Future<int> addClip(int timelineId, ClipDescriptor descriptor);
  Future<void> removeClip(int timelineId, int clipId);
  Future<void> trimClip(int timelineId, int clipId, TimelineRange newRange, SourceRange newSource);
  Future<void> moveClip(int timelineId, int clipId, int newTrackIndex, double newInTime);
  Future<int?> splitClip(int timelineId, int clipId, double splitTimeSeconds);
  Future<void> rippleDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds);
  Future<void> moveMultipleClips(int timelineId, List<int> clipIds, double deltaTime, int deltaTrack);
  Future<void> swapClips(int timelineId, int clipIdA, int clipIdB);
  Future<int> splitAllTracks(int timelineId, double splitTimeSeconds);
  Future<void> liftDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds);
  /// Collision detection: 0=CLEAR, 1=OVERLAP, 2=ADJACENT.
  Future<int> checkOverlap(int timelineId, int trackIndex, double inTime, double outTime, {int excludeClipId = -1});
  Future<List<int>> getOverlappingClips(int timelineId, int trackIndex, double inTime, double outTime);
}

/// Playback, seek, render, frame cache.
abstract class TimelinePlayback {
  Future<void> seek(int timelineId, double positionSeconds);
  Future<DecodedImage?> renderFrame(int timelineId);
  Future<double> getPosition(int timelineId);
  Future<void> setFrameCacheSizeBytes(int timelineId, int maxBytes);
  Future<void> invalidateFrameCache(int timelineId);
}

/// NLE edit operations (insert, overwrite, roll, slip, slide, etc.).
abstract class TimelineNleEdits {
  Future<int> insertEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip);
  Future<int> overwriteEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip);
  Future<void> rollEdit(int timelineId, int clipId, double deltaSec);
  Future<void> slipEdit(int timelineId, int clipId, double deltaSec);
  Future<void> slideEdit(int timelineId, int clipId, double deltaSec);
  Future<void> rateStretch(int timelineId, int clipId, double newDurationSec);
  Future<int> duplicateClip(int timelineId, int clipId);
  Future<List<double>> getSnapPoints(int timelineId, double timeSec, double thresholdSec);
}

/// Media probing.
abstract class TimelineMediaProbe {
  Future<MediaInfo?> probeMedia(String filePath);
  Future<MediaInfo?> probeMediaFast(String filePath);
}

/// Composite interface — backwards-compatible with existing code.
/// All timelines share the same native engine.
abstract class VideoTimelineEngine implements
    TimelineLifecycle, TimelineTrackOps, TimelineClipOps, TimelinePlayback,
    TimelineNleEdits, TimelineMediaProbe {
  Future<int> createTimeline(TimelineConfig config);
  Future<void> destroyTimeline(int timelineId);
  Future<TimelineConfig> getTimelineConfig(int timelineId);
  Future<double> getDuration(int timelineId);
  Future<int> addTrack(int timelineId, VideoTrackType type);
  Future<void> removeTrack(int timelineId, int trackIndex);
  Future<int> getTrackCount(int timelineId);
  Future<int> addClip(int timelineId, ClipDescriptor descriptor);
  Future<void> removeClip(int timelineId, int clipId);
  Future<void> trimClip(int timelineId, int clipId, TimelineRange newRange, SourceRange newSource);
  Future<void> moveClip(int timelineId, int clipId, int newTrackIndex, double newInTime);
  /// Split clip at [splitTimeSeconds]. Returns new clip id or null on failure.
  Future<int?> splitClip(int timelineId, int clipId, double splitTimeSeconds);
  /// Ripple delete: remove clips on track in range and shift later clips left.
  Future<void> rippleDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds);
  Future<void> seek(int timelineId, double positionSeconds);
  Future<DecodedImage?> renderFrame(int timelineId);
  Future<double> getPosition(int timelineId);
  Future<void> setFrameCacheSizeBytes(int timelineId, int maxBytes);
  Future<void> invalidateFrameCache(int timelineId);

  /// Probe a media file for metadata (duration, dimensions, audio info).
  Future<MediaInfo?> probeMedia(String filePath);

  /// Fast, non-blocking probe using only header parsing or file-size
  /// heuristic. Returns immediately (< 100ms) with best-effort metadata.
  /// Callers should follow up with [probeMedia] in the background if
  /// accurate duration is needed.
  Future<MediaInfo?> probeMediaFast(String filePath);

  /// Set per-clip audio volume (0.0–2.0). Default is 1.0.
  Future<void> setClipVolume(int timelineId, int clipId, double volume);

  /// Get current per-clip audio volume.
  Future<double> getClipVolume(int timelineId, int clipId);

  // --- Transitions (S10) ---

  Future<void> setClipTransitionIn(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve);
  Future<void> setClipTransitionOut(int timelineId, int clipId,
      int transitionType, double durationSeconds, int easingCurve);

  // --- Keyframes (S10) ---

  Future<void> setClipKeyframe(int timelineId, int clipId,
      int property, double time, double value, int interpolation);
  Future<void> removeClipKeyframe(int timelineId, int clipId,
      int property, double time);
  Future<void> clearClipKeyframes(int timelineId, int clipId, int property);

  // --- Effects (S10) ---

  Future<void> setClipColorGrading(int timelineId, int clipId, {
    double brightness = 0, double contrast = 0, double saturation = 0,
    double exposure = 0, double temperature = 0, double tint = 0,
    double highlights = 0, double shadows = 0, double vibrance = 0,
    double hue = 0,
  });

  Future<void> clearClipEffects(int timelineId, int clipId);

  // --- Audio enhancements (S10) ---

  Future<void> setClipPan(int timelineId, int clipId, double pan);
  Future<void> setClipFadeIn(int timelineId, int clipId, double seconds);
  Future<void> setClipFadeOut(int timelineId, int clipId, double seconds);
  Future<void> setTrackVolume(int timelineId, int trackIndex, double volume);
  Future<void> setTrackPan(int timelineId, int trackIndex, double pan);
  Future<void> setTrackMute(int timelineId, int trackIndex, bool mute);
  Future<void> setTrackSolo(int timelineId, int trackIndex, bool solo);

  // --- Export pipeline (S11) ---

  /// Start an asynchronous video export. Returns a unique export job ID.
  Future<int> startExport(int timelineId, VideoExportConfig config);

  /// Poll the current export progress (0.0–1.0). Returns -1 if not exporting.
  Future<double> getExportProgress(int exportJobId);

  /// Cancel a running export.
  Future<void> cancelExport(int exportJobId);

  /// Whether the native engine supports HW-accelerated encoding.
  bool get supportsHardwareEncoding;

  // =========================================================================
  // Phase 2: NLE Edit Operations
  // =========================================================================

  /// Insert a clip at [atTime] on [trackIndex], pushing existing clips right.
  Future<int> insertEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip);

  /// Overwrite: place clip at position, splitting/replacing any overlapping clips.
  Future<int> overwriteEdit(int timelineId, int trackIndex, double atTime, ClipDescriptor clip);

  /// Roll edit: adjust shared edit point between two adjacent clips.
  /// [clipId] is the left clip; delta > 0 extends it (shortens the right neighbor).
  Future<void> rollEdit(int timelineId, int clipId, double deltaSec);

  /// Slip edit: change source in/out without moving the clip on the timeline.
  Future<void> slipEdit(int timelineId, int clipId, double deltaSec);

  /// Slide edit: move clip between neighbors, adjusting neighbor in/out points.
  Future<void> slideEdit(int timelineId, int clipId, double deltaSec);

  /// Rate stretch: change clip speed by adjusting its timeline duration.
  Future<void> rateStretch(int timelineId, int clipId, double newDurationSec);

  /// Duplicate a clip. Returns the new clip ID.
  Future<int> duplicateClip(int timelineId, int clipId);

  /// Get snap points around [timeSec] within [thresholdSec].
  Future<List<double>> getSnapPoints(int timelineId, double timeSec, double thresholdSec);

  /// Reorder tracks. [newOrder] is the list of track indices in the desired order.
  Future<void> reorderTracks(int timelineId, List<int> newOrder);

  // =========================================================================
  // Phase 3: Effect DAG & Registry
  // =========================================================================

  /// List all registered effect definitions by category.
  Future<List<EngineEffectDef>> listEffects({String? category});

  /// Add an effect instance to a clip. Returns the instance ID.
  Future<int> addClipEffect(int timelineId, int clipId, String effectDefId);

  /// Remove an effect instance from a clip.
  Future<void> removeClipEffect(int timelineId, int clipId, int effectInstanceId);

  /// Reorder effects on a clip.
  Future<void> reorderClipEffects(int timelineId, int clipId, List<int> instanceIds);

  /// Set an effect parameter value.
  Future<void> setEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value);

  /// Set effect enabled/disabled.
  Future<void> setEffectEnabled(int timelineId, int clipId, int effectInstanceId, bool enabled);

  /// Set effect mix (dry/wet blend 0.0–1.0).
  Future<void> setEffectMix(int timelineId, int clipId, int effectInstanceId, double mix);

  // =========================================================================
  // Phase 4: Masking & Tracking
  // =========================================================================

  /// Add a mask to a clip. Returns the mask ID.
  Future<int> addClipMask(int timelineId, int clipId, MaskData mask);

  /// Update mask data for an existing mask.
  Future<void> updateClipMask(int timelineId, int clipId, int maskId, MaskData mask);

  /// Remove a mask from a clip.
  Future<void> removeClipMask(int timelineId, int clipId, int maskId);

  /// Start point tracking on a clip from the given frame position.
  Future<int> startTracking(int timelineId, int clipId, double x, double y, double timeSec);

  /// Get tracking data for a tracker.
  Future<List<TrackPoint>> getTrackingData(int timelineId, int trackerId);

  /// Apply stabilization to a clip.
  Future<void> stabilizeClip(int timelineId, int clipId, StabilizationConfig config);

  // =========================================================================
  // Phase 5: Text Layers, Shapes, Audio Effects
  // =========================================================================

  /// Set text content and style on a title clip.
  Future<void> setClipText(int timelineId, int clipId, TextLayerData textData);

  /// Add a shape layer to a clip. Returns the shape ID.
  Future<int> addClipShape(int timelineId, int clipId, ShapeData shape);

  /// Update a shape on a clip.
  Future<void> updateClipShape(int timelineId, int clipId, int shapeId, ShapeData shape);

  /// Remove a shape from a clip.
  Future<void> removeClipShape(int timelineId, int clipId, int shapeId);

  /// Add an audio effect to a clip. Returns the effect instance ID.
  Future<int> addAudioEffect(int timelineId, int clipId, String audioEffectDefId);

  /// Set an audio effect parameter.
  Future<void> setAudioEffectParam(int timelineId, int clipId, int effectInstanceId,
      String paramId, double value);

  /// Remove an audio effect from a clip.
  Future<void> removeAudioEffect(int timelineId, int clipId, int effectInstanceId);

  /// List available audio effect definitions.
  Future<List<AudioEffectDef>> listAudioEffects();

  // =========================================================================
  // Phase 6: AI, Proxy, Multi-Cam
  // =========================================================================

  /// Run AI segmentation (background removal) on a clip.
  Future<int> startAiSegmentation(int timelineId, int clipId, AiSegmentationConfig config);

  /// Poll AI segmentation progress (0.0–1.0, or -1 if not running).
  Future<double> getAiSegmentationProgress(int jobId);

  /// Cancel an AI segmentation job.
  Future<void> cancelAiSegmentation(int jobId);

  /// Enable proxy workflow: generate low-res proxy for editing.
  Future<void> enableProxyMode(int timelineId, ProxyConfig config);

  /// Disable proxy mode (switch back to full-res).
  Future<void> disableProxyMode(int timelineId);

  /// Whether proxy mode is currently active.
  Future<bool> isProxyModeActive(int timelineId);

  /// Create a multi-cam clip from multiple source clips.
  Future<int> createMultiCamClip(int timelineId, int trackIndex, MultiCamConfig config);

  /// Switch the active camera angle in a multi-cam clip.
  Future<void> switchMultiCamAngle(int timelineId, int clipId, int angleIndex, double atTimeSec);

  /// Flatten a multi-cam clip into individual clips on the track.
  Future<void> flattenMultiCam(int timelineId, int clipId);

  // =========================================================================
  // Phase 7: Extended Clip Engine — multi-clip, collision, sync-lock
  // =========================================================================

  /// Move multiple clips simultaneously (group move).
  @override
  Future<void> moveMultipleClips(int timelineId, List<int> clipIds, double deltaTime, int deltaTrack);

  /// Swap two clips on the timeline.
  @override
  Future<void> swapClips(int timelineId, int clipIdA, int clipIdB);

  /// Split all tracks at a given time. Returns count of new clips created.
  @override
  Future<int> splitAllTracks(int timelineId, double splitTimeSeconds);

  /// Lift delete: remove clips in range without closing gap.
  @override
  Future<void> liftDelete(int timelineId, int trackIndex, double rangeStartSeconds, double rangeEndSeconds);

  /// Collision detection: 0=CLEAR, 1=OVERLAP, 2=ADJACENT.
  @override
  Future<int> checkOverlap(int timelineId, int trackIndex, double inTime, double outTime, {int excludeClipId = -1});

  /// Get IDs of clips overlapping a region.
  @override
  Future<List<int>> getOverlappingClips(int timelineId, int trackIndex, double inTime, double outTime);

  /// Set sync-lock on a track.
  @override
  Future<void> setTrackSyncLock(int timelineId, int trackIndex, bool locked);

  /// Set persisted track height.
  @override
  Future<void> setTrackHeight(int timelineId, int trackIndex, double heightPx);

  /// Get persisted track height.
  @override
  Future<double> getTrackHeight(int timelineId, int trackIndex);

  // =========================================================================
  // Texture Bridge (GPU preview pipeline)
  // =========================================================================

  /// Create a native texture bridge for GPU-rendered preview.
  /// Returns a bridge-local texture ID. For CPU-bridge mode, the Dart side
  /// reads pixels back via [getTextureBridgePixels].
  Future<int> createTextureBridge(int width, int height);

  /// Destroy the texture bridge.
  Future<void> destroyTextureBridge();

  /// Render the current timeline frame and push it to the texture bridge.
  /// Returns true if a frame was successfully rendered and pushed.
  Future<bool> renderToTextureBridge(int timelineId);

  /// Resize the texture bridge (e.g. when preview panel resizes).
  Future<void> resizeTextureBridge(int width, int height);

  /// Read back the current front buffer as RGBA pixels.
  /// Returns null if no frame has been rendered yet.
  Future<Uint8List?> getTextureBridgePixels();
}

/// Export configuration passed to the native engine.
class VideoExportConfig {
  final int width;
  final int height;
  final double frameRate;
  final int videoCodec;  // 0=H.264, 1=H.265, 2=VP9
  final int videoBitrateBps;
  final int audioCodec;  // 0=AAC, 1=Opus
  final int audioBitrateKbps;
  final int container;   // 0=MP4, 1=MOV, 2=WebM
  final String outputPath;

  const VideoExportConfig({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.videoCodec,
    required this.videoBitrateBps,
    required this.audioCodec,
    required this.audioBitrateKbps,
    required this.container,
    required this.outputPath,
  });
}

// =========================================================================
// Phase 3: Effect definitions (engine-side registry)
// =========================================================================

class EngineEffectDef {
  final String id;
  final String displayName;
  final String category;
  final List<EngineEffectParamDef> params;
  final bool gpuAccelerated;

  const EngineEffectDef({
    required this.id,
    required this.displayName,
    required this.category,
    required this.params,
    this.gpuAccelerated = false,
  });
}

class EngineEffectParamDef {
  final String id;
  final String displayName;
  final double defaultValue;
  final double minValue;
  final double maxValue;
  final bool keyframeable;

  const EngineEffectParamDef({
    required this.id,
    required this.displayName,
    required this.defaultValue,
    required this.minValue,
    required this.maxValue,
    this.keyframeable = true,
  });
}

// =========================================================================
// Phase 4: Masking & Tracking data models
// =========================================================================

enum VideoMaskType { rectangle, ellipse, bezier, freehand }

class MaskData {
  final VideoMaskType type;
  final List<MaskPoint> points;
  final double feather;
  final double opacity;
  final bool inverted;
  final double expansion;

  const MaskData({
    required this.type,
    required this.points,
    this.feather = 0,
    this.opacity = 1.0,
    this.inverted = false,
    this.expansion = 0,
  });

  Map<String, dynamic> toMap() => {
    'type': type.index,
    'points': points.map((p) => p.toMap()).toList(),
    'feather': feather,
    'opacity': opacity,
    'inverted': inverted,
    'expansion': expansion,
  };

  factory MaskData.fromMap(Map<String, dynamic> m) => MaskData(
    type: VideoMaskType.values[m['type'] as int],
    points: (m['points'] as List).map((p) => MaskPoint.fromMap(p as Map<String, dynamic>)).toList(),
    feather: (m['feather'] as num?)?.toDouble() ?? 0,
    opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
    inverted: m['inverted'] as bool? ?? false,
    expansion: (m['expansion'] as num?)?.toDouble() ?? 0,
  );
}

class MaskPoint {
  final double x;
  final double y;
  final double handleInX;
  final double handleInY;
  final double handleOutX;
  final double handleOutY;

  const MaskPoint({
    required this.x, required this.y,
    this.handleInX = 0, this.handleInY = 0,
    this.handleOutX = 0, this.handleOutY = 0,
  });

  Map<String, dynamic> toMap() => {
    'x': x, 'y': y,
    'hix': handleInX, 'hiy': handleInY,
    'hox': handleOutX, 'hoy': handleOutY,
  };

  factory MaskPoint.fromMap(Map<String, dynamic> m) => MaskPoint(
    x: (m['x'] as num).toDouble(), y: (m['y'] as num).toDouble(),
    handleInX: (m['hix'] as num?)?.toDouble() ?? 0,
    handleInY: (m['hiy'] as num?)?.toDouble() ?? 0,
    handleOutX: (m['hox'] as num?)?.toDouble() ?? 0,
    handleOutY: (m['hoy'] as num?)?.toDouble() ?? 0,
  );
}

class TrackPoint {
  final double time;
  final double x;
  final double y;
  final double confidence;

  const TrackPoint({required this.time, required this.x, required this.y, this.confidence = 1.0});
}

enum StabilizationMethod { translation, translationRotation, perspective }

class StabilizationConfig {
  final StabilizationMethod method;
  final double smoothness;
  final bool cropToStable;

  const StabilizationConfig({
    this.method = StabilizationMethod.translationRotation,
    this.smoothness = 0.5,
    this.cropToStable = true,
  });
}

// =========================================================================
// Phase 5: Text, Shape, Audio effect data models
// =========================================================================

class TextLayerData {
  final String text;
  final String fontFamily;
  final String fontStyle;
  final double fontSize;
  final int fillColor;
  final bool fillEnabled;
  final int strokeColor;
  final double strokeWidth;
  final bool strokeEnabled;
  final TextAlignment alignment;
  final double tracking;
  final double leading;
  final double positionX;
  final double positionY;
  final double rotation;
  final double scaleX;
  final double scaleY;

  const TextLayerData({
    required this.text,
    this.fontFamily = 'Inter',
    this.fontStyle = 'Regular',
    this.fontSize = 48,
    this.fillColor = 0xFFFFFFFF,
    this.fillEnabled = true,
    this.strokeColor = 0xFF000000,
    this.strokeWidth = 0,
    this.strokeEnabled = false,
    this.alignment = TextAlignment.center,
    this.tracking = 0,
    this.leading = 0,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.rotation = 0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
  });

  Map<String, dynamic> toMap() => {
    'text': text, 'fontFamily': fontFamily, 'fontStyle': fontStyle,
    'fontSize': fontSize, 'fillColor': fillColor, 'fillEnabled': fillEnabled,
    'strokeColor': strokeColor, 'strokeWidth': strokeWidth, 'strokeEnabled': strokeEnabled,
    'alignment': alignment.index, 'tracking': tracking, 'leading': leading,
    'positionX': positionX, 'positionY': positionY, 'rotation': rotation,
    'scaleX': scaleX, 'scaleY': scaleY,
  };

  factory TextLayerData.fromMap(Map<String, dynamic> m) => TextLayerData(
    text: m['text'] as String,
    fontFamily: m['fontFamily'] as String? ?? 'Inter',
    fontStyle: m['fontStyle'] as String? ?? 'Regular',
    fontSize: (m['fontSize'] as num?)?.toDouble() ?? 48,
    fillColor: m['fillColor'] as int? ?? 0xFFFFFFFF,
    fillEnabled: m['fillEnabled'] as bool? ?? true,
    strokeColor: m['strokeColor'] as int? ?? 0xFF000000,
    strokeWidth: (m['strokeWidth'] as num?)?.toDouble() ?? 0,
    strokeEnabled: m['strokeEnabled'] as bool? ?? false,
    alignment: TextAlignment.values[(m['alignment'] as int?) ?? 1],
    tracking: (m['tracking'] as num?)?.toDouble() ?? 0,
    leading: (m['leading'] as num?)?.toDouble() ?? 0,
    positionX: (m['positionX'] as num?)?.toDouble() ?? 0.5,
    positionY: (m['positionY'] as num?)?.toDouble() ?? 0.5,
    rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
    scaleX: (m['scaleX'] as num?)?.toDouble() ?? 1.0,
    scaleY: (m['scaleY'] as num?)?.toDouble() ?? 1.0,
  );
}

enum ShapeType { rectangle, ellipse, polygon, star, line, arrow, path }

class ShapeData {
  final ShapeType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int fillColor;
  final bool fillEnabled;
  final int strokeColor;
  final double strokeWidth;
  final bool strokeEnabled;
  final double cornerRadius;
  final int sides;
  final double innerRadius;
  final List<MaskPoint> pathPoints;

  const ShapeData({
    required this.type,
    this.x = 0.5, this.y = 0.5,
    this.width = 0.3, this.height = 0.3,
    this.rotation = 0,
    this.fillColor = 0xFFFFFFFF,
    this.fillEnabled = true,
    this.strokeColor = 0xFF000000,
    this.strokeWidth = 2,
    this.strokeEnabled = true,
    this.cornerRadius = 0,
    this.sides = 6,
    this.innerRadius = 0.5,
    this.pathPoints = const [],
  });

  Map<String, dynamic> toMap() => {
    'type': type.index, 'x': x, 'y': y, 'width': width, 'height': height,
    'rotation': rotation, 'fillColor': fillColor, 'fillEnabled': fillEnabled,
    'strokeColor': strokeColor, 'strokeWidth': strokeWidth, 'strokeEnabled': strokeEnabled,
    'cornerRadius': cornerRadius, 'sides': sides, 'innerRadius': innerRadius,
    'pathPoints': pathPoints.map((p) => p.toMap()).toList(),
  };

  factory ShapeData.fromMap(Map<String, dynamic> m) => ShapeData(
    type: ShapeType.values[m['type'] as int],
    x: (m['x'] as num?)?.toDouble() ?? 0.5,
    y: (m['y'] as num?)?.toDouble() ?? 0.5,
    width: (m['width'] as num?)?.toDouble() ?? 0.3,
    height: (m['height'] as num?)?.toDouble() ?? 0.3,
    rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
    fillColor: m['fillColor'] as int? ?? 0xFFFFFFFF,
    fillEnabled: m['fillEnabled'] as bool? ?? true,
    strokeColor: m['strokeColor'] as int? ?? 0xFF000000,
    strokeWidth: (m['strokeWidth'] as num?)?.toDouble() ?? 2,
    strokeEnabled: m['strokeEnabled'] as bool? ?? true,
    cornerRadius: (m['cornerRadius'] as num?)?.toDouble() ?? 0,
    sides: m['sides'] as int? ?? 6,
    innerRadius: (m['innerRadius'] as num?)?.toDouble() ?? 0.5,
    pathPoints: (m['pathPoints'] as List?)?.map((p) => MaskPoint.fromMap(p as Map<String, dynamic>)).toList() ?? const [],
  );
}

class AudioEffectDef {
  final String id;
  final String displayName;
  final String category;
  final List<EngineEffectParamDef> params;

  const AudioEffectDef({
    required this.id,
    required this.displayName,
    required this.category,
    required this.params,
  });
}

// =========================================================================
// Phase 6: AI, Proxy, Multi-Cam data models
// =========================================================================

enum AiSegmentationType { background, person, object, sky }

class AiSegmentationConfig {
  final AiSegmentationType type;
  final double edgeFeather;
  final bool refineEdges;

  const AiSegmentationConfig({
    this.type = AiSegmentationType.background,
    this.edgeFeather = 2.0,
    this.refineEdges = true,
  });
}

enum ProxyResolution { quarter, half, threeQuarter }

class ProxyConfig {
  final ProxyResolution resolution;
  final int videoCodec;
  final int bitrateBps;

  const ProxyConfig({
    this.resolution = ProxyResolution.quarter,
    this.videoCodec = 0,
    this.bitrateBps = 2000000,
  });
}

class CameraAngle {
  final String name;
  final String sourcePath;
  final double syncOffset;

  const CameraAngle({required this.name, required this.sourcePath, this.syncOffset = 0});
}

class MultiCamConfig {
  final String name;
  final List<CameraAngle> angles;
  final double durationSec;

  const MultiCamConfig({
    required this.name,
    required this.angles,
    required this.durationSec,
  });
}

// ---------------------------------------------------------------------------
// Decoder Pool & Thumbnail Generator
// ---------------------------------------------------------------------------

/// Priority for decoder acquire requests.
enum DecoderPriority { high, medium, low }

/// Thumbnail job status reported by the native generator.
enum ThumbnailJobStatus { queued, inProgress, completed, failed, cancelled }

/// A single thumbnail result from the native generator.
class NativeThumbnailResult {
  final Uint8List jpegData;
  final int width;
  final int height;
  final double timestamp;

  const NativeThumbnailResult({
    required this.jpegData,
    required this.width,
    required this.height,
    required this.timestamp,
  });
}

/// Request for native thumbnail extraction.
class NativeThumbnailRequest {
  final String sourcePath;
  final double sourceDuration;
  final int count;
  final int thumbWidth;
  final int thumbHeight;
  final DecoderPriority priority;

  const NativeThumbnailRequest({
    required this.sourcePath,
    required this.sourceDuration,
    required this.count,
    this.thumbWidth = 160,
    this.thumbHeight = 90,
    this.priority = DecoderPriority.medium,
  });
}
