import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/thumbnail_provider.dart';
import 'package:gopost_app/video_editor/presentation/widgets/adjustment_clip_painter.dart';

Color clipColor(ClipSourceType type) => switch (type) {
  ClipSourceType.video => const Color(0xFF26C6DA),
  ClipSourceType.image => const Color(0xFFFF7043),
  ClipSourceType.title => const Color(0xFFAB47BC),
  ClipSourceType.color => const Color(0xFFFFCA28),
  ClipSourceType.adjustment => const Color(0xFF6C63FF),
};

/// Returns the color from the adjustment clip's own data if available.
Color clipColorForClip(VideoClip clip) {
  if (clip.isAdjustmentLayer && clip.adjustmentData != null) {
    return Color(clip.adjustmentData!.colorValue);
  }
  return clipColor(clip.sourceType);
}

IconData clipIcon(ClipSourceType type) => switch (type) {
  ClipSourceType.video => Icons.videocam_rounded,
  ClipSourceType.image => Icons.image_rounded,
  ClipSourceType.title => Icons.title_rounded,
  ClipSourceType.color => Icons.palette_rounded,
  ClipSourceType.adjustment => Icons.auto_fix_high_rounded,
};

const double _kThumbWidth = 56;

class ClipWidget extends ConsumerStatefulWidget {
  const ClipWidget({
    super.key,
    required this.clip,
    required this.pixelsPerSecond,
    required this.isSelected,
    this.trackType = TrackType.video,
    this.isLocked = false,
    this.previewFrame,
    this.playheadPosition = 0,
    required this.onTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTrimLeftUpdate,
    this.onTrimLeftEnd,
    this.onTrimRightUpdate,
    this.onTrimRightEnd,
  });

  final VideoClip clip;
  final TrackType trackType;
  final double pixelsPerSecond;
  final bool isSelected;
  final bool isLocked;
  final ui.Image? previewFrame;
  final double playheadPosition;
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final ValueChanged<DragUpdateDetails>? onTrimLeftUpdate;
  final VoidCallback? onTrimLeftEnd;
  final ValueChanged<DragUpdateDetails>? onTrimRightUpdate;
  final VoidCallback? onTrimRightEnd;

  @override
  ConsumerState<ClipWidget> createState() => _ClipWidgetState();
}

class _ClipWidgetState extends ConsumerState<ClipWidget> {
  bool _isDragging = false;
  double _lastLongPressDx = 0;
  bool _prevIsLive = false;

  bool get _isLive =>
      widget.playheadPosition >= widget.clip.timelineIn &&
      widget.playheadPosition < widget.clip.timelineOut;

