import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/domain/models/video_transition.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

/// Icon mapping for each transition type (excluding none).
IconData _iconForTransition(TransitionType type) {
  return switch (type) {
    TransitionType.fade => Icons.gradient,
    TransitionType.dissolve => Icons.blur_on,
    TransitionType.slideLeft => Icons.arrow_back,
    TransitionType.slideRight => Icons.arrow_forward,
    TransitionType.slideUp => Icons.arrow_upward,
    TransitionType.slideDown => Icons.arrow_downward,
    TransitionType.wipeLeft => Icons.swipe_left,
    TransitionType.wipeRight => Icons.swipe_right,
    TransitionType.wipeUp => Icons.swipe_up,
    TransitionType.wipeDown => Icons.swipe_down,
    TransitionType.zoom => Icons.zoom_in,
    TransitionType.push => Icons.open_with,
    TransitionType.reveal => Icons.visibility,
    TransitionType.iris => Icons.radio_button_unchecked,
    TransitionType.clock => Icons.access_time,
    TransitionType.blur => Icons.blur_circular,
    TransitionType.glitch => Icons.broken_image,
    TransitionType.morph => Icons.transform,
    TransitionType.flash => Icons.flash_on,
    TransitionType.spin => Icons.rotate_right,
    TransitionType.none => Icons.circle_outlined,
  };
}

/// All transition types except none, for the grid.
final _transitionTypes = TransitionType.values.where((t) => t != TransitionType.none).toList();

class TransitionPicker extends ConsumerWidget {
  const TransitionPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final clipId = ref.watch(timelineNotifierProvider.select((s) => s.selectedClipId));
    final clip = ref.watch(timelineNotifierProvider.select((s) => s.selectedClip));
    final hasClip = clipId != null && clip != null;
    const defaultTransition = ClipTransition();

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasClip)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    'Select a clip to add transitions',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
                  ),
                ],
              ),
            ),
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.7),
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(text: 'Transition In'),
              Tab(text: 'Transition Out'),
            ],
          ),
          Expanded(
            child: IgnorePointer(
              ignoring: !hasClip,
              child: Opacity(
                opacity: hasClip ? 1.0 : 0.45,
                child: TabBarView(
                  children: [
                    _TransitionPanel(
                      clipId: clipId ?? 0,
                      current: clip?.transitionIn ?? defaultTransition,
                      isIn: true,
                    ),
                    _TransitionPanel(
                      clipId: clipId ?? 0,
                      current: clip?.transitionOut ?? defaultTransition,
                      isIn: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransitionPanel extends ConsumerStatefulWidget {
  final int clipId;
  final ClipTransition current;
  final bool isIn;

  const _TransitionPanel({
    required this.clipId,
    required this.current,
    required this.isIn,
  });

  @override
  ConsumerState<_TransitionPanel> createState() => _TransitionPanelState();
}

class _TransitionPanelState extends ConsumerState<_TransitionPanel> {
  late double _duration;
  late EasingCurve _easing;

  @override
  void initState() {
    super.initState();
    _duration = widget.current.durationSeconds;
    _easing = widget.current.easing;
  }

  @override
  void didUpdateWidget(_TransitionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clipId != widget.clipId || oldWidget.current != widget.current) {
      _duration = widget.current.durationSeconds;
      _easing = widget.current.easing;
    }
  }

  void _applyTransition(TransitionType type) {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final transition = ClipTransition(
      type: type,
      durationSeconds: _duration,
      easing: _easing,
    );
    if (widget.isIn) {
      notifier.setTransitionIn(widget.clipId, transition);
    } else {
      notifier.setTransitionOut(widget.clipId, transition);
    }
  }

  void _setDuration(double d) {
    setState(() => _duration = d);
    final t = widget.current.type;
    if (t != TransitionType.none) {
      _applyTransition(t);
    }
  }

  void _setEasing(EasingCurve e) {
    setState(() => _easing = e);
    final t = widget.current.type;
    if (t != TransitionType.none) {
      _applyTransition(t);
    }
  }

  void _removeTransition() {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    if (widget.isIn) {
      notifier.removeTransitionIn(widget.clipId);
    } else {
      notifier.removeTransitionOut(widget.clipId);
    }
    setState(() {
      _duration = 0.5;
      _easing = EasingCurve.easeInOut;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentType = widget.current.type;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grid of transition types
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.72,
            ),
            itemCount: _transitionTypes.length,
            itemBuilder: (context, index) {
              final type = _transitionTypes[index];
              final isActive = currentType == type;
              return _TransitionGridItem(
                type: type,
                isActive: isActive,
                isIn: widget.isIn,
                onTap: () => _applyTransition(type),
              );
            },
          ),
          const SizedBox(height: 20),
          // Duration slider
          Text(
            'Duration: ${_duration.toStringAsFixed(1)}s',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          Slider(
            value: _duration,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            onChanged: (v) => _setDuration(v),
          ),
          const SizedBox(height: 12),
          // Easing curve selector
          Text(
            'Easing',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EasingCurve.values.map((e) {
              final selected = _easing == e;
              return NeonChip(
                label: e.label,
                selected: selected,
                onSelected: (_) => _setEasing(e),
                activeColor: colorScheme.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Remove transition button
          OutlinedButton.icon(
            onPressed: currentType == TransitionType.none
                ? null
                : _removeTransition,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            label: const Text('Remove Transition'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransitionGridItem extends StatelessWidget {
  final TransitionType type;
  final bool isActive;
  final bool isIn;
  final VoidCallback onTap;

  const _TransitionGridItem({
    required this.type,
    required this.isActive,
    required this.isIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = _iconForTransition(type);

    final gridContent = NeonGlow(
      isActive: isActive,
      baseColor: colorScheme.primary,
      borderRadius: 8,
      glowSpread: 1.5,
      glowBlur: 10,
      child: Material(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 26, color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return LongPressDraggable<TimelineDragData>(
      data: TransitionDragData(transitionType: type, icon: icon, isIn: isIn),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(type.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: gridContent),
      child: gridContent,
    );
  }
}
