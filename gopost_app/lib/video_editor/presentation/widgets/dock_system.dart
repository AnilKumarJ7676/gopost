import 'package:flutter/material.dart';

import 'package:gopost_app/video_editor/domain/models/editor_layout_state.dart';

// =============================================================================
// Dockable Panel Header — supports drag-to-undock + double-click maximize
// =============================================================================

class DockablePanelHeader extends StatefulWidget {
  final String panelId;
  final String title;
  final bool isMaximized;
  final VoidCallback? onMaximize;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onUndock;
  final VoidCallback? onClose;

  const DockablePanelHeader({
    super.key,
    required this.panelId,
    required this.title,
    this.isMaximized = false,
    this.onMaximize,
    this.onDragUpdate,
    this.onDragEnd,
    this.onUndock,
    this.onClose,
  });

  @override
  State<DockablePanelHeader> createState() => _DockablePanelHeaderState();
}

class _DockablePanelHeaderState extends State<DockablePanelHeader> {
  bool _isDragging = false;
  Offset _dragStartOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onMaximize,
      onPanStart: (d) {
        _isDragging = false;
        _dragStartOffset = d.globalPosition;
      },
      onPanUpdate: (d) {
        final distance = (d.globalPosition - _dragStartOffset).distance;
        if (!_isDragging && distance > 10) {
          _isDragging = true;
          widget.onUndock?.call();
        }
        if (_isDragging) {
          widget.onDragUpdate?.call(
            DragUpdateDetails(
              globalPosition: d.globalPosition,
              delta: d.delta,
            ),
          );
        }
      },
      onPanEnd: (_) {
        if (_isDragging) {
          _isDragging = false;
          widget.onDragEnd?.call();
        }
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF16162E),
          border: Border(bottom: BorderSide(color: Color(0xFF252540), width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 14, color: Color(0xFF505068)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD0D0E8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onMaximize != null)
              _HeaderButton(
                icon: widget.isMaximized
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: widget.isMaximized ? 'Restore' : 'Maximize',
                onTap: widget.onMaximize!,
              ),
            if (widget.onClose != null)
              _HeaderButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onTap: widget.onClose!,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: const Color(0xFF8888A0)),
        ),
      ),
    );
  }
}

// =============================================================================
// Floating Panel — overlaid on top of the editor when undocked
// =============================================================================

class FloatingPanel extends StatefulWidget {
  final FloatingPanelState panelState;
  final Widget child;
  final String title;
  final ValueChanged<FloatingPanelState> onStateChanged;
  final VoidCallback? onClose;
  final VoidCallback? onRedock;

  const FloatingPanel({
    super.key,
    required this.panelState,
    required this.child,
    required this.title,
    required this.onStateChanged,
    this.onClose,
    this.onRedock,
  });

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel> {
  late double _x;
  late double _y;
  late double _w;
  late double _h;

  @override
  void initState() {
    super.initState();
    _x = widget.panelState.x;
    _y = widget.panelState.y;
    _w = widget.panelState.width;
    _h = widget.panelState.height;
  }

  @override
  void didUpdateWidget(covariant FloatingPanel old) {
    super.didUpdateWidget(old);
    if (old.panelState != widget.panelState) {
      _x = widget.panelState.x;
      _y = widget.panelState.y;
      _w = widget.panelState.width;
      _h = widget.panelState.height;
    }
  }

  void _emitState() {
    widget.onStateChanged(widget.panelState.copyWith(
      x: _x,
      y: _y,
      width: _w,
      height: _h,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: const Color(0xFF12122A),
            border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), width: 1),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Title bar — drag to move
              GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _x += d.delta.dx;
                    _y += d.delta.dy;
                  });
                },
                onPanEnd: (_) => _emitState(),
                onDoubleTap: widget.onRedock,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A38),
                    border: Border(bottom: BorderSide(color: Color(0xFF252540))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator_rounded, size: 12, color: Color(0xFF505068)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD0D0E8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.onRedock != null)
                        _HeaderButton(
                          icon: Icons.push_pin_outlined,
                          tooltip: 'Re-dock',
                          onTap: widget.onRedock!,
                        ),
                      if (widget.onClose != null)
                        _HeaderButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: widget.onClose!,
                        ),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(child: widget.child),
              // Resize handle (bottom-right corner)
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      _w = (_w + d.delta.dx).clamp(200.0, 800.0);
                      _h = (_h + d.delta.dy).clamp(150.0, 800.0);
                    });
                  },
                  onPanEnd: (_) => _emitState(),
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: Icon(Icons.open_in_full_rounded, size: 10, color: Color(0xFF505068)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Dock Zone Highlight — shown when dragging a panel over a valid dock target
// =============================================================================

class DockZoneOverlay extends StatelessWidget {
  final bool isActive;
  final String label;

  const DockZoneOverlay({
    super.key,
    this.isActive = false,
    this.label = 'Drop to dock',
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab Group Widget — multiple panels as tabs
// =============================================================================

class DockTabGroup extends StatelessWidget {
  final List<String> tabLabels;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int>? onTabClosed;
  final void Function(int oldIndex, int newIndex)? onTabReordered;
  final Widget child;

  const DockTabGroup({
    super.key,
    required this.tabLabels,
    required this.activeIndex,
    required this.onTabSelected,
    this.onTabClosed,
    this.onTabReordered,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E1C),
            border: Border(bottom: BorderSide(color: Color(0xFF252540), width: 1)),
          ),
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            itemCount: tabLabels.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              onTabReordered?.call(oldIndex, newIndex);
            },
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final isActive = index == activeIndex;
              return ReorderableDragStartListener(
                key: ValueKey('tab_$index'),
                index: index,
                child: GestureDetector(
                  onTap: () => onTabSelected(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF12122A) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? const Color(0xFF6C63FF) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabLabels[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? const Color(0xFFD0D0E8) : const Color(0xFF6B6B88),
                          ),
                        ),
                        if (onTabClosed != null && tabLabels.length > 1) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => onTabClosed!(index),
                            borderRadius: BorderRadius.circular(3),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 10,
                                color: isActive ? const Color(0xFF8888A0) : const Color(0xFF505068),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Content
        Expanded(child: child),
      ],
    );
  }
}

// =============================================================================
// Layout Preset Selector
// =============================================================================

class LayoutPresetSelector extends StatelessWidget {
  final LayoutPreset activePreset;
  final ValueChanged<LayoutPreset> onPresetSelected;
  final VoidCallback? onSaveCustom;

  const LayoutPresetSelector({
    super.key,
    required this.activePreset,
    required this.onPresetSelected,
    this.onSaveCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final preset in LayoutPreset.values) ...[
          _PresetChip(
            label: preset.name[0].toUpperCase() + preset.name.substring(1),
            isActive: activePreset == preset,
            onTap: () => onPresetSelected(preset),
          ),
          const SizedBox(width: 4),
        ],
        if (onSaveCustom != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Save current layout',
            child: InkWell(
              onTap: onSaveCustom,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: const Icon(Icons.save_outlined, size: 14, color: Color(0xFF6B6B88)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF353550),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF8888A0),
          ),
        ),
      ),
    );
  }
}
