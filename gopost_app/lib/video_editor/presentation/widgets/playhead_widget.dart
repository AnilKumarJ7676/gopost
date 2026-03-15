import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double kPlayheadTriangleWidth = 14;
const double kPlayheadTriangleHeight = 12;
const double kPlayheadLineWidth = 2;

/// The hit target width varies by platform: wider on mobile for touch.
double get kPlayheadHitWidth {
  if (kIsWeb) return 24;
  try {
    if (Platform.isIOS || Platform.isAndroid) return 36;
  } catch (_) {}
  return 24;
}

/// Visual playhead indicator (triangle head + vertical line).
///
/// When [onDragStart], [onDragUpdate], [onDragEnd] are provided, the playhead
/// becomes draggable. On desktop it responds to hover with cursor changes and
/// a highlight tint; on mobile the hit target is wider for touch ergonomics.
class PlayheadWidget extends StatefulWidget {
  const PlayheadWidget({
    super.key,
    required this.height,
    this.color,
    this.activeColor,
    this.isActive = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTap,
  });

  final double height;
  final Color? color;
  final Color? activeColor;
  final bool isActive;
  final ValueChanged<DragStartDetails>? onDragStart;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onTap;

  @override
  State<PlayheadWidget> createState() => _PlayheadWidgetState();
}

class _PlayheadWidgetState extends State<PlayheadWidget> {
  bool _isHovering = false;
  bool _isDragging = false;

  Color get _effectiveColor {
    if (_isDragging || widget.isActive) {
      return widget.activeColor ?? const Color(0xFF6C63FF);
    }
    if (_isHovering) {
      return (widget.color ?? Colors.white).withValues(alpha: 0.85);
    }
    return widget.color ?? Colors.white;
  }

  bool get _isInteractive => widget.onDragStart != null;

  @override
  Widget build(BuildContext context) {
    final hitWidth = kPlayheadHitWidth;
    const visualWidth = kPlayheadTriangleWidth;

    final Widget playhead = SizedBox(
      width: visualWidth,
      height: widget.height,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(kPlayheadTriangleWidth, kPlayheadTriangleHeight),
              painter: _TrianglePainter(_effectiveColor),
            ),
          ),
          Positioned(
            top: kPlayheadTriangleHeight - 2,
            bottom: 0,
            child: Container(
              width: kPlayheadLineWidth,
              decoration: BoxDecoration(
                color: _effectiveColor,
                boxShadow: [
                  BoxShadow(
                    color: _effectiveColor.withValues(alpha: 0.4),
                    blurRadius: _isDragging ? 6 : 4,
                    spreadRadius: _isDragging ? 2 : 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!_isInteractive) return playhead;

    return MouseRegion(
      cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      hitTestBehavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onHorizontalDragStart: (details) {
          setState(() => _isDragging = true);
          HapticFeedback.selectionClick();
          widget.onDragStart?.call(details);
        },
        onHorizontalDragUpdate: (details) {
          widget.onDragUpdate?.call(details);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        onHorizontalDragCancel: () {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        child: SizedBox(
          width: hitWidth,
          height: widget.height,
          child: Center(child: playhead),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => color != old.color;
}
