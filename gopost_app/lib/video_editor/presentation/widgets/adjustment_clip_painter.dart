import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';

/// Animated CustomPainter for adjustment layer clips on the timeline.
///
/// Each [AdjustmentClipStyle] produces a distinct animated visual:
/// - [colorWave]: Smooth gradient wave with ripple animation
/// - [blurPulse]: Concentric rings that pulse outward
/// - [distortScan]: Horizontal scanlines with glitch offset
/// - [stylizeDots]: Halftone-like dot matrix
/// - [presetStrip]: Color swatch strip with the preset's signature colors
class AdjustmentClipPainter extends CustomPainter {
  AdjustmentClipPainter({
    required this.style,
    required this.baseColor,
    required this.clipDuration,
    required this.pixelsPerSecond,
    required this.animationValue,
    this.effects = const [],
    this.intensity = 1.0,
  });

  final AdjustmentClipStyle style;
  final Color baseColor;
  final double clipDuration;
  final double pixelsPerSecond;

  /// 0..1 animation tick, drives all animated patterns.
  final double animationValue;
  final List<VideoEffect> effects;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    switch (style) {
      case AdjustmentClipStyle.colorWave:
        _paintColorWave(canvas, size);
      case AdjustmentClipStyle.blurPulse:
        _paintBlurPulse(canvas, size);
      case AdjustmentClipStyle.distortScan:
        _paintDistortScan(canvas, size);
      case AdjustmentClipStyle.stylizeDots:
        _paintStylizeDots(canvas, size);
      case AdjustmentClipStyle.presetStrip:
        _paintPresetStrip(canvas, size);
    }

    _paintEffectIcons(canvas, size);
  }

  // ---------------------------------------------------------------------------
  // Color Wave — smooth gradient undulation for color/tone adjustments
  // ---------------------------------------------------------------------------

  void _paintColorWave(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          baseColor.withValues(alpha: 0.25),
          baseColor.withValues(alpha: 0.08),
          baseColor.withValues(alpha: 0.20),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final wavePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int wave = 0; wave < 3; wave++) {
      final path = Path();
      final phaseOffset = wave * 0.33 + animationValue;
      final amplitude = (size.height * 0.15) * (1 + wave * 0.3);
      final midY = size.height * (0.3 + wave * 0.2);

      path.moveTo(0, midY);
      for (double x = 0; x <= size.width; x += 2) {
        final t = x / size.width;
        final y = midY + math.sin((t * 4 * math.pi) + (phaseOffset * 2 * math.pi)) * amplitude;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, wavePaint..color = baseColor.withValues(alpha: 0.15 + wave * 0.08));
    }
  }

  // ---------------------------------------------------------------------------
  // Blur Pulse — concentric rings that expand outward
  // ---------------------------------------------------------------------------

  void _paintBlurPulse(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = baseColor.withValues(alpha: 0.1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final maxRadius = math.max(size.width, size.height) * 0.6;

    for (int ring = 0; ring < 5; ring++) {
      final phase = (animationValue + ring * 0.2) % 1.0;
      final radius = maxRadius * phase;
      final alpha = (1.0 - phase) * 0.25;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = baseColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Distort Scan — horizontal scanlines with jitter
  // ---------------------------------------------------------------------------

  void _paintDistortScan(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = baseColor.withValues(alpha: 0.08);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final rng = math.Random((animationValue * 100).toInt());
    const lineSpacing = 4.0;
    final scanPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += lineSpacing) {
      final offset = rng.nextDouble() * 6 * math.sin(animationValue * math.pi * 2 + y);
      canvas.drawLine(
        Offset(offset, y),
        Offset(size.width + offset, y),
        scanPaint,
      );
    }

    final glitchY = size.height * ((animationValue * 3) % 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, glitchY, size.width, 3),
      Paint()..color = baseColor.withValues(alpha: 0.35),
    );
  }

  // ---------------------------------------------------------------------------
  // Stylize Dots — halftone dot matrix
  // ---------------------------------------------------------------------------

  void _paintStylizeDots(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = baseColor.withValues(alpha: 0.06);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const spacing = 10.0;
    final dotPaint = Paint()..color = baseColor.withValues(alpha: 0.3);
    final phase = animationValue * spacing;

    for (double y = -spacing + phase; y < size.height + spacing; y += spacing) {
      final rowOffset = ((y / spacing).floor().isOdd) ? spacing * 0.5 : 0.0;
      for (double x = -spacing + rowOffset; x < size.width + spacing; x += spacing) {
        final dist = math.sqrt(math.pow(x - size.width / 2, 2) + math.pow(y - size.height / 2, 2));
        final maxDist = math.sqrt(math.pow(size.width / 2, 2) + math.pow(size.height / 2, 2));
        final sizeFactor = 1.0 - (dist / maxDist).clamp(0.0, 1.0);
        final r = 1.0 + sizeFactor * 2.0;
        canvas.drawCircle(Offset(x, y), r, dotPaint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Preset Strip — color swatch band representing the preset's palette
  // ---------------------------------------------------------------------------

  void _paintPresetStrip(Canvas canvas, Size size) {
    final colors = [
      baseColor.withValues(alpha: 0.3),
      baseColor,
      HSLColor.fromColor(baseColor).withHue((HSLColor.fromColor(baseColor).hue + 30) % 360).toColor(),
      HSLColor.fromColor(baseColor).withHue((HSLColor.fromColor(baseColor).hue + 60) % 360).toColor().withValues(alpha: 0.5),
    ];

    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, 0),
      colors,
      [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient,
    );

    final shimmerX = size.width * animationValue;
    const shimmerWidth = 40.0;
    final shimmerGradient = ui.Gradient.linear(
      Offset(shimmerX - shimmerWidth, 0),
      Offset(shimmerX + shimmerWidth, 0),
      [Colors.transparent, Colors.white.withValues(alpha: 0.15), Colors.transparent],
    );
    canvas.drawRect(
      Rect.fromLTWH(shimmerX - shimmerWidth, 0, shimmerWidth * 2, size.height),
      Paint()..shader = shimmerGradient,
    );
  }

  // ---------------------------------------------------------------------------
  // Effect icons overlay — small icons showing which effects are active
  // ---------------------------------------------------------------------------

  void _paintEffectIcons(Canvas canvas, Size size) {
    if (effects.isEmpty) return;
    final iconCount = effects.length.clamp(0, 6);
    const iconSize = 10.0;
    const padding = 4.0;
    final startX = size.width - (iconCount * (iconSize + padding)) - padding;
    final y = size.height - iconSize - padding;

    for (int i = 0; i < iconCount; i++) {
      final effect = effects[i];
      final x = startX + i * (iconSize + padding);
      final dotPaint = Paint()
        ..color = effect.enabled
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, iconSize, iconSize),
          const Radius.circular(2),
        ),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(AdjustmentClipPainter old) =>
      old.style != style ||
      old.baseColor != baseColor ||
      old.animationValue != animationValue ||
      old.clipDuration != clipDuration ||
      old.pixelsPerSecond != pixelsPerSecond;
}
