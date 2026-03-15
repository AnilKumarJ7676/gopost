import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/image_editor/presentation/providers/canvas_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// S5-10: Canvas preview widget.
/// Uses InteractiveViewer for pan/zoom gestures.
/// When layers exist, renders canvas via engine (or stub) and displays the result.
class CanvasPreview extends ConsumerStatefulWidget {
  const CanvasPreview({super.key});

  @override
  ConsumerState<CanvasPreview> createState() => _CanvasPreviewState();
}

class _CanvasPreviewState extends ConsumerState<CanvasPreview> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformUpdate() {
    final matrix = _transformController.value;
    final zoom = matrix.getMaxScaleOnAxis();
    final tx = matrix.getTranslation().x;
    final ty = matrix.getTranslation().y;

    ref.read(canvasProvider.notifier).updateViewport(
      ViewportState(panX: tx, panY: ty, zoom: zoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final canvas = canvasState.canvas;

    return Container(
      color: AppColors.editorBackground,
      child: InteractiveViewer(
        transformationController: _transformController,
        onInteractionEnd: (_) => _onTransformUpdate(),
        minScale: 0.1,
        maxScale: 10.0,
        boundaryMargin: const EdgeInsets.all(200),
        child: Center(
          child: canvas != null
              ? _buildCanvasSurface(canvas.width, canvas.height, canvasState)
              : _buildEmptyState(context),
        ),
      ),
    );
  }

  Widget _buildCanvasSurface(
      int width, int height, CanvasState canvasState) {
    final hasLayers = canvasState.layers.isNotEmpty;
    return AspectRatio(
      aspectRatio: width / height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.white24, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildCheckerboard(),
            if (hasLayers)
              Positioned.fill(
                child: FutureBuilder<DecodedImage>(
                  key: ValueKey(
                      '${canvasState.canvas!.canvasId}-${canvasState.layers.length}-${canvasState.revision}'),
                  future: ref
                      .read(renderRepositoryProvider)
                      .renderCanvas(canvasState.canvas!.canvasId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return _RenderedCanvasImage(decoded: snapshot.data!);
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Render: ${snapshot.error}',
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const Center(
                        child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2)));
                  },
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${width} × $height',
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0 layers',
                      style: const TextStyle(
                        color: Colors.black26,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckerboard() {
    return Positioned.fill(
      child: CustomPaint(painter: _CheckerPainter()),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'Import a photo or create a blank canvas',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Decodes RGBA [DecodedImage] to [ui.Image] and displays it (works on all platforms).
class _RenderedCanvasImage extends StatefulWidget {
  final DecodedImage decoded;

  const _RenderedCanvasImage({required this.decoded});

  @override
  State<_RenderedCanvasImage> createState() => _RenderedCanvasImageState();
}

class _RenderedCanvasImageState extends State<_RenderedCanvasImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _RenderedCanvasImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decoded.pixels != widget.decoded.pixels ||
        oldWidget.decoded.width != widget.decoded.width ||
        oldWidget.decoded.height != widget.decoded.height) {
      _image?.dispose();
      _image = null;
      _decode();
    }
  }

  void _decode() {
    // Flutter expects premultiplied alpha for rgba8888; engine/stub use straight alpha.
    final w = widget.decoded.width;
    final h = widget.decoded.height;
    final src = widget.decoded.pixels;
    final premul = _toPremultipliedAlpha(src);
    ui.decodeImageFromPixels(
      premul,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = image;
        });
      },
    );
  }

  static Uint8List _toPremultipliedAlpha(Uint8List rgba) {
    final out = Uint8List(rgba.length);
    for (int i = 0; i < rgba.length; i += 4) {
      final a = rgba[i + 3];
      if (a == 255) {
        out[i] = rgba[i];
        out[i + 1] = rgba[i + 1];
        out[i + 2] = rgba[i + 2];
        out[i + 3] = 255;
      } else if (a == 0) {
        // All zeros already from Uint8List constructor
      } else {
        out[i] = (rgba[i] * a + 127) ~/ 255;
        out[i + 1] = (rgba[i + 1] * a + 127) ~/ 255;
        out[i + 2] = (rgba[i + 2] * a + 127) ~/ 255;
        out[i + 3] = a;
      }
    }
    return out;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return RawImage(
      image: _image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _CheckerPainter extends CustomPainter {
  static final _paintLight = Paint()..color = const Color(0xFFE8E8E8);
  static final _paintDark = Paint()..color = const Color(0xFFD0D0D0);

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 16.0;
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven = ((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? _paintLight : _paintDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