  int get _thumbCount {
    final clipPx = widget.clip.duration * widget.pixelsPerSecond;
    return (clipPx / _kThumbWidth).ceil().clamp(1, 40);
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final width = clip.duration * widget.pixelsPerSecond;
    final color = clipColorForClip(clip);
    final isLive = _isLive;

    // Skip rebuild if only the playhead moved and the live state hasn't changed
    // (the most common rebuild trigger during playback).
    if (isLive == _prevIsLive && !_isDragging) {
      // fall through — Flutter will still diff the tree
    }
    _prevIsLive = isLive;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: widget.isLocked ? null : (_) {
        _lastLongPressDx = 0;
        setState(() => _isDragging = true);
      },
      onLongPressMoveUpdate: widget.isLocked ? null : (d) {
        final currentDx = d.localOffsetFromOrigin.dx;
        final incrementalDelta = currentDx - _lastLongPressDx;
        _lastLongPressDx = currentDx;
        widget.onDragUpdate?.call(DragUpdateDetails(
          globalPosition: d.globalPosition,
          localPosition: d.localPosition,
          delta: Offset(incrementalDelta, 0),
          primaryDelta: incrementalDelta,
        ));
      },
      onLongPressEnd: widget.isLocked ? null : (_) {
        _lastLongPressDx = 0;
        setState(() => _isDragging = false);
        widget.onDragEnd?.call();
      },
      child: AnimatedScale(
        scale: _isDragging ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: width.clamp(20.0, double.infinity),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isLive
                        ? const Color(0xFF4CAF50)
                        : widget.isSelected ? color : color.withValues(alpha: 0.5),
                    width: isLive ? 1.5 : (widget.isSelected ? 1.5 : 0.5),
                  ),
                  boxShadow: _isDragging
                      ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 2))]
                      : widget.isSelected
                          ? _neonShadows(color)
                          : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildThumbnailStrip(color)),
                      _buildInfoOverlay(clip, color, width, isLive),
                      if (clip.appliedBadges.isNotEmpty)
                        Positioned.fill(
                          child: _EffectOverlay(badges: clip.appliedBadges),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.isSelected && !widget.isLocked) ...[
                _buildTrimHandle(isLeft: true),
                _buildTrimHandle(isLeft: false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(Color color) {
    final clip = widget.clip;

    if (clip.sourceType == ClipSourceType.video) {
      return _VideoThumbnailStrip(
        sourcePath: clip.hasProxy ? clip.proxyPath! : clip.sourcePath,
        sourceDuration: clip.sourceOut - clip.sourceIn,
        thumbCount: _thumbCount,
        color: color,
      );
    }

    if (clip.sourceType == ClipSourceType.image) {
      return _ImageThumbnailStrip(sourcePath: clip.sourcePath, color: color);
    }

    if (widget.trackType == TrackType.audio) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _AudioWaveformPainter(
            color: color,
            clipDuration: clip.duration,
            pixelsPerSecond: widget.pixelsPerSecond,
            seed: clip.id,
          ),
        ),
      );
    }

    if (widget.trackType == TrackType.effect && clip.isAdjustmentLayer && clip.adjustmentData != null) {
      return _AdjustmentClipVisual(
        adjustmentData: clip.adjustmentData!,
        clipDuration: clip.duration,
        pixelsPerSecond: widget.pixelsPerSecond,
      );
    }

    if (widget.trackType == TrackType.effect) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _EffectGradientPainter(
            color: color,
            clipDuration: clip.duration,
            pixelsPerSecond: widget.pixelsPerSecond,
          ),
        ),
      );
    }

    return Container(color: color.withValues(alpha: 0.15));
  }

  Widget _buildInfoOverlay(VideoClip clip, Color color, double width, bool isLive) {
    return Positioned.fill(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
            ],
            stops: const [0.0, 0.25, 0.75, 1.0],
          ),
        ),
        padding: const EdgeInsets.only(left: 6, right: 4, top: 2, bottom: 2),
        child: Row(
          children: [
            Icon(clipIcon(clip.sourceType), size: 14,
                color: isLive ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.85)),
            if (isLive) ...[
              const SizedBox(width: 3),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF4CAF50),
                  boxShadow: [BoxShadow(color: Color(0x994CAF50), blurRadius: 4)],
                ),
              ),
            ],
            if (clip.sourceType == ClipSourceType.video && clip.proxyStatus != ProxyStatus.none) ...[
              const SizedBox(width: 3),
              _ProxyStatusDot(status: clip.proxyStatus),
            ],
            if (width > 50) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  clip.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                  ),
                ),
              ),
            ],
            if (width > 90) ...[
              const SizedBox(width: 3),
              Text(
                clip.speed != 1.0 ? '${clip.speed}x' : _formatDuration(clip.duration),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrimHandle({required bool isLeft}) {
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0, bottom: 0,
      child: GestureDetector(
        onHorizontalDragUpdate: isLeft ? widget.onTrimLeftUpdate : widget.onTrimRightUpdate,
        onHorizontalDragEnd: (_) => isLeft ? widget.onTrimLeftEnd?.call() : widget.onTrimRightEnd?.call(),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: Container(
            width: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isLeft
                  ? const BorderRadius.horizontal(left: Radius.circular(6))
                  : const BorderRadius.horizontal(right: Radius.circular(6)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
            ),
            child: Center(
              child: Container(
                width: 2, height: 20,
                decoration: BoxDecoration(color: const Color(0xFF303050), borderRadius: BorderRadius.circular(1)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<BoxShadow> _neonShadows(Color color) {
    return [
      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1),
      BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 16),
    ];
  }

  String _formatDuration(double s) {
    final sec = s.floor();
    if (sec < 60) return '${sec}s';
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Thumbnail strip widgets — fetched via Riverpod
// ---------------------------------------------------------------------------

class _VideoThumbnailStrip extends ConsumerStatefulWidget {
  const _VideoThumbnailStrip({
    required this.sourcePath,
    required this.sourceDuration,
    required this.thumbCount,
    required this.color,
  });

  final String sourcePath;
  final double sourceDuration;
  final int thumbCount;
  final Color color;

  @override
  ConsumerState<_VideoThumbnailStrip> createState() => _VideoThumbnailStripState();
}

class _VideoThumbnailStripState extends ConsumerState<_VideoThumbnailStrip> {
  /// Debounce the thumb count so rapid zoom changes don't keep restarting
  /// FFmpeg extractions. We lock in the count on first build and only update
  /// it if the new count persists across rebuilds.
  late int _stableThumbCount;
  int? _pendingThumbCount;

  @override
  void initState() {
    super.initState();
    _stableThumbCount = widget.thumbCount;
  }

  @override
  void didUpdateWidget(covariant _VideoThumbnailStrip old) {
    super.didUpdateWidget(old);
    if (widget.thumbCount != _stableThumbCount) {
      // Thumb count changed (zoom). Accept it after a brief stabilization.
      if (_pendingThumbCount != widget.thumbCount) {
        _pendingThumbCount = widget.thumbCount;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _pendingThumbCount == widget.thumbCount) {
            setState(() {
              _stableThumbCount = widget.thumbCount;
              _pendingThumbCount = null;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ClipThumbRequest(
      sourcePath: widget.sourcePath,
      sourceDuration: widget.sourceDuration,
      count: _stableThumbCount,
    );
    final thumbsAsync = ref.watch(clipThumbnailsProvider(request));

    return thumbsAsync.when(
      data: (thumbs) {
        if (thumbs.isEmpty) return _placeholder(widget.color);
        return Row(
          children: [
            for (int i = 0; i < thumbs.length; i++)
              Expanded(
                child: Image.memory(
                  thumbs[i],
                  fit: BoxFit.cover,
                  height: double.infinity,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(color: widget.color.withValues(alpha: 0.15)),
                ),
              ),
          ],
        );
      },
      loading: () => _ThumbnailShimmer(color: widget.color),
      error: (_, __) => _placeholder(widget.color),
    );
  }

  static Widget _placeholder(Color color) {
    return Container(color: color.withValues(alpha: 0.15));
  }
}

class _ImageThumbnailStrip extends StatelessWidget {
  const _ImageThumbnailStrip({required this.sourcePath, required this.color});

  final String sourcePath;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final file = File(sourcePath);
    if (!file.existsSync()) return Container(color: color.withValues(alpha: 0.15));
    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(color: color.withValues(alpha: 0.15)),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading shimmer while thumbnails are being extracted
// ---------------------------------------------------------------------------

class _ThumbnailShimmer extends StatefulWidget {
  const _ThumbnailShimmer({required this.color});
  final Color color;

  @override
  State<_ThumbnailShimmer> createState() => _ThumbnailShimmerState();
}

class _ThumbnailShimmerState extends State<_ThumbnailShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * t, 0),
              end: Alignment(-0.5 + 2.0 * t, 0),
              colors: [
                widget.color.withValues(alpha: 0.08),
                widget.color.withValues(alpha: 0.18),
                widget.color.withValues(alpha: 0.08),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CapCut-style effect overlay — colored animated bands within the clip
// ---------------------------------------------------------------------------

class _EffectOverlay extends StatelessWidget {
  const _EffectOverlay({required this.badges});
  final List<AppliedBadge> badges;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _EffectOverlayPainter(
          badges: badges,
          phase: 0,
        ),
      ),
    );
  }
}

class _EffectOverlayPainter extends CustomPainter {
  _EffectOverlayPainter({required this.badges, required this.phase});

  final List<AppliedBadge> badges;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (badges.isEmpty) return;

    final count = badges.length;
    final bandH = (size.height * 0.55) / count;
    final startY = (size.height - bandH * count) / 2;

    for (int i = 0; i < count; i++) {
      final badge = badges[i];
      final badgeColor = Color(badge.colorValue);
      final y = startY + i * bandH;

      final stagger = ((phase + i * 0.12) % 1.0);
      final shimmerX = -0.3 + stagger * 1.6;

      final bandRect = Rect.fromLTWH(0, y, size.width, bandH);

      final bgPaint = Paint()
        ..color = badgeColor.withValues(alpha: 0.18);
      canvas.drawRect(bandRect, bgPaint);

      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(shimmerX - 0.4, 0),
          end: Alignment(shimmerX + 0.4, 0),
          colors: [
            badgeColor.withValues(alpha: 0.0),
            badgeColor.withValues(alpha: 0.35),
            badgeColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bandRect);
      canvas.drawRect(bandRect, shimmerPaint);

      final edgePaint = Paint()
        ..color = badgeColor.withValues(alpha: 0.45)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), edgePaint);
      canvas.drawLine(
        Offset(0, y + bandH), Offset(size.width, y + bandH), edgePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_EffectOverlayPainter old) =>
      old.phase != phase || old.badges != badges;
}

// ---------------------------------------------------------------------------
// Track-type-specific painters (audio waveform & effect gradient)
// ---------------------------------------------------------------------------

class _AudioWaveformPainter extends CustomPainter {
  _AudioWaveformPainter({
    required this.color,
    required this.clipDuration,
    required this.pixelsPerSecond,
    required this.seed,
  });

  final Color color;
  final double clipDuration;
  final double pixelsPerSecond;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final midY = size.height / 2;
    const barWidth = 2.0;
    const gap = 1.5;
    const step = barWidth + gap;
    final numBars = (size.width / step).ceil();
    final barPaint = Paint()..color = color.withValues(alpha: 0.5);
    final fillPaint = Paint()..color = color.withValues(alpha: 0.15);
    final linePaint = Paint()..color = color.withValues(alpha: 0.08);

    canvas.drawRect(Rect.fromLTWH(0, midY - 0.5, size.width, 1), linePaint);

    for (int i = 0; i < numBars; i++) {
      final x = i * step;
      final amp = 0.15 + rng.nextDouble() * 0.7;
      final h = amp * (size.height * 0.82);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + barWidth / 2, midY), width: barWidth, height: h),
          const Radius.circular(1),
        ),
        barPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + barWidth / 2, midY), width: barWidth, height: h * 0.5),
          const Radius.circular(1),
        ),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioWaveformPainter old) =>
      old.color != color || old.seed != seed || old.clipDuration != clipDuration;
}

class _ProxyStatusDot extends StatelessWidget {
  const _ProxyStatusDot({required this.status});
  final ProxyStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color dotColor, String tooltip) = switch (status) {
      ProxyStatus.generating => (const Color(0xFFFFCA28), 'Generating proxy...'),
      ProxyStatus.ready => (const Color(0xFF26C6DA), 'Proxy ready'),
      ProxyStatus.failed => (const Color(0xFFEF5350), 'Proxy failed'),
      ProxyStatus.none => (Colors.transparent, ''),
    };
    if (status == ProxyStatus.none) return const SizedBox.shrink();
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dotColor,
          boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 3)],
        ),
      ),
    );
  }
}

