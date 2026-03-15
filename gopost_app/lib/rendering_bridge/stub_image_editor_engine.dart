import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'stub_read_file_stub.dart' if (dart.library.io) 'stub_read_file_io.dart' as _file_reader;

/// In-memory layer data for stub engine (so image load works on iOS/macOS/web
/// when native engine is not loaded).
class _StubLayer {
  final int id;
  final LayerType type;
  String name;
  double opacity;
  BlendMode blendMode;
  bool visible;
  bool locked;
  double tx, ty, sx, sy, rotation;
  final int contentWidth;
  final int contentHeight;
  /// RGBA pixels for image layers; null for solid/group.
  Uint8List? imagePixels;
  /// Solid color for solid layers (r,g,b,a 0-1).
  double? solidR, solidG, solidB, solidA;

  _StubLayer({
    required this.id,
    required this.type,
    required this.name,
    this.opacity = 1.0,
    this.blendMode = BlendMode.normal,
    this.visible = true,
    this.locked = false,
    this.tx = 0,
    this.ty = 0,
    this.sx = 1,
    this.sy = 1,
    this.rotation = 0,
    this.contentWidth = 0,
    this.contentHeight = 0,
    this.imagePixels,
    this.solidR,
    this.solidG,
    this.solidB,
    this.solidA,
  });

  LayerInfo toLayerInfo() {
    return LayerInfo(
      id: id,
      type: type,
      name: name,
      opacity: opacity,
      blendMode: blendMode,
      visible: visible,
      locked: locked,
      tx: tx,
      ty: ty,
      sx: sx,
      sy: sy,
      rotation: rotation,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
    );
  }
}

/// Stub implementation of [ImageEditorEngine] so the image editor UI can open
/// when the native engine is not yet wired (e.g. development, or engine not built).
/// Keeps layers in memory and composites them for preview on all platforms.
class StubImageEditorEngine implements ImageEditorEngine {
  int _nextCanvasId = 1;
  int _nextLayerId = 1;
  int? _currentCanvasId;
  int _canvasWidth = 1080;
  int _canvasHeight = 1080;
  double _canvasDpi = 72;
  final ViewportState _viewport = const ViewportState();
  final List<_StubLayer> _layers = [];

