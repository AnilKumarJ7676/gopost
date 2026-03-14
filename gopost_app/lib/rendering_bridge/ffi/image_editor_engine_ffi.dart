import 'dart:ffi';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/ffi/gopost_engine_ffi.dart';
import 'package:gopost_app/rendering_bridge/ffi/native_bindings.dart';
import 'load_gopost_native_stub.dart'
    if (dart.library.io) 'load_gopost_native_io.dart' as load_lib;

// C enum values from canvas.h, export.h, image_codec.h
const int _colorSpaceSrgb = 0;
const int _colorSpaceDisplayP3 = 1;
const int _colorSpaceAdobeRgb = 2;
const int _blendNormal = 0;
const int _formatJpeg = 1;
const int _formatPng = 2;
const int _formatWebp = 3;
const int _exportResOriginal = 0;
const int _exportRes4k = 1;
const int _exportRes1080p = 2;
const int _exportRes720p = 3;
const int _exportResInstagramSquare = 4;
const int _exportResInstagramStory = 5;
const int _exportResCustom = 6;

/// Set before exportToFile and cleared after; used by native progress callback.
void Function(double)? _globalExportProgress;

int _exportProgressCallback(double progress, Pointer<Void> userData) {
  _globalExportProgress?.call(progress);
  return 0;
}

/// FFI-backed [ImageEditorEngine] using the native gopost engine for canvas,
/// layers, render, and export. Other interfaces (effects, text, mask, project,
/// decoder/encoder, GPU texture) are stubbed.
class GopostImageEditorEngineFfi implements ImageEditorEngine {
  GopostImageEditorEngineFfi(this._lib);

  final DynamicLibrary _lib;
  NativeBindings? _bindings;
  Pointer<Void>? _enginePtr;
  bool _initialized = false;
  int _nextCanvasId = 1;
  final Map<int, Pointer<Void>> _canvases = {};

  /// Exposed so the video timeline engine can share the same native engine.
  DynamicLibrary get library => _lib;
  Pointer<Void>? get enginePointer => _enginePtr;

  void _ensureInitialized() {
    if (!_initialized || _bindings == null || _enginePtr == null) {
      throw StateError('GopostImageEditorEngineFfi not initialized');
    }
  }

  Pointer<Void>? _getCanvas(int canvasId) => _canvases[canvasId];

  int _toColorSpace(CanvasColorSpace cs) {
    return switch (cs) {
      CanvasColorSpace.srgb => _colorSpaceSrgb,
      CanvasColorSpace.displayP3 => _colorSpaceDisplayP3,
      CanvasColorSpace.adobeRgb => _colorSpaceAdobeRgb,
    };
  }

  LayerType _fromLayerType(int t) {
    return switch (t) {
      0 => LayerType.image,
      1 => LayerType.solidColor,
      2 => LayerType.text,
      3 => LayerType.shape,
      4 => LayerType.group,
      5 => LayerType.adjustment,
      6 => LayerType.gradient,
      7 => LayerType.sticker,
      _ => LayerType.image,
    };
  }

  int _toBlendMode(BlendMode m) {
    return switch (m) {
      BlendMode.normal => _blendNormal,
      BlendMode.multiply => 1,
      BlendMode.screen => 2,
      BlendMode.overlay => 3,
    };
  }

  BlendMode _fromBlendMode(int m) {
    return switch (m) {
      0 => BlendMode.normal,
      1 => BlendMode.multiply,
      2 => BlendMode.screen,
      3 => BlendMode.overlay,
      _ => BlendMode.normal,
    };
  }

  int _toExportFormat(ExportFormat f) {
    return switch (f) {
      ExportFormat.jpeg => _formatJpeg,
      ExportFormat.png => _formatPng,
      ExportFormat.webp => _formatWebp,
    };
  }

  int _toExportResolution(ExportResolution r) {
    return switch (r) {
      ExportResolution.original => _exportResOriginal,
      ExportResolution.res4k => _exportRes4k,
      ExportResolution.res1080p => _exportRes1080p,
      ExportResolution.res720p => _exportRes720p,
      ExportResolution.instagramSquare => _exportResInstagramSquare,
      ExportResolution.instagramStory => _exportResInstagramStory,
      ExportResolution.custom => _exportResCustom,
    };
  }

  void _checkErr(int err) {
    if (err != 0) {
      final msg = _bindings!.gopost_error_string(err).cast<Utf8>().toDartString();
      throw EngineException(msg);
    }
  }

