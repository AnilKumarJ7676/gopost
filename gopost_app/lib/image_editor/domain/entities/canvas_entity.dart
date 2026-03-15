import 'package:equatable/equatable.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Represents an active canvas in the image editor.
class CanvasEntity extends Equatable {
  final int canvasId;
  final int width;
  final int height;
  final double dpi;
  final CanvasColorSpace colorSpace;
  final bool transparentBackground;

  const CanvasEntity({
    required this.canvasId,
    required this.width,
    required this.height,
    this.dpi = 72.0,
    this.colorSpace = CanvasColorSpace.srgb,
    this.transparentBackground = false,
  });

  double get aspectRatio => width / height;

  CanvasEntity copyWith({
    int? width,
    int? height,
    double? dpi,
  }) {
    return CanvasEntity(
      canvasId: canvasId,
      width: width ?? this.width,
      height: height ?? this.height,
      dpi: dpi ?? this.dpi,
      colorSpace: colorSpace,
      transparentBackground: transparentBackground,
    );
  }

  @override
  List<Object?> get props =>
      [canvasId, width, height, dpi, colorSpace, transparentBackground];
}
