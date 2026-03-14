import 'package:flutter/material.dart';

class TimeRuler extends StatelessWidget {
  const TimeRuler({
    super.key,
    required this.duration,
    required this.pixelsPerSecond,
    required this.viewportWidth,
    this.inPoint,
    this.outPoint,
  });

  final double duration;
  final double pixelsPerSecond;
  final double viewportWidth;
  final double? inPoint;
  final double? outPoint;

  @override
  Widget build(BuildContext context) {
    final totalWidth = (duration > 0 ? duration : 10) * pixelsPerSecond;
    final width = totalWidth.clamp(viewportWidth, 50000.0);
    final interval = _bestInterval(pixelsPerSecond);

    return Container(
      color: const Color(0xFF14142B),
      child: CustomPaint(
        size: Size(width, 34),
        painter: _RulerPainter(
          interval: interval,
          pixelsPerSecond: pixelsPerSecond,
          duration: duration > 0 ? duration : 10,
          textColor: const Color(0xFF6B6B88),
          tickColor: const Color(0xFF303050),
          majorTickColor: const Color(0xFF404060),
          inPoint: inPoint,
          outPoint: outPoint,
        ),
      ),
    );
  }

  static double _bestInterval(double pxPerSec) {
    const intervals = [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0];
    for (final i in intervals) {
      if (i * pxPerSec >= 60) return i;
    }
    return 60;
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.interval,
    required this.pixelsPerSecond,
    required this.duration,
    required this.textColor,
    required this.tickColor,
    required this.majorTickColor,
    this.inPoint,
    this.outPoint,
  });

  final double interval;
  final double pixelsPerSecond;
  final double duration;
  final Color textColor;
  final Color tickColor;
  final Color majorTickColor;
  final double? inPoint;
  final double? outPoint;

  @override
  void paint(Canvas canvas, Size size) {
    // In/Out range highlight
    if (inPoint != null || outPoint != null) {
      final rangeStart = (inPoint ?? 0) * pixelsPerSecond;
      final rangeEnd = (outPoint ?? duration) * pixelsPerSecond;
      if (rangeEnd > rangeStart) {
        canvas.drawRect(
          Rect.fromLTRB(rangeStart, size.height - 3, rangeEnd, size.height),
          Paint()..color = const Color(0xFF6C63FF).withAlpha(80),
        );
      }
    }

    final majorPaint = Paint()..color = majorTickColor..strokeWidth = 1;
    final minorPaint = Paint()..color = tickColor..strokeWidth = 1;
    final textStyle = TextStyle(color: textColor, fontSize: 12, fontFamily: 'monospace');
    final totalTicks = (duration / interval).ceil() + 1;

    for (int i = 0; i < totalTicks; i++) {
      final t = i * interval;
      final x = t * pixelsPerSecond;
      if (x > size.width) break;

      canvas.drawLine(Offset(x, size.height - 10), Offset(x, size.height), majorPaint);

      final tp = TextPainter(
        text: TextSpan(text: _formatTime(t), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, 4));

      final subInterval = interval / 4;
      for (int j = 1; j < 4; j++) {
        final sx = (t + j * subInterval) * pixelsPerSecond;
        if (sx > size.width) break;
        canvas.drawLine(Offset(sx, size.height - 5), Offset(sx, size.height), minorPaint);
      }
    }

    // In-point marker
    if (inPoint != null) {
      final ix = inPoint! * pixelsPerSecond;
      canvas.drawLine(
        Offset(ix, 0), Offset(ix, size.height),
        Paint()..color = const Color(0xFF66BB6A)..strokeWidth = 2,
      );
      final path = Path()
        ..moveTo(ix, size.height - 8)
        ..lineTo(ix + 6, size.height)
        ..lineTo(ix, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF66BB6A));
    }

    // Out-point marker
    if (outPoint != null) {
      final ox = outPoint! * pixelsPerSecond;
      canvas.drawLine(
        Offset(ox, 0), Offset(ox, size.height),
        Paint()..color = const Color(0xFFEF5350)..strokeWidth = 2,
      );
      final path = Path()
        ..moveTo(ox, size.height - 8)
        ..lineTo(ox - 6, size.height)
        ..lineTo(ox, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFEF5350));
    }
  }

  String _formatTime(double s) {
    if (s < 60) {
      final sec = s.floor();
      final frac = ((s - sec) * 10).floor();
      return frac > 0 ? '$sec.${frac}s' : '${sec}s';
    }
    final m = (s / 60).floor();
    final sec = (s % 60).floor();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      interval != old.interval ||
      pixelsPerSecond != old.pixelsPerSecond ||
      duration != old.duration ||
      inPoint != old.inPoint ||
      outPoint != old.outPoint;
}