  /// Initialize the engine. Call once before using canvas/export.
  Future<void> initialize() async {
    if (_initialized) return;
    _bindings = NativeBindings(_lib);

    final configPtr = calloc<Uint8>(32);
    final config = configPtr.cast<_GopostEngineConfig>();
    config.ref.threadCount = 4;
    config.ref.framePoolSizeMb = 128;
    config.ref.enableGpu = 0;
    config.ref.logLevel = 2;

    final enginePtrPtr = calloc<Pointer<Void>>();
    final result = _bindings!.gopost_engine_create(enginePtrPtr, config.cast());
    calloc.free(configPtr);

    if (result != 0) {
      calloc.free(enginePtrPtr);
      throw EngineException(_bindings!.gopost_error_string(result).cast<Utf8>().toDartString());
    }

    _enginePtr = enginePtrPtr.value;
    calloc.free(enginePtrPtr);
    _initialized = true;
  }

  /// Dispose engine and all canvases.
  Future<void> dispose() async {
    if (!_initialized) return;
    for (final canvasPtr in _canvases.values) {
      _bindings!.gopost_canvas_destroy(canvasPtr);
    }
    _canvases.clear();
    _bindings!.gopost_engine_destroy(_enginePtr!);
    _enginePtr = null;
    _initialized = false;
  }

  // --- CanvasManager ---

  @override
  Future<int> createCanvas(CanvasConfig config) async {
    if (!_initialized) await initialize();
    final configPtr = calloc<NativeGopostCanvasConfig>();
    configPtr.ref.width = config.width;
    configPtr.ref.height = config.height;
    configPtr.ref.dpi = config.dpi;
    configPtr.ref.colorSpace = _toColorSpace(config.colorSpace);
    configPtr.ref.bgR = config.bgR;
    configPtr.ref.bgG = config.bgG;
    configPtr.ref.bgB = config.bgB;
    configPtr.ref.bgA = config.bgA;
    configPtr.ref.transparentBg = config.transparentBackground ? 1 : 0;

    final canvasPtrPtr = calloc<Pointer<Void>>();
    final err = _bindings!.gopost_canvas_create(_enginePtr!, configPtr, canvasPtrPtr);
    calloc.free(configPtr);

    if (err != 0) {
      calloc.free(canvasPtrPtr);
      _checkErr(err);
    }

    final canvasPtr = canvasPtrPtr.value;
    calloc.free(canvasPtrPtr);
    final id = _nextCanvasId++;
    _canvases[id] = canvasPtr;
    return id;
  }

  @override
  Future<void> destroyCanvas(int canvasId) async {
    _ensureInitialized();
    final canvasPtr = _canvases.remove(canvasId);
    if (canvasPtr != null) _bindings!.gopost_canvas_destroy(canvasPtr);
  }

  @override
  Future<({int width, int height, double dpi})> getCanvasSize(int canvasId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');

    final w = calloc<Int32>();
    final h = calloc<Int32>();
    final dpi = calloc<Float>();
    _checkErr(_bindings!.gopost_canvas_get_size(canvasPtr, w, h, dpi));
    final result = (width: w.value, height: h.value, dpi: dpi.value);
    calloc.free(w);
    calloc.free(h);
    calloc.free(dpi);
    return result;
  }

