import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/models/video_transition.dart';
import 'package:gopost_app/video_editor/presentation/widgets/clip_widget.dart';

const double kTrackHeight = 68;
const double kTrackHeaderWidth = 96;

Color _trackAccent(TrackType type) => switch (type) {
  TrackType.video => const Color(0xFF26C6DA),
  TrackType.audio => const Color(0xFF66BB6A),
  TrackType.title => const Color(0xFFAB47BC),
  TrackType.effect => const Color(0xFF5C6BC0),
  TrackType.subtitle => const Color(0xFF42A5F5),
};

IconData _trackIcon(TrackType type) => switch (type) {
  TrackType.video => Icons.videocam_rounded,
  TrackType.audio => Icons.audiotrack_rounded,
  TrackType.title => Icons.title_rounded,
  TrackType.effect => Icons.auto_fix_high_rounded,
  TrackType.subtitle => Icons.subtitles_rounded,
};

class TrackHeader extends StatelessWidget {
  const TrackHeader({
    super.key,
    required this.track,
    this.onToggleVisibility,
    this.onToggleLock,
    this.onToggleMute,
    this.onToggleSolo,
    this.onRemove,
  });

  final VideoTrack track;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onToggleLock;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSolo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = _trackAccent(track.type);
    final icon = _trackIcon(track.type);

    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        width: kTrackHeaderWidth,
        height: kTrackHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF14142B),
          border: Border(
            right: BorderSide(color: accent.withValues(alpha: 0.3), width: 2),
            bottom: const BorderSide(color: Color(0xFF1E1E38), width: 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 5),
                Text(
                  track.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tinyToggle(
                  icon: track.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  active: track.isVisible,
                  onTap: onToggleVisibility,
                  activeColor: const Color(0xFF8888A0),
                ),
                _tinyToggle(
                  icon: track.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  active: track.isLocked,
                  onTap: onToggleLock,
                  activeColor: const Color(0xFFEF5350),
                ),
                if (track.type == TrackType.audio || track.type == TrackType.video)
                  _tinyToggle(
                    icon: track.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    active: !track.isMuted,
                    onTap: onToggleMute,
                    activeColor: const Color(0xFF8888A0),
                  ),
                if (track.type == TrackType.audio || track.type == TrackType.video)
                  _tinyToggle(
                    icon: Icons.headphones_rounded,
                    active: track.isSolo,
                    onTap: onToggleSolo,
                    activeColor: const Color(0xFFFFCA28),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tinyToggle({
    required IconData icon,
    required bool active,
    VoidCallback? onTap,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Icon(
          icon,
          size: 14,
          color: active ? activeColor ?? const Color(0xFF8888A0) : const Color(0xFF303050),
        ),
      ),
    );
  }
}

class TrackLane extends StatelessWidget {
  const TrackLane({
    super.key,
    required this.track,
    required this.pixelsPerSecond,
    required this.totalWidth,
    required this.selectedClipId,
    required this.onClipTap,
    this.previewFrame,
    this.playheadPosition = 0,
    this.onClipDragUpdate,
    this.onClipDragEnd,
    this.onClipTrimLeftUpdate,
    this.onClipTrimLeftEnd,
    this.onClipTrimRightUpdate,
    this.onClipTrimRightEnd,
    this.onEffectDrop,
    this.onTransitionDropBetween,
  });

  final VideoTrack track;
  final double pixelsPerSecond;
  final double totalWidth;
  final int? selectedClipId;
  final ui.Image? previewFrame;
  final double playheadPosition;
  final ValueChanged<int> onClipTap;
  final void Function(int clipId, DragUpdateDetails details)? onClipDragUpdate;
  final ValueChanged<int>? onClipDragEnd;
  final void Function(int clipId, DragUpdateDetails details)? onClipTrimLeftUpdate;
  final ValueChanged<int>? onClipTrimLeftEnd;
  final void Function(int clipId, DragUpdateDetails details)? onClipTrimRightUpdate;
  final ValueChanged<int>? onClipTrimRightEnd;
  final void Function(int clipId, TimelineDragData data)? onEffectDrop;
  final void Function(int leftClipId, int rightClipId, TransitionDragData data)? onTransitionDropBetween;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !track.isVisible;
    final accent = _trackAccent(track.type);
    final sorted = List<VideoClip>.from(track.clips)
      ..sort((a, b) => a.timelineIn.compareTo(b.timelineIn));

    Widget content = Container(
      height: kTrackHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E1E38), width: 1),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Clip widgets
          for (final clip in track.clips)
            Positioned(
              key: ValueKey('clip_${clip.id}'),
              left: clip.timelineIn * pixelsPerSecond,
              top: 0,
              height: kTrackHeight - 1,
              child: RepaintBoundary(
                child: _ClipDropTarget(
                  clipId: clip.id,
                  accent: accent,
                  onEffectDrop: onEffectDrop,
                  child: ClipWidget(
                    clip: clip,
                    trackType: track.type,
                    pixelsPerSecond: pixelsPerSecond,
                    isSelected: clip.id == selectedClipId,
                    isLocked: track.isLocked,
                    previewFrame: previewFrame,
                    playheadPosition: playheadPosition,
                    onTap: () => onClipTap(clip.id),
                    onDragUpdate: track.isLocked ? null : (d) => onClipDragUpdate?.call(clip.id, d),
                    onDragEnd: track.isLocked ? null : () => onClipDragEnd?.call(clip.id),
                    onTrimLeftUpdate: track.isLocked ? null : (d) => onClipTrimLeftUpdate?.call(clip.id, d),
                    onTrimLeftEnd: track.isLocked ? null : () => onClipTrimLeftEnd?.call(clip.id),
                    onTrimRightUpdate: track.isLocked ? null : (d) => onClipTrimRightUpdate?.call(clip.id, d),
                    onTrimRightEnd: track.isLocked ? null : () => onClipTrimRightEnd?.call(clip.id),
                  ),
                ),
              ),
            ),
          // Transition indicators + drop zones between adjacent clips
          for (int i = 0; i < sorted.length - 1; i++)
            _buildTransitionZone(sorted[i], sorted[i + 1], accent),
        ],
      ),
    );

    if (isDisabled) {
      content = Opacity(opacity: 0.3, child: content);
    }

    return content;
  }

  Widget _buildTransitionZone(VideoClip left, VideoClip right, Color accent) {
    final cutPoint = (left.timelineOut + right.timelineIn) / 2.0;
    final hasTransition = !left.transitionOut.isNone || !right.transitionIn.isNone;

    final transitionDur = hasTransition
        ? (left.transitionOut.isNone ? 0.0 : left.transitionOut.durationSeconds)
            .clamp(0.0, double.infinity) +
          (right.transitionIn.isNone ? 0.0 : right.transitionIn.durationSeconds)
              .clamp(0.0, double.infinity)
        : 0.0;
    final indicatorW = hasTransition
        ? (transitionDur * pixelsPerSecond).clamp(24.0, double.infinity)
        : 0.0;

    const dropZoneW = 28.0;
    final zoneW = hasTransition ? indicatorW.clamp(dropZoneW, double.infinity) : dropZoneW;
    final leftEdge = cutPoint * pixelsPerSecond - zoneW / 2;

    return Positioned(
      key: ValueKey('trz_${left.id}_${right.id}'),
      left: leftEdge,
      top: 0,
      width: zoneW,
      height: kTrackHeight - 1,
      child: _TransitionZone(
        leftClipId: left.id,
        rightClipId: right.id,
        accent: accent,
        hasTransition: hasTransition,
        transitionOut: left.transitionOut,
        transitionIn: right.transitionIn,
        indicatorWidth: indicatorW,
        onTransitionDrop: onTransitionDropBetween,
      ),
    );
  }
}

