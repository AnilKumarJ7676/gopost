import 'package:flutter/material.dart';

const double _kSplitterThickness = 6.0;
const Color _kSplitterColor = Color(0xFF252540);
const Color _kSplitterHoverColor = Color(0xFF6C63FF);
const Color _kHandleColor = Color(0xFF404060);

// =============================================================================
// Horizontal Split: top/bottom panels with a draggable horizontal divider
// =============================================================================

class HorizontalSplit extends StatefulWidget {
  final Widget top;
  final Widget bottom;
  final double fraction;
  final double minTopFraction;
  final double maxTopFraction;
  final ValueChanged<double> onFractionChanged;
  final VoidCallback? onDoubleTap;

  const HorizontalSplit({
    super.key,
    required this.top,
    required this.bottom,
    required this.fraction,
    this.minTopFraction = 0.15,
    this.maxTopFraction = 0.85,
    required this.onFractionChanged,
    this.onDoubleTap,
  });

  @override
  State<HorizontalSplit> createState() => _HorizontalSplitState();
}

class _HorizontalSplitState extends State<HorizontalSplit> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxHeight;
        final splitter = _kSplitterThickness;
        final available = total - splitter;
        final topH = (available * widget.fraction).clamp(0.0, available);
        final bottomH = available - topH;

        return Column(
          children: [
            SizedBox(height: topH, child: widget.top),
            _buildSplitter(total),
            SizedBox(height: bottomH, child: widget.bottom),
          ],
        );
      },
    );
  }

  Widget _buildSplitter(double totalHeight) {
    final isActive = _hovering || _dragging;
    return GestureDetector(
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: (d) {
        final delta = d.delta.dy;
        final newFrac = widget.fraction + delta / (totalHeight - _kSplitterThickness);
        widget.onFractionChanged(
          newFrac.clamp(widget.minTopFraction, widget.maxTopFraction),
        );
      },
      onVerticalDragEnd: (_) => setState(() => _dragging = false),
      onDoubleTap: widget.onDoubleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Container(
          height: _kSplitterThickness,
          color: isActive ? _kSplitterHoverColor : _kSplitterColor,
          child: Center(
            child: Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.6) : _kHandleColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Vertical Split: left/right panels with a draggable vertical divider
// =============================================================================

class VerticalSplit extends StatefulWidget {
  final Widget left;
  final Widget right;

  /// Left panel width in pixels.
  final double leftWidth;
  final double minLeftWidth;
  final double maxLeftWidth;
  final ValueChanged<double> onLeftWidthChanged;
  final VoidCallback? onDoubleTap;

  /// If true, left panel collapses when dragged below threshold.
  final double collapseThreshold;

  const VerticalSplit({
    super.key,
    required this.left,
    required this.right,
    required this.leftWidth,
    this.minLeftWidth = 0,
    this.maxLeftWidth = 600,
    required this.onLeftWidthChanged,
    this.onDoubleTap,
    this.collapseThreshold = 80,
  });

  @override
  State<VerticalSplit> createState() => _VerticalSplitState();
}

class _VerticalSplitState extends State<VerticalSplit> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final leftW = widget.leftWidth.clamp(0.0, widget.maxLeftWidth);

    // If collapsed, don't show left panel
    if (leftW < 1) {
      return Row(
        children: [
          _buildSplitter(),
          Expanded(child: widget.right),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: leftW, child: widget.left),
        _buildSplitter(),
        Expanded(child: widget.right),
      ],
    );
  }

  Widget _buildSplitter() {
    final isActive = _hovering || _dragging;
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (d) {
        var newWidth = widget.leftWidth + d.delta.dx;
        // Snap to collapsed
        if (newWidth < widget.collapseThreshold) {
          newWidth = 0;
        }
        widget.onLeftWidthChanged(
          newWidth.clamp(widget.minLeftWidth, widget.maxLeftWidth),
        );
      },
      onHorizontalDragEnd: (_) => setState(() => _dragging = false),
      onDoubleTap: widget.onDoubleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Container(
          width: _kSplitterThickness,
          color: isActive ? _kSplitterHoverColor : _kSplitterColor,
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.6) : _kHandleColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Track splitter: between individual tracks in the timeline
// =============================================================================

class TrackSplitter extends StatefulWidget {
  final int trackIndex;
  final ValueChanged<double> onDrag;
  final VoidCallback? onDoubleTap;

  const TrackSplitter({
    super.key,
    required this.trackIndex,
    required this.onDrag,
    this.onDoubleTap,
  });

  @override
  State<TrackSplitter> createState() => _TrackSplitterState();
}

class _TrackSplitterState extends State<TrackSplitter> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _hovering || _dragging;
    return GestureDetector(
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => setState(() => _dragging = false),
      onDoubleTap: widget.onDoubleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Container(
          height: 4,
          color: isActive ? _kSplitterHoverColor.withValues(alpha: 0.6) : const Color(0xFF1E1E38),
          child: Center(
            child: Container(
              width: 24,
              height: 1.5,
              decoration: BoxDecoration(
                color: isActive ? _kSplitterHoverColor : const Color(0xFF353550),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
