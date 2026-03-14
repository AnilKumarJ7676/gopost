import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gopost_app/core/theme/app_colors.dart';

/// Overlay widget that shows transform handles for the selected layer.
/// Displays 8 resize handles, a rotation handle, and a dashed border.
class TransformOverlay extends StatefulWidget {
  final Rect layerBounds;
  final VoidCallback? onMoveStart;
  final void Function(Offset delta)? onMove;
  final void Function(double scaleFactor)? onScale;
  final void Function(double angleDelta)? onRotate;

  const TransformOverlay({
    super.key,
    required this.layerBounds,
    this.onMoveStart,
    this.onMove,
    this.onScale,
    this.onRotate,
  });

  @override
  State<TransformOverlay> createState() => _TransformOverlayState();
}

class _TransformOverlayState extends State<TransformOverlay> {
  static const double _handleSize = 10;
  static const double _rotationHandleSize = 8;
  static const double _rotationHandleOffset = 20;

  Offset? _lastPanPoint;
  Offset? _lastRotationCenter;
  double _lastAngle = 0;

  @override
  Widget build(BuildContext context) {
    final rect = widget.layerBounds;
    final center = rect.center;
    final topCenter = Offset(center.dx, rect.top);
    final rotationHandlePos = Offset(
      topCenter.dx,
      topCenter.dy - _rotationHandleOffset,
    );

    return Stack(
      children: [
        CustomPaint(
          painter: _TransformOverlayPainter(
            layerBounds: rect,
            rotationHandlePos: rotationHandlePos,
          ),
          size: Size.infinite,
        ),
        _buildHandle(
          rect.topLeft,
          () => _onResizeDragStart(rect.topLeft, rect.bottomRight),
          (d) => _onResizeDragUpdate(d, rect.topLeft),
          _onResizeDragEnd,
        ),
        _buildHandle(
          Offset(rect.centerLeft.dx, rect.top),
          () => _onResizeDragStart(Offset(rect.centerLeft.dx, rect.top), Offset(rect.centerRight.dx, rect.bottom)),
          (d) => _onResizeDragUpdate(d, Offset(rect.centerLeft.dx, rect.top)),
          _onResizeDragEnd,
        ),
        _buildHandle(
          rect.topRight,
          () => _onResizeDragStart(rect.topRight, rect.bottomLeft),
          (d) => _onResizeDragUpdate(d, rect.topRight),
          _onResizeDragEnd,
        ),
        _buildHandle(
          Offset(rect.right, rect.centerLeft.dy),
          () => _onResizeDragStart(Offset(rect.right, rect.centerLeft.dy), Offset(rect.left, rect.centerRight.dy)),
          (d) => _onResizeDragUpdate(d, Offset(rect.right, rect.centerLeft.dy)),
          _onResizeDragEnd,
        ),
        _buildHandle(
          rect.bottomRight,
          () => _onResizeDragStart(rect.bottomRight, rect.topLeft),
          (d) => _onResizeDragUpdate(d, rect.bottomRight),
          _onResizeDragEnd,
        ),
        _buildHandle(
          Offset(rect.centerLeft.dx, rect.bottom),
          () => _onResizeDragStart(Offset(rect.centerLeft.dx, rect.bottom), Offset(rect.centerRight.dx, rect.top)),
          (d) => _onResizeDragUpdate(d, Offset(rect.centerLeft.dx, rect.bottom)),
          _onResizeDragEnd,
        ),
        _buildHandle(
          rect.bottomLeft,
          () => _onResizeDragStart(rect.bottomLeft, rect.topRight),
          (d) => _onResizeDragUpdate(d, rect.bottomLeft),
          _onResizeDragEnd,
        ),
        _buildHandle(
          Offset(rect.left, rect.centerLeft.dy),
          () => _onResizeDragStart(Offset(rect.left, rect.centerLeft.dy), Offset(rect.right, rect.centerRight.dy)),
          (d) => _onResizeDragUpdate(d, Offset(rect.left, rect.centerLeft.dy)),
          _onResizeDragEnd,
        ),
        _buildRotationHandle(
          rotationHandlePos,
          (d) => _onRotationDragStart(d, rotationHandlePos),
          (d) => _onRotationDragUpdate(d, rotationHandlePos),
          _onRotationDragEnd,
        ),
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              widget.onMoveStart?.call();
              _lastPanPoint = details.localPosition;
            },
            onPanUpdate: (details) {
              if (_lastPanPoint != null) {
                final delta = details.localPosition - _lastPanPoint!;
                _lastPanPoint = details.localPosition;
                widget.onMove?.call(delta);
              }
            },
            onPanEnd: (_) => _lastPanPoint = null,
          ),
        ),
      ],
    );
  }

  Offset? _resizePivot;
  Offset? _resizeHandleStart;

  void _onResizeDragStart(Offset handlePos, Offset pivot) {
    _resizePivot = pivot;
    _resizeHandleStart = handlePos;
    _lastPanPoint = null;
  }

  Offset _localToOverlay(Offset local, Offset handleCenter) {
    return Offset(
      handleCenter.dx - _handleSize / 2 + local.dx,
      handleCenter.dy - _handleSize / 2 + local.dy,
    );
  }

  void _onResizeDragUpdate(DragUpdateDetails details, Offset handleCenter) {
    if (_resizePivot == null || _resizeHandleStart == null) return;

    final newPos = _localToOverlay(details.localPosition, handleCenter);
    final pivot = _resizePivot!;
    final start = _resizeHandleStart!;

    final startDist = (start - pivot).distance;
    final newDist = (newPos - pivot).distance;

    if (startDist > 0) {
      final scaleFactor = newDist / startDist;
      widget.onScale?.call(scaleFactor);
      _resizeHandleStart = newPos;
    }
  }

  void _onResizeDragEnd(DragEndDetails _) {
    _resizePivot = null;
    _resizeHandleStart = null;
  }

  Offset _rotationLocalToOverlay(Offset local, Offset handlePos) {
    return Offset(
      handlePos.dx - _rotationHandleSize / 2 + local.dx,
      handlePos.dy - _rotationHandleSize / 2 + local.dy,
    );
  }

  void _onRotationDragStart(DragStartDetails details, Offset handlePos) {
    _lastRotationCenter = widget.layerBounds.center;
    final globalPos = _rotationLocalToOverlay(details.localPosition, handlePos);
    _lastAngle = _angleFromPoint(globalPos, _lastRotationCenter!);
  }

  void _onRotationDragUpdate(DragUpdateDetails details, Offset handlePos) {
    if (_lastRotationCenter == null) return;

    final globalPos = _rotationLocalToOverlay(details.localPosition, handlePos);
    final currentAngle = _angleFromPoint(globalPos, _lastRotationCenter!);
    var angleDelta = currentAngle - _lastAngle;

    while (angleDelta > math.pi) {
      angleDelta -= 2 * math.pi;
    }
    while (angleDelta < -math.pi) {
      angleDelta += 2 * math.pi;
    }

    widget.onRotate?.call(angleDelta);
    _lastAngle = currentAngle;
  }

  void _onRotationDragEnd(DragEndDetails _) {
    _lastRotationCenter = null;
  }

  double _angleFromPoint(Offset point, Offset center) {
    return math.atan2(point.dy - center.dy, point.dx - center.dx);
  }

  Widget _buildHandle(
    Offset position,
    VoidCallback onStart,
    void Function(DragUpdateDetails) onUpdate,
    void Function(DragEndDetails) onEnd,
  ) {
    return Positioned(
      left: position.dx - _handleSize / 2,
      top: position.dy - _handleSize / 2,
      width: _handleSize,
      height: _handleSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onStart(),
        onPanUpdate: onUpdate,
        onPanEnd: onEnd,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.semanticInfoDark, width: 1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildRotationHandle(
    Offset position,
    void Function(DragStartDetails) onStart,
    void Function(DragUpdateDetails) onUpdate,
    void Function(DragEndDetails) onEnd,
  ) {
    return Positioned(
      left: position.dx - _rotationHandleSize / 2,
      top: position.dy - _rotationHandleSize / 2,
      width: _rotationHandleSize,
      height: _rotationHandleSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: onStart,
        onPanUpdate: onUpdate,
        onPanEnd: onEnd,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.semanticInfoDark, width: 1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TransformOverlayPainter extends CustomPainter {
  final Rect layerBounds;
  final Offset rotationHandlePos;

  _TransformOverlayPainter({
    required this.layerBounds,
    required this.rotationHandlePos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawDashedBorder(canvas);
    _drawRotationLine(canvas);
    _drawHandles(canvas);
  }

  void _drawDashedBorder(Canvas canvas) {
    const dashWidth = 4.0;
    const dashGap = 3.0;
    const strokeWidth = 1.0;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = layerBounds;
    final path = Path()..addRect(rect);

    _drawDashedPath(canvas, path, paint, dashWidth, dashGap);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashWidth,
    double dashGap,
  ) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + dashWidth;
        final extractPath = metric.extractPath(
          distance,
          nextDistance.clamp(0.0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance = nextDistance + dashGap;
      }
    }
  }

  void _drawRotationLine(Canvas canvas) {
    final topCenter = Offset(layerBounds.center.dx, layerBounds.top);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(topCenter, rotationHandlePos, paint);
  }

  void _drawHandles(Canvas canvas) {
    const handleSize = 10.0;
    const rotationHandleSize = 8.0;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.semanticInfoDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = layerBounds;
    final positions = [
      rect.topLeft,
      Offset(rect.centerLeft.dx, rect.top),
      rect.topRight,
      Offset(rect.right, rect.centerLeft.dy),
      rect.bottomRight,
      Offset(rect.centerLeft.dx, rect.bottom),
      rect.bottomLeft,
      Offset(rect.left, rect.centerLeft.dy),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, handleSize / 2, fillPaint);
      canvas.drawCircle(pos, handleSize / 2, strokePaint);
    }

    canvas.drawCircle(rotationHandlePos, rotationHandleSize / 2, fillPaint);
    canvas.drawCircle(rotationHandlePos, rotationHandleSize / 2, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TransformOverlayPainter oldDelegate) {
    return oldDelegate.layerBounds != layerBounds ||
        oldDelegate.rotationHandlePos != rotationHandlePos;
  }
}