class _ClipDropTarget extends StatefulWidget {
  const _ClipDropTarget({
    required this.clipId,
    required this.accent,
    required this.child,
    this.onEffectDrop,
  });

  final int clipId;
  final Color accent;
  final Widget child;
  final void Function(int clipId, TimelineDragData data)? onEffectDrop;

  @override
  State<_ClipDropTarget> createState() => _ClipDropTargetState();
}

class _ClipDropTargetState extends State<_ClipDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<TimelineDragData>(
      onWillAcceptWithDetails: (_) {
        if (!_hovering) setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onEffectDrop?.call(widget.clipId, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: _hovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.accent, width: 2),
                  boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)],
                )
              : null,
          child: widget.child,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Transition zone between adjacent clips: visual indicator + drop target
// ---------------------------------------------------------------------------

class _TransitionZone extends StatefulWidget {
  const _TransitionZone({
    required this.leftClipId,
    required this.rightClipId,
    required this.accent,
    required this.hasTransition,
    required this.transitionOut,
    required this.transitionIn,
    required this.indicatorWidth,
    this.onTransitionDrop,
  });

  final int leftClipId;
  final int rightClipId;
  final Color accent;
  final bool hasTransition;
  final ClipTransition transitionOut;
  final ClipTransition transitionIn;
  final double indicatorWidth;
  final void Function(int leftClipId, int rightClipId, TransitionDragData data)? onTransitionDrop;