class _EffectGradientPainter extends CustomPainter {
  _EffectGradientPainter({
    required this.color,
    required this.clipDuration,
    required this.pixelsPerSecond,
  });

  final Color color;
  final double clipDuration;
  final double pixelsPerSecond;

  @override
  void paint(Canvas canvas, Size size) {
    final gradPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.06),
          color.withValues(alpha: 0.14),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradPaint);

    final dotPaint = Paint()..color = color.withValues(alpha: 0.2);
    const spacing = 14.0;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_EffectGradientPainter old) =>
      old.color != color || old.clipDuration != clipDuration;
}

// ---------------------------------------------------------------------------
// Animated adjustment clip visual — renders AdjustmentClipPainter with
// a looping animation controller for the pattern animation.
// ---------------------------------------------------------------------------

class _AdjustmentClipVisual extends StatefulWidget {
  const _AdjustmentClipVisual({
    required this.adjustmentData,
    required this.clipDuration,
    required this.pixelsPerSecond,
  });

  final AdjustmentClipData adjustmentData;
  final double clipDuration;
  final double pixelsPerSecond;

  @override
  State<_AdjustmentClipVisual> createState() => _AdjustmentClipVisualState();
}

class _AdjustmentClipVisualState extends State<_AdjustmentClipVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.adjustmentData;
    final baseColor = Color(data.colorValue);

    return RepaintBoundary(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: AdjustmentClipPainter(
                  style: data.style,
                  baseColor: baseColor,
                  clipDuration: widget.clipDuration,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  animationValue: _animCtrl.value,
                  effects: data.effects,
                ),
              );
            },
          ),
          Positioned(
            left: 6,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                data.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