  @override
  Future<void> resizeCanvas(int canvasId, int width, int height) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_canvas_resize(canvasPtr, width, height));
  }

  // --- LayerManager ---

  @override
  Future<int> addImageLayer(
      int canvasId, Uint8List rgbaPixels, int width, int height,
      {int index = -1}) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');

    final pixelsPtr = calloc<Uint8>(rgbaPixels.length);
    pixelsPtr.asTypedList(rgbaPixels.length).setAll(0, rgbaPixels);
    final outId = calloc<Int32>();
    final err = _bindings!.gopost_canvas_add_image_layer(
        canvasPtr, pixelsPtr, width, height, index, outId);
    calloc.free(pixelsPtr);

    if (err != 0) {
      calloc.free(outId);
      _checkErr(err);
    }
    final layerId = outId.value;
    calloc.free(outId);
    return layerId;
  }

  @override
  Future<int> addSolidLayer(int canvasId, double r, double g, double b,
      double a, int width, int height,
      {int index = -1}) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');

    final outId = calloc<Int32>();
    _checkErr(_bindings!.gopost_canvas_add_solid_layer(
        canvasPtr, r, g, b, a, width, height, index, outId));
    final layerId = outId.value;
    calloc.free(outId);
    return layerId;
  }

  @override
  Future<int> addGroupLayer(int canvasId, String name, {int index = -1}) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');

    final namePtr = name.toNativeUtf8();
    final outId = calloc<Int32>();
    _checkErr(_bindings!.gopost_canvas_add_group_layer(
        canvasPtr, namePtr, index, outId));
    malloc.free(namePtr);
    final layerId = outId.value;
    calloc.free(outId);
    return layerId;
  }

  @override
  Future<void> removeLayer(int canvasId, int layerId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_canvas_remove_layer(canvasPtr, layerId));
  }

  @override
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_canvas_reorder_layer(canvasPtr, layerId, newIndex));
  }

  @override
  Future<int> duplicateLayer(int canvasId, int layerId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    final outId = calloc<Int32>();
    _checkErr(_bindings!.gopost_canvas_duplicate_layer(canvasPtr, layerId, outId));
    final newId = outId.value;
    calloc.free(outId);
    return newId;
  }

  @override
  Future<int> getLayerCount(int canvasId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    final out = calloc<Int32>();
    _checkErr(_bindings!.gopost_canvas_get_layer_count(canvasPtr, out));
    final count = out.value;
    calloc.free(out);
    return count;
  }

  @override
  Future<LayerInfo> getLayerInfo(int canvasId, int layerId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    final infoPtr = calloc<NativeGopostLayerInfo>();
    _checkErr(_bindings!.gopost_canvas_get_layer_info(canvasPtr, layerId, infoPtr));
    final ref = infoPtr.ref;
    final arr = ref.name;
    final name = String.fromCharCodes(
        [for (var i = 0; i < 128; i++) if (arr[i] != 0) arr[i]]);
    final info = LayerInfo(
      id: ref.id,
      type: _fromLayerType(ref.type),
      name: name,
      opacity: ref.opacity,
      blendMode: _fromBlendMode(ref.blendMode),
      visible: ref.visible != 0,
      locked: ref.locked != 0,
      tx: ref.tx,
      ty: ref.ty,
      sx: ref.sx,
      sy: ref.sy,
      rotation: ref.rotation,
      contentWidth: ref.contentW,
      contentHeight: ref.contentH,
    );
    calloc.free(infoPtr);
    return info;
  }

  @override
  Future<List<int>> getLayerIds(int canvasId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    final count = await getLayerCount(canvasId);
    if (count == 0) return [];
    final idsPtr = calloc<Int32>(count);
    _checkErr(_bindings!.gopost_canvas_get_layer_ids(canvasPtr, idsPtr, count));
    final list = List<int>.generate(count, (i) => idsPtr[i]);
    calloc.free(idsPtr);
    return list;
  }

  // --- LayerPropertyEditor ---

  @override
  Future<void> setLayerVisible(int canvasId, int layerId, bool visible) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_layer_set_visible(canvasPtr, layerId, visible ? 1 : 0));
  }

  @override
  Future<void> setLayerLocked(int canvasId, int layerId, bool locked) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_layer_set_locked(canvasPtr, layerId, locked ? 1 : 0));
  }

  @override
  Future<void> setLayerOpacity(int canvasId, int layerId, double opacity) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_layer_set_opacity(canvasPtr, layerId, opacity));
  }

  @override
  Future<void> setLayerBlendMode(
      int canvasId, int layerId, BlendMode blendMode) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_layer_set_blend_mode(
        canvasPtr, layerId, _toBlendMode(blendMode)));
  }

  @override
  Future<void> setLayerName(int canvasId, int layerId, String name) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    final namePtr = name.toNativeUtf8();
    _checkErr(_bindings!.gopost_layer_set_name(canvasPtr, layerId, namePtr));
    malloc.free(namePtr);
  }

  @override
  Future<void> setLayerTransform(int canvasId, int layerId,
      {double tx = 0,
      double ty = 0,
      double sx = 1,
      double sy = 1,
      double rotation = 0}) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');
    _checkErr(_bindings!.gopost_layer_set_transform(
        canvasPtr, layerId, tx, ty, sx, sy, rotation));
  }

  // --- CanvasRenderer ---

  @override
  Future<DecodedImage> renderCanvas(int canvasId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');

    final framePtrPtr = calloc<Pointer<Void>>();
    _checkErr(_bindings!.gopost_canvas_render(canvasPtr, framePtrPtr));
    final framePtr = framePtrPtr.value;
    calloc.free(framePtrPtr);

    if (framePtr == nullptr) throw const EngineException('Render returned null frame');

    final frame = framePtr.cast<NativeGopostFrame>().ref;
    final w = frame.width;
    final h = frame.height;
    final data = frame.data;
    final stride = frame.stride;
    final size = h * stride;
    final pixels = Uint8List(size);
    if (data != nullptr && size > 0) {
      pixels.setRange(0, size, data.asTypedList(size));
    }
    final enginePtr = _bindings!.gopost_canvas_get_engine(canvasPtr);
    if (enginePtr != nullptr) {
      _bindings!.gopost_frame_release(enginePtr, framePtr);
    } else {
      _bindings!.gopost_render_frame_free(framePtr);
    }

    return DecodedImage(width: w, height: h, pixels: pixels);
  }

  @override
  Future<void> invalidateCanvas(int canvasId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr != null) _bindings!.gopost_canvas_invalidate(canvasPtr);
  }

  @override
  Future<void> invalidateLayer(int canvasId, int layerId) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr != null) {
      _bindings!.gopost_canvas_invalidate_layer(canvasPtr, layerId);
    }
  }

  // --- ImageExporter ---

  @override
  Future<ExportResult> exportToFile(int canvasId, ExportConfig config,
      String outputPath,
      {void Function(double progress)? onProgress}) async {
    if (!_initialized) await initialize();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) throw EngineException('Canvas $canvasId not found');

    final configPtr = calloc<NativeGopostExportConfig>();
    configPtr.ref.format = _toExportFormat(config.format);
    configPtr.ref.quality = config.quality;
    configPtr.ref.resolution = _toExportResolution(config.resolution);
    configPtr.ref.customWidth = config.customWidth;
    configPtr.ref.customHeight = config.customHeight;
    configPtr.ref.embedColorProfile = 0;
    configPtr.ref.dpi = config.dpi;

    try {
      _globalExportProgress = onProgress;
      final pathPtr = outputPath.toNativeUtf8();
      final progressCb = Pointer.fromFunction<
          Int32 Function(Float progress, Pointer<Void> userData)>(
        _exportProgressCallback,
        -1,
      );
      final err = _bindings!.gopost_export_to_file(
          canvasPtr, configPtr, pathPtr, progressCb.cast<Void>(), nullptr);
      malloc.free(pathPtr);
      if (err != 0) _checkErr(err);
    } finally {
      _globalExportProgress = null;
      calloc.free(configPtr);
    }

    final size = await estimateFileSize(canvasId, config);
    final sizeResult = await getCanvasSize(canvasId);
    return ExportResult(
      filePath: outputPath,
      fileSize: size,
      width: sizeResult.width,
      height: sizeResult.height,
    );
  }

  @override
  Future<int> estimateFileSize(int canvasId, ExportConfig config) async {
    if (!_initialized) await initialize();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) return 0;

    final configPtr = calloc<NativeGopostExportConfig>();
    configPtr.ref.format = _toExportFormat(config.format);
    configPtr.ref.quality = config.quality;
    configPtr.ref.resolution = _toExportResolution(config.resolution);
    configPtr.ref.customWidth = config.customWidth;
    configPtr.ref.customHeight = config.customHeight;
    configPtr.ref.embedColorProfile = 0;
    configPtr.ref.dpi = config.dpi;

    final outSize = calloc<Uint64>();
    final err = _bindings!.gopost_export_estimate_size(canvasPtr, configPtr, outSize);
    calloc.free(configPtr);
    if (err != 0) {
      calloc.free(outSize);
      return 0;
    }
    final size = outSize.value;
    calloc.free(outSize);
    return size;
  }

  // --- Stubs (GpuTextureOutput, ImageDecoder, ImageEncoder, effects, text, mask, project) ---

  @override
  Future<({int textureHandle, int width, int height})> renderToGpuTexture(
      int canvasId) async {
    final size = await getCanvasSize(canvasId);
    return (textureHandle: 0, width: size.width, height: size.height);
  }

  @override
  Future<void> setViewport(int canvasId, ViewportState viewport) async {}

  @override
  Future<ViewportState> getViewport(int canvasId) async =>
      const ViewportState(panX: 0, panY: 0, zoom: 1.0, rotation: 0);

  @override
  Future<ImageInfo> probeImage(Uint8List data) async {
    _ensureInitialized();
    final dataPtr = calloc<Uint8>(data.length);
    dataPtr.asTypedList(data.length).setAll(0, data);
    final info = calloc<NativeGopostImageInfo>();

    final err = _bindings!.gopost_image_probe(dataPtr, data.length, info);
    calloc.free(dataPtr);

    if (err != 0) {
      calloc.free(info);
      _checkErr(err);
    }

    const formatMap = {
      1: ImageFormat.jpeg,
      2: ImageFormat.png,
      3: ImageFormat.webp,
      4: ImageFormat.heic,
      5: ImageFormat.bmp,
      6: ImageFormat.gif,
      7: ImageFormat.tiff,
      8: ImageFormat.tga,
    };

    final result = ImageInfo(
      width: info.ref.width,
      height: info.ref.height,
      channels: info.ref.channels,
      format: formatMap[info.ref.format] ?? ImageFormat.jpeg,
      hasAlpha: info.ref.hasAlpha != 0,
    );
    calloc.free(info);
    return result;
  }

  @override
  Future<DecodedImage> decodeImage(Uint8List data) async {
    return _decodeToRgba(data);
  }

  @override
  Future<DecodedImage> decodeImageResized(
      Uint8List data, int maxWidth, int maxHeight) async {
    return _decodeToRgba(data, maxWidth: maxWidth, maxHeight: maxHeight);
  }

  @override
  Future<DecodedImage> decodeImageFile(String path) async {
    final file = io.File(path);
    if (!await file.exists()) {
      throw EngineException('File not found: $path');
    }
    final bytes = await file.readAsBytes();
    return _decodeToRgba(bytes);
  }

  @override
  Future<Uint8List> encodeJpeg(DecodedImage image, {int quality = 85}) async {
    _ensureInitialized();
    final frame = _allocFrame(image);
    final opts = calloc<NativeGopostJpegOpts>();
    opts.ref.quality = quality;
    opts.ref.progressive = 0;
    final outPtr = calloc<Pointer<Uint8>>();
    final outSize = calloc<Uint64>();

    final err = _bindings!.gopost_image_encode_jpeg(frame, opts, outPtr, outSize);
    calloc.free(opts);

    if (err != 0) {
      _freeFrame(frame);
      calloc.free(outPtr);
      calloc.free(outSize);
      _checkErr(err);
    }

    final result = Uint8List.fromList(
        outPtr.value.asTypedList(outSize.value));
    _bindings!.gopost_image_encode_free(outPtr.value);
    _freeFrame(frame);
    calloc.free(outPtr);
    calloc.free(outSize);
    return result;
  }

  @override
  Future<Uint8List> encodePng(DecodedImage image) async {
    _ensureInitialized();
    final frame = _allocFrame(image);
    final opts = calloc<NativeGopostPngOpts>();
    opts.ref.compressionLevel = 6;
    final outPtr = calloc<Pointer<Uint8>>();
    final outSize = calloc<Uint64>();

    final err = _bindings!.gopost_image_encode_png(frame, opts, outPtr, outSize);
    calloc.free(opts);

    if (err != 0) {
      _freeFrame(frame);
      calloc.free(outPtr);
      calloc.free(outSize);
      _checkErr(err);
    }

    final result = Uint8List.fromList(
        outPtr.value.asTypedList(outSize.value));
    _bindings!.gopost_image_encode_free(outPtr.value);
    _freeFrame(frame);
    calloc.free(outPtr);
    calloc.free(outSize);
    return result;
  }

  @override
  Future<Uint8List> encodeWebp(DecodedImage image,
      {int quality = 80, bool lossless = false}) async {
    _ensureInitialized();
    final frame = _allocFrame(image);
    final opts = calloc<NativeGopostWebpOpts>();
    opts.ref.quality = quality;
    opts.ref.lossless = lossless ? 1 : 0;
    final outPtr = calloc<Pointer<Uint8>>();
    final outSize = calloc<Uint64>();

    final err = _bindings!.gopost_image_encode_webp(frame, opts, outPtr, outSize);
    calloc.free(opts);

    if (err != 0) {
      _freeFrame(frame);
      calloc.free(outPtr);
      calloc.free(outSize);
      _checkErr(err);
    }

    final result = Uint8List.fromList(
        outPtr.value.asTypedList(outSize.value));
    _bindings!.gopost_image_encode_free(outPtr.value);
    _freeFrame(frame);
    calloc.free(outPtr);
    calloc.free(outSize);
    return result;
  }

  @override
  Future<void> encodeToFile(DecodedImage image, String path, ImageFormat format,
      {int quality = 85}) async {
    _ensureInitialized();
    final frame = _allocFrame(image);
    final pathPtr = path.toNativeUtf8();
    const formatMap = {
      ImageFormat.jpeg: 1,
      ImageFormat.png: 2,
      ImageFormat.webp: 3,
      ImageFormat.heic: 4,
      ImageFormat.bmp: 5,
    };

    final err = _bindings!.gopost_image_encode_to_file(
        frame, pathPtr, formatMap[format] ?? 1, quality);
    calloc.free(pathPtr);
    _freeFrame(frame);
    _checkErr(err);
  }

  /// Allocates a native GopostFrame from decoded RGBA pixels.
  static Pointer<Void> _allocFrame(DecodedImage image) {
    final framePtr = calloc<NativeGopostFrame>();
    framePtr.ref.width = image.width;
    framePtr.ref.height = image.height;
    framePtr.ref.format = 0; // GOPOST_PIXEL_FORMAT_RGBA8
    framePtr.ref.dataSize = image.pixels.length;
    framePtr.ref.stride = image.width * 4;

    final dataPtr = calloc<Uint8>(image.pixels.length);
    dataPtr.asTypedList(image.pixels.length).setAll(0, image.pixels);
    framePtr.ref.data = dataPtr;

    return framePtr.cast<Void>();
  }

  static void _freeFrame(Pointer<Void> framePtr) {
    final frame = framePtr.cast<NativeGopostFrame>();
    if (frame.ref.data != nullptr) {
      calloc.free(frame.ref.data);
    }
    calloc.free(frame);
  }

  static Future<DecodedImage> _decodeToRgba(Uint8List data,
      {int? maxWidth, int? maxHeight}) async {
    final codec = await ui.instantiateImageCodec(
      data,
      targetWidth: maxWidth,
      targetHeight: maxHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    codec.dispose();

    if (byteData == null) {
      throw EngineException('Failed to decode image to RGBA pixels');
    }

    return DecodedImage(
      width: image.width,
      height: image.height,
      pixels: byteData.buffer.asUint8List(),
    );
  }

  @override
  Future<void> initEffects() async {
    _ensureInitialized();
    _bindings!.gopost_effects_init(_enginePtr!);
  }

  @override
  Future<void> shutdownEffects() async {
    _ensureInitialized();
    _bindings!.gopost_effects_shutdown(_enginePtr!);
  }

  @override
  Future<List<EffectDef>> getAllEffects() async {
    _ensureInitialized();
    final pCount = calloc<Int32>();
    try {
      _bindings!.gopost_effects_get_count(_enginePtr!, pCount);
      final count = pCount.value;
      final defs = <EffectDef>[];
      final pDef = calloc<NativeGopostEffectDef>();
      try {
        for (int i = 0; i < count; i++) {
          _bindings!.gopost_effects_get_def(_enginePtr!, i, pDef);
          defs.add(_parseEffectDef(pDef.ref));
        }
      } finally {
        calloc.free(pDef);
      }
      return defs;
    } finally {
      calloc.free(pCount);
    }
  }

  @override
  Future<EffectDef?> findEffect(String effectId) async {
    _ensureInitialized();
    final pId = effectId.toNativeUtf8();
    final pDef = calloc<NativeGopostEffectDef>();
    try {
      final rc = _bindings!.gopost_effects_find(_enginePtr!, pId, pDef);
      if (rc != 0) return null;
      return _parseEffectDef(pDef.ref);
    } finally {
      calloc.free(pId);
      calloc.free(pDef);
    }
  }

  @override
  Future<List<EffectDef>> getEffectsByCategory(EffectCategory category) async {
    _ensureInitialized();
    final pDefs = calloc<NativeGopostEffectDef>(64);
    final pCount = calloc<Int32>();
    try {
      _bindings!.gopost_effects_list_category(
          _enginePtr!, category.index, pDefs, 64, pCount);
      final count = pCount.value;
      final list = <EffectDef>[];
      for (int i = 0; i < count; i++) {
        list.add(_parseEffectDef(pDefs[i]));
      }
      return list;
    } finally {
      calloc.free(pDefs);
      calloc.free(pCount);
    }
  }

  @override
  Future<int> addEffectToLayer(
      int canvasId, int layerId, String effectId) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) throw StateError('Canvas $canvasId not found');
    final pId = effectId.toNativeUtf8();
    final pOut = calloc<Int32>();
    try {
      _bindings!.gopost_layer_add_effect(canvas, layerId, pId, pOut);
      return pOut.value;
    } finally {
      calloc.free(pId);
      calloc.free(pOut);
    }
  }

  @override
  Future<void> removeEffectFromLayer(
      int canvasId, int layerId, int instanceId) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) return;
    _bindings!.gopost_layer_remove_effect(canvas, layerId, instanceId);
  }

  @override
  Future<List<EffectInstance>> getLayerEffects(
      int canvasId, int layerId) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) return [];
    final pCount = calloc<Int32>();
    try {
      _bindings!.gopost_layer_get_effect_count(canvas, layerId, pCount);
      final count = pCount.value;
      final list = <EffectInstance>[];
      final pInst = calloc<NativeGopostEffectInstance>();
      try {
        for (int i = 0; i < count; i++) {
          _bindings!.gopost_layer_get_effect(canvas, layerId, i, pInst);
          list.add(_parseEffectInstance(pInst.ref));
        }
      } finally {
        calloc.free(pInst);
      }
      return list;
    } finally {
      calloc.free(pCount);
    }
  }

  @override
  Future<void> setEffectEnabled(
      int canvasId, int layerId, int instanceId, bool enabled) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) return;
    _bindings!.gopost_effect_set_enabled(
        canvas, layerId, instanceId, enabled ? 1 : 0);
  }

  @override
  Future<void> setEffectMix(
      int canvasId, int layerId, int instanceId, double mix) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) return;
    _bindings!.gopost_effect_set_mix(canvas, layerId, instanceId, mix);
  }

  @override
  Future<void> setEffectParam(int canvasId, int layerId, int instanceId,
      String paramId, double value) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) return;
    final pId = paramId.toNativeUtf8();
    try {
      _bindings!.gopost_effect_set_param(
          canvas, layerId, instanceId, pId, value);
    } finally {
      calloc.free(pId);
    }
  }

  @override
  Future<double> getEffectParam(
      int canvasId, int layerId, int instanceId, String paramId) async {
    _ensureInitialized();
    final canvas = _getCanvas(canvasId);
    if (canvas == null) return 0;
    final pId = paramId.toNativeUtf8();
    final pVal = calloc<Float>();
    try {
      _bindings!.gopost_effect_get_param(
          canvas, layerId, instanceId, pId, pVal);
      return pVal.value;
    } finally {
      calloc.free(pId);
      calloc.free(pVal);
    }
  }

  @override
  Future<List<PresetFilterInfo>> getPresetFilters() async {
    _ensureInitialized();
    final pCount = calloc<Int32>();
    try {
      _bindings!.gopost_preset_get_count(_enginePtr!, pCount);
      final count = pCount.value;
      final list = <PresetFilterInfo>[];
      for (int i = 0; i < count; i++) {
        final pName = calloc<Uint8>(128).cast<Utf8>();
        final pCat = calloc<Uint8>(64).cast<Utf8>();
        try {
          _bindings!.gopost_preset_get_info(
              _enginePtr!, i, pName, 128, pCat, 64);
          list.add(PresetFilterInfo(
            index: i,
            name: pName.toDartString(),
            category: pCat.toDartString(),
          ));
        } finally {
          calloc.free(pName);
          calloc.free(pCat);
        }
      }
      return list;
    } finally {
      calloc.free(pCount);
    }
  }

  @override
  Future<DecodedImage?> applyPreset(
      int canvasId, int layerId, int presetIndex, double intensity) async {
    _ensureInitialized();
    final canvasPtr = _getCanvas(canvasId);
    if (canvasPtr == null) return null;
    final pCount = calloc<Int32>();
    try {
      _checkErr(_bindings!.gopost_preset_get_count(_enginePtr!, pCount));
      final count = pCount.value;
      if (presetIndex < 0 || presetIndex >= count) return null;
    } finally {
      calloc.free(pCount);
    }
    final framePtrPtr = calloc<Pointer<Void>>();
    try {
      _checkErr(_bindings!.gopost_canvas_render(canvasPtr, framePtrPtr));
      final framePtr = framePtrPtr.value;
      if (framePtr == nullptr) return null;
      try {
        _checkErr(_bindings!.gopost_preset_apply(
            _enginePtr!, framePtr, presetIndex, intensity));
        final frame = framePtr.cast<NativeGopostFrame>().ref;
        final w = frame.width;
        final h = frame.height;
        final data = frame.data;
        final stride = frame.stride;
        final size = h * stride;
        final pixels = Uint8List(size);
        if (data != nullptr && size > 0) {
          pixels.setRange(0, size, data.asTypedList(size));
        }
        final enginePtr = _bindings!.gopost_canvas_get_engine(canvasPtr);
        if (enginePtr != nullptr) {
          _bindings!.gopost_frame_release(enginePtr, framePtr);
        } else {
          _bindings!.gopost_render_frame_free(framePtr);
        }
        return DecodedImage(width: w, height: h, pixels: pixels);
      } catch (_) {
        final enginePtr = _bindings!.gopost_canvas_get_engine(canvasPtr);
        if (enginePtr != nullptr) {
          _bindings!.gopost_frame_release(enginePtr, framePtr);
        } else {
          _bindings!.gopost_render_frame_free(framePtr);
        }
        rethrow;
      }
    } finally {
      calloc.free(framePtrPtr);
    }
  }

  static EffectDef _parseEffectDef(NativeGopostEffectDef native) {
    final id = _readFixedString(native.id, 64);
    final displayName = _readFixedString(native.displayName, 64);
    final category = EffectCategory.values[native.category.clamp(0, EffectCategory.values.length - 1)];
    final params = <EffectParamDef>[];
    // sizeof(GopostParamDef) = char[64]+char[64]+int32+float+float+float = 144
    const paramSize = 144;
    for (int p = 0; p < native.paramCount && p < 16; p++) {
      final base = p * paramSize;
      final pId = _readFixedStringFromArray(native.paramsRaw, base, 64);
      final pName = _readFixedStringFromArray(native.paramsRaw, base + 64, 64);
      final defaultVal = _readFloatFromArray(native.paramsRaw, base + 132);
      final minVal = _readFloatFromArray(native.paramsRaw, base + 136);
      final maxVal = _readFloatFromArray(native.paramsRaw, base + 140);
      params.add(EffectParamDef(
        id: pId,
        displayName: pName,
        defaultValue: defaultVal,
        minValue: minVal,
        maxValue: maxVal,
      ));
    }
    return EffectDef(
      id: id,
      displayName: displayName,
      category: category,
      params: params,
      gpuAccelerated: native.gpuAccelerated != 0,
    );
  }

  static EffectInstance _parseEffectInstance(NativeGopostEffectInstance native) {
    final effectId = _readFixedString(native.effectId, 64);
    final paramValues = <String, double>{};
    return EffectInstance(
      instanceId: native.instanceId,
      effectId: effectId,
      enabled: native.enabled != 0,
      mix: native.mix,
      paramValues: paramValues,
    );
  }

  static String _readFixedString(Array<Uint8> arr, int maxLen) {
    final bytes = <int>[];
    for (int i = 0; i < maxLen; i++) {
      final b = arr[i];
      if (b == 0) break;
      bytes.add(b);
    }
    return String.fromCharCodes(bytes);
  }

  static String _readFixedStringFromArray(
      Array<Uint8> arr, int offset, int maxLen) {
    final bytes = <int>[];
    for (int i = 0; i < maxLen; i++) {
      final b = arr[offset + i];
      if (b == 0) break;
      bytes.add(b);
    }
    return String.fromCharCodes(bytes);
  }

  static double _readFloatFromArray(Array<Uint8> arr, int offset) {
    final buf = Uint8List(4);
    for (int i = 0; i < 4; i++) {
      buf[i] = arr[offset + i];
    }
    return ByteData.view(buf.buffer).getFloat32(0, Endian.little);
  }

  @override
  Future<void> initText() async {}

  @override
  Future<void> shutdownText() async {}

  @override
  Future<List<String>> getAvailableFonts() async => ['System'];

  @override
  Future<int> addTextLayer(
      int canvasId, TextConfig config, int maxWidth,
      {int index = -1}) async =>
      0;

  @override
  Future<void> updateTextLayer(
      int canvasId, int layerId, TextConfig config, int maxWidth) async {}

  @override
  Future<void> addMask(int canvasId, int layerId, MaskType type) async {}

  @override
  Future<void> removeMask(int canvasId, int layerId) async {}

  @override
  Future<bool> hasMask(int canvasId, int layerId) async => false;

  @override
  Future<void> invertMask(int canvasId, int layerId) async {}

  @override
  Future<void> setMaskEnabled(
      int canvasId, int layerId, bool enabled) async {}

  @override
  Future<void> maskPaint(
      int canvasId,
      int layerId,
      double cx,
      double cy,
      double radius,
      double hardness,
      MaskBrushMode mode,
      double opacity) async {}

  @override
  Future<void> maskFill(int canvasId, int layerId, int value) async {}

  @override
  Future<void> saveProject(int canvasId, String filePath) async {}

  @override
  Future<int> loadProject(String filePath) async => 0;
}

/// Loads the gopost image editor native library.
DynamicLibrary? loadGopostImageEngineLibrary() =>
    load_lib.loadGopostImageEngineLibrary();

/// Loads the gopost video editor native library.
DynamicLibrary? loadGopostVideoEngineLibrary() =>
    load_lib.loadGopostVideoEngineLibrary();

@Deprecated('Use loadGopostImageEngineLibrary or loadGopostVideoEngineLibrary')
DynamicLibrary? loadGopostNativeLibrary() =>
    load_lib.loadGopostImageEngineLibrary();

final class _GopostEngineConfig extends Struct {
  @Uint32()
  external int threadCount;

  @Uint64()
  external int framePoolSizeMb;

  @Int32()
  external int enableGpu;

  @Int32()
  external int logLevel;
}