  @override
  State<_TransitionZone> createState() => _TransitionZoneState();
}

class _TransitionZoneState extends State<_TransitionZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<TimelineDragData>(
      onWillAcceptWithDetails: (details) {
        if (details.data is TransitionDragData) {
          if (!_hovering) setState(() => _hovering = true);
          return true;
        }
        return false;
      },
      onLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        final data = details.data;
        if (data is TransitionDragData) {
          widget.onTransitionDrop?.call(widget.leftClipId, widget.rightClipId, data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        if (widget.hasTransition) {
          return _TransitionIndicator(
            transitionOut: widget.transitionOut,
            transitionIn: widget.transitionIn,
            accent: widget.accent,
            hovering: _hovering,
          );
        }
        // Empty drop zone: show a subtle drop hint when dragging
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: _hovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: widget.accent.withValues(alpha: 0.15),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.6), width: 1.5),
                )
              : null,
          child: _hovering
              ? Center(
                  child: Icon(Icons.swap_horiz, size: 14, color: widget.accent.withValues(alpha: 0.8)),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _TransitionIndicator extends StatefulWidget {
  const _TransitionIndicator({
    required this.transitionOut,
    required this.transitionIn,
    required this.accent,
    this.hovering = false,
  });

  final ClipTransition transitionOut;
  final ClipTransition transitionIn;
  final Color accent;
  final bool hovering;

  @override
  State<_TransitionIndicator> createState() => _TransitionIndicatorState();
}

class _TransitionIndicatorState extends State<_TransitionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TransitionIndicator old) {
    super.didUpdateWidget(old);
    // Pause animation when TickerMode is disabled (e.g. off-screen)
    if (!TickerMode.of(context) && _anim.isAnimating) {
      _anim.stop();
    } else if (TickerMode.of(context) && !_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = !widget.transitionOut.isNone ? widget.transitionOut : widget.transitionIn;
    final label = active.type.label;
    final dur = '${active.durationSeconds.toStringAsFixed(1)}s';
    const color = Color(0xFF26C6DA);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return CustomPaint(
            painter: _TransitionDiamondPainter(
              color: widget.hovering ? widget.accent : color,
              phase: _anim.value,
            ),
            child: child,
          );
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz, size: 10, color: color),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dur,
                  style: TextStyle(
                    fontSize: 6,
                    color: color.withValues(alpha: 0.7),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitionDiamondPainter extends CustomPainter {
  _TransitionDiamondPainter({required this.color, required this.phase});

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hw = size.width / 2;
    final hh = size.height / 2 - 2;

    // Diamond / bowtie path
    final path = Path()
      ..moveTo(cx, cy - hh)
      ..lineTo(cx + hw, cy)
      ..lineTo(cx, cy + hh)
      ..lineTo(cx - hw, cy)
      ..close();

    // Animated gradient fill
    final shimmerCenter = phase * 1.4 - 0.2;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: 0.10),
        color.withValues(alpha: 0.30),
        color.withValues(alpha: 0.10),
      ],
      stops: [
        (shimmerCenter - 0.3).clamp(0.0, 1.0),
        shimmerCenter.clamp(0.0, 1.0),
        (shimmerCenter + 0.3).clamp(0.0, 1.0),
      ],
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withValues(alpha: 0.5),
    );

    // Animated pulse glow dots at the left and right tips
    final glowAlpha = (math.sin(phase * math.pi * 2) * 0.3 + 0.4).clamp(0.0, 1.0);
    final dotPaint = Paint()..color = color.withValues(alpha: glowAlpha);
    canvas.drawCircle(Offset(cx - hw + 1, cy), 1.5, dotPaint);
    canvas.drawCircle(Offset(cx + hw - 1, cy), 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(_TransitionDiamondPainter old) =>
      old.color != color || old.phase != phase;
}