  _StubLayer? _layer(int layerId) {
    try {
      return _layers.firstWhere((l) => l.id == layerId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> createCanvas(CanvasConfig config) async {
    _currentCanvasId = _nextCanvasId++;
    _canvasWidth = config.width;
    _canvasHeight = config.height;
    _canvasDpi = config.dpi;
    _layers.clear();
    return _currentCanvasId!;
  }

  @override
  Future<void> destroyCanvas(int canvasId) async {
    if (_currentCanvasId == canvasId) {
      _currentCanvasId = null;
      _layers.clear();
    }
  }

  @override
  Future<({int width, int height, double dpi})> getCanvasSize(int canvasId) async {
    return (width: _canvasWidth, height: _canvasHeight, dpi: _canvasDpi);
  }

  @override
  Future<void> resizeCanvas(int canvasId, int width, int height) async {
    _canvasWidth = width;
    _canvasHeight = height;
  }

  @override
  Future<int> addImageLayer(
      int canvasId, Uint8List rgbaPixels, int width, int height,
      {int index = -1}) async {
    final id = _nextLayerId++;
    final pixels = Uint8List.fromList(rgbaPixels);
    final layer = _StubLayer(
      id: id,
      type: LayerType.image,
      name: 'Layer ${_layers.length + 1}',
      contentWidth: width,
      contentHeight: height,
      imagePixels: pixels,
    );
    if (index < 0 || index >= _layers.length) {
      _layers.add(layer);
    } else {
      _layers.insert(index, layer);
    }
    return id;
  }

  @override
  Future<int> addSolidLayer(int canvasId, double r, double g, double b,
      double a, int width, int height,
      {int index = -1}) async {
    final id = _nextLayerId++;
    final layer = _StubLayer(
      id: id,
      type: LayerType.solidColor,
      name: 'Solid ${_layers.length + 1}',
      contentWidth: width,
      contentHeight: height,
      solidR: r,
      solidG: g,
      solidB: b,
      solidA: a,
    );
    if (index < 0 || index >= _layers.length) {
      _layers.add(layer);
    } else {
      _layers.insert(index, layer);
    }
    return id;
  }

  @override
  Future<int> addGroupLayer(int canvasId, String name, {int index = -1}) async {
    final id = _nextLayerId++;
    final layer = _StubLayer(
      id: id,
      type: LayerType.group,
      name: name.isNotEmpty ? name : 'Group ${_layers.length + 1}',
    );
    if (index < 0 || index >= _layers.length) {
      _layers.add(layer);
    } else {
      _layers.insert(index, layer);
    }
    return id;
  }

  @override
  Future<void> removeLayer(int canvasId, int layerId) async {
    _layers.removeWhere((l) => l.id == layerId);
  }

  @override
  Future<void> reorderLayer(int canvasId, int layerId, int newIndex) async {
    final idx = _layers.indexWhere((l) => l.id == layerId);
    if (idx < 0) return;
    final layer = _layers.removeAt(idx);
    final insert = newIndex.clamp(0, _layers.length);
    _layers.insert(insert, layer);
  }

  @override
  Future<int> duplicateLayer(int canvasId, int layerId) async {
    final layer = _layer(layerId);
    if (layer == null) return 0;
    final id = _nextLayerId++;
    final copy = _StubLayer(
      id: id,
      type: layer.type,
      name: '${layer.name} copy',
      opacity: layer.opacity,
      blendMode: layer.blendMode,
      visible: layer.visible,
      locked: layer.locked,
      tx: layer.tx,
      ty: layer.ty,
      sx: layer.sx,
      sy: layer.sy,
      rotation: layer.rotation,
      contentWidth: layer.contentWidth,
      contentHeight: layer.contentHeight,
      imagePixels: layer.imagePixels != null
          ? Uint8List.fromList(layer.imagePixels!)
          : null,
      solidR: layer.solidR,
      solidG: layer.solidG,
      solidB: layer.solidB,
      solidA: layer.solidA,
    );
    final idx = _layers.indexWhere((l) => l.id == layerId);
    _layers.insert(idx + 1, copy);
    return id;
  }

  @override
  Future<int> getLayerCount(int canvasId) async => _layers.length;

  @override
  Future<LayerInfo> getLayerInfo(int canvasId, int layerId) async {
    final layer = _layer(layerId);
    if (layer == null) {
      throw StateError('Layer $layerId not found');
    }
    return layer.toLayerInfo();
  }

  @override
  Future<List<int>> getLayerIds(int canvasId) async =>
      _layers.map((l) => l.id).toList();

  @override
  Future<void> setLayerVisible(int canvasId, int layerId, bool visible) async {
    _layer(layerId)?.visible = visible;
  }

  @override
  Future<void> setLayerLocked(int canvasId, int layerId, bool locked) async {
    _layer(layerId)?.locked = locked;
  }

  @override
  Future<void> setLayerOpacity(int canvasId, int layerId, double opacity) async {
    _layer(layerId)?.opacity = opacity;
  }

  @override
  Future<void> setLayerBlendMode(
      int canvasId, int layerId, BlendMode blendMode) async {
    _layer(layerId)?.blendMode = blendMode;
  }

  @override
  Future<void> setLayerName(int canvasId, int layerId, String name) async {
    final l = _layer(layerId);
    if (l != null) l.name = name;
  }

  @override
  Future<void> setLayerTransform(int canvasId, int layerId,
      {double tx = 0,
      double ty = 0,
      double sx = 1,
      double sy = 1,
      double rotation = 0}) async {
    final l = _layer(layerId);
    if (l != null) {
      l.tx = tx;
      l.ty = ty;
      l.sx = sx;
      l.sy = sy;
      l.rotation = rotation;
    }
  }

  @override
  Future<DecodedImage> renderCanvas(int canvasId) async {
    final w = _canvasWidth.clamp(1, 8192);
    final h = _canvasHeight.clamp(1, 8192);
    final out = Uint8List(w * h * 4);
    // Transparent background
    for (int i = 0; i < w * h * 4; i += 4) {
      out[i] = 0;
      out[i + 1] = 0;
      out[i + 2] = 0;
      out[i + 3] = 0;
    }
    for (final layer in _layers) {
      if (!layer.visible) continue;
      if (layer.type == LayerType.image && layer.imagePixels != null) {
        _blendImage(out, w, h, layer.imagePixels!, layer.contentWidth,
            layer.contentHeight, layer.opacity);
      } else if (layer.type == LayerType.solidColor &&
          layer.solidR != null &&
          layer.solidG != null &&
          layer.solidB != null &&
          layer.solidA != null) {
        _blendSolid(out, w, h, layer.solidR!, layer.solidG!, layer.solidB!,
            layer.solidA! * layer.opacity);
      }
    }
    return DecodedImage(width: w, height: h, pixels: out);
  }

  void _blendSolid(Uint8List out, int cw, int ch, double r, double g, double b,
      double a) {
    final ir = (r * 255).round().clamp(0, 255);
    final ig = (g * 255).round().clamp(0, 255);
    final ib = (b * 255).round().clamp(0, 255);
    final ia = (a * 255).round().clamp(0, 255);
    for (int i = 0; i < out.length; i += 4) {
      final da = out[i + 3] / 255.0;
      final sa = ia / 255.0;
      final outA = sa + da * (1 - sa);
      if (outA <= 0) continue;
      out[i] = ((ir * sa + out[i] * da * (1 - sa)) / outA).round().clamp(0, 255);
      out[i + 1] =
          ((ig * sa + out[i + 1] * da * (1 - sa)) / outA).round().clamp(0, 255);
      out[i + 2] =
          ((ib * sa + out[i + 2] * da * (1 - sa)) / outA).round().clamp(0, 255);
      out[i + 3] = (outA * 255).round().clamp(0, 255);
    }
  }

  void _blendImage(Uint8List out, int cw, int ch, Uint8List src, int sw,
      int sh, double opacity) {
    if (sw <= 0 || sh <= 0) return;
    // Preserve aspect ratio: fit image within canvas, centered (letterbox/pillarbox).
    final scaleX = cw / sw;
    final scaleY = ch / sh;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dw = (sw * scale).round().clamp(1, cw);
    final dh = (sh * scale).round().clamp(1, ch);
    final left = ((cw - dw) / 2).round();
    final top = ((ch - dh) / 2).round();
    for (int y = 0; y < ch; y++) {
      for (int x = 0; x < cw; x++) {
        final oi = (y * cw + x) * 4;
        // Only sample from source when (x,y) is inside the centered image rect.
        if (x < left || x >= left + dw || y < top || y >= top + dh) continue;
        final sx = ((x - left) * sw / dw).floor().clamp(0, sw - 1);
        final sy = ((y - top) * sh / dh).floor().clamp(0, sh - 1);
        final si = (sy * sw + sx) * 4;
        final sa = (src[si + 3] / 255.0) * opacity;
        final da = out[oi + 3] / 255.0;
        final outA = sa + da * (1 - sa);
        if (outA <= 0) continue;
        out[oi] = ((src[si] * sa + out[oi] * da * (1 - sa)) / outA)
            .round()
            .clamp(0, 255);
        out[oi + 1] = ((src[si + 1] * sa + out[oi + 1] * da * (1 - sa)) / outA)
            .round()
            .clamp(0, 255);
        out[oi + 2] = ((src[si + 2] * sa + out[oi + 2] * da * (1 - sa)) / outA)
            .round()
            .clamp(0, 255);
        out[oi + 3] = (outA * 255).round().clamp(0, 255);
      }
    }
  }

  @override
  Future<void> invalidateCanvas(int canvasId) async {}

  @override
  Future<void> invalidateLayer(int canvasId, int layerId) async {}

  @override
  Future<({int textureHandle, int width, int height})> renderToGpuTexture(
      int canvasId) async =>
      (textureHandle: 0, width: _canvasWidth, height: _canvasHeight);

  @override
  Future<void> setViewport(int canvasId, ViewportState viewport) async {}

  @override
  Future<ViewportState> getViewport(int canvasId) async => _viewport;

  @override
  Future<ImageInfo> probeImage(Uint8List data) async {
    throw UnimplementedError('Stub engine: probe not available');
  }

  @override
  Future<DecodedImage> decodeImage(Uint8List data) async {
    return _decodeToRgbaSafe(data);
  }

  @override
  Future<DecodedImage> decodeImageResized(
      Uint8List data, int maxWidth, int maxHeight) async {
    return _decodeToRgbaSafe(data,
        maxWidth: maxWidth, maxHeight: maxHeight);
  }

  @override
  Future<DecodedImage> decodeImageFile(String path) async {
    // iOS/macOS may return file:// URL from image picker.
    String filePath = path;
    if (path.startsWith('file://')) {
      filePath = Uri.parse(path).path;
    }
    final bytes = await _file_reader.stubReadFileBytes(filePath);
    return _decodeToRgbaSafe(bytes);
  }

  /// Decode image bytes to RGBA. Supports formats provided by Flutter's codec:
  /// JPEG, PNG, GIF, WebP, BMP; HEIC on iOS/macOS. Works on all platforms.
  static Future<DecodedImage> _decodeToRgbaSafe(Uint8List data,
      {int? maxWidth, int? maxHeight}) async {
    try {
      return await _decodeToRgba(data,
          maxWidth: maxWidth, maxHeight: maxHeight);
    } catch (e) {
      if (maxWidth != null || maxHeight != null) {
        try {
          return await _decodeToRgba(data);
        } catch (_) {
          throw StateError(
            'Unsupported image format or corrupt file. Supported: JPEG, PNG, GIF, WebP, BMP; HEIC on iOS/macOS. ($e)',
          );
        }
      }
      throw StateError(
        'Unsupported image format or corrupt file. Supported: JPEG, PNG, GIF, WebP, BMP; HEIC on iOS/macOS. ($e)',
      );
    }
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
      throw StateError('Failed to decode image to RGBA pixels');
    }

    return DecodedImage(
      width: image.width,
      height: image.height,
      pixels: byteData.buffer.asUint8List(),
    );
  }

  @override
  Future<Uint8List> encodeJpeg(DecodedImage image, {int quality = 85}) async =>
      Uint8List(0);

  @override
  Future<Uint8List> encodePng(DecodedImage image) async => Uint8List(0);

  @override
  Future<Uint8List> encodeWebp(DecodedImage image,
      {int quality = 80, bool lossless = false}) async =>
      Uint8List(0);

  @override
  Future<void> encodeToFile(DecodedImage image, String path, ImageFormat format,
      {int quality = 85}) async {}

  @override
  Future<void> initEffects() async {}

  @override
  Future<void> shutdownEffects() async {}

  @override
  Future<List<EffectDef>> getAllEffects() async => [];

  @override
  Future<EffectDef?> findEffect(String effectId) async => null;

  @override
  Future<List<EffectDef>> getEffectsByCategory(
      EffectCategory category) async =>
      [];

  @override
  Future<int> addEffectToLayer(
      int canvasId, int layerId, String effectId) async =>
      0;

  @override
  Future<void> removeEffectFromLayer(
      int canvasId, int layerId, int instanceId) async {}

  @override
  Future<List<EffectInstance>> getLayerEffects(
      int canvasId, int layerId) async =>
      [];

  @override
  Future<void> setEffectEnabled(
      int canvasId, int layerId, int instanceId, bool enabled) async {}

  @override
  Future<void> setEffectMix(
      int canvasId, int layerId, int instanceId, double mix) async {}

  @override
  Future<void> setEffectParam(int canvasId, int layerId, int instanceId,
      String paramId, double value) async {}

  @override
  Future<double> getEffectParam(
      int canvasId, int layerId, int instanceId, String paramId) async =>
      0;

  static const List<PresetFilterInfo> _presets = [
    PresetFilterInfo(index: 0, name: 'Warm', category: 'Color'),
    PresetFilterInfo(index: 1, name: 'Cool', category: 'Color'),
    PresetFilterInfo(index: 2, name: 'Vintage', category: 'Style'),
    PresetFilterInfo(index: 3, name: 'B&W', category: 'Style'),
  ];

  @override
  Future<List<PresetFilterInfo>> getPresetFilters() async =>
      List.from(_presets);

  @override
  Future<DecodedImage?> applyPreset(
      int canvasId, int layerId, int presetIndex, double intensity) async {
    final current = await renderCanvas(canvasId);
    final t = (intensity / 100.0).clamp(0.0, 1.0);
    final out = Uint8List.fromList(current.pixels);
    final n = out.length ~/ 4;
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      int r = out[o].toInt();
      int g = out[o + 1].toInt();
      int b = out[o + 2].toInt();
      final a = out[o + 3];
      switch (presetIndex.clamp(0, 3)) {
        case 0: // Warm
          r = (r + (255 - r) * 0.1 * t).round().clamp(0, 255);
          b = (b * (1 - 0.15 * t)).round().clamp(0, 255);
          break;
        case 1: // Cool
          b = (b + (255 - b) * 0.1 * t).round().clamp(0, 255);
          r = (r * (1 - 0.1 * t)).round().clamp(0, 255);
          break;
        case 2: // Vintage
          r = (r * 1.1 + 10 * t).round().clamp(0, 255);
          g = (g * 0.95).round().clamp(0, 255);
          b = (b * 0.9 - 5 * t).round().clamp(0, 255);
          break;
        case 3: // B&W
          final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
          final mix = gray * t + r * (1 - t);
          r = mix.round().clamp(0, 255);
          g = (gray * t + g * (1 - t)).round().clamp(0, 255);
          b = (gray * t + b * (1 - t)).round().clamp(0, 255);
          break;
      }
      out[o] = r.clamp(0, 255);
      out[o + 1] = g.clamp(0, 255);
      out[o + 2] = b.clamp(0, 255);
    }
    return DecodedImage(width: current.width, height: current.height, pixels: out);
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
  Future<ExportResult> exportToFile(int canvasId, ExportConfig config,
      String outputPath,
      {void Function(double progress)? onProgress}) async {
    return const ExportResult();
  }

  @override
  Future<int> estimateFileSize(int canvasId, ExportConfig config) async => 0;

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
