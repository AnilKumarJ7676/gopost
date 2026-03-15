import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

/// Flutter widget for keyframe animation editing.
class KeyframeEditor extends ConsumerStatefulWidget {
  const KeyframeEditor({super.key});

  @override
  ConsumerState<KeyframeEditor> createState() => _KeyframeEditorState();
}

class _KeyframeEditorState extends ConsumerState<KeyframeEditor> {
  KeyframeProperty _selectedProperty = KeyframeProperty.positionX;
  double? _selectedKeyframeTime;
  VideoProject? _beforeDrag;

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(timelineNotifierProvider.select((s) => s.selectedClip));
    final playheadPos = ref.watch(timelineNotifierProvider.select((s) => s.playback.positionSeconds));
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final hasClip = clip != null;
    final track = clip?.keyframes.trackFor(_selectedProperty);
    final keyframes = track?.keyframes ?? [];
    final selectedKf = _selectedKeyframeTime != null
        ? keyframes.where((k) => k.time == _selectedKeyframeTime).firstOrNull
        : null;
    final clipStart = clip?.timelineIn ?? 0.0;
    final clipEnd = clip?.timelineOut ?? 10.0;

    return Container(
      color: scheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasClip)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Select a clip to edit keyframes',
                    style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            ),
          // Property selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: KeyframeProperty.values.map((prop) {
                final isSelected = _selectedProperty == prop;
                return FilterChip(
                  selected: isSelected,
                  label: Text(prop.label, style: const TextStyle(fontSize: 14)),
                  onSelected: (_) {
                    setState(() {
                      _selectedProperty = prop;
                      _selectedKeyframeTime = null;
                    });
                  },
                  selectedColor: scheme.primaryContainer,
                  checkmarkColor: scheme.onPrimaryContainer,
                );
              }).toList(),
            ),
          ),
          // Timeline strip + Add Keyframe
          IgnorePointer(
            ignoring: !hasClip,
            child: Opacity(
              opacity: hasClip ? 1.0 : 0.45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SizedBox(
                      height: 48,
                      child: _KeyframeStrip(
                        clipStart: clipStart,
                        clipEnd: clipEnd,
                        keyframes: keyframes,
                        selectedTime: _selectedKeyframeTime,
                        playheadPos: playheadPos,
                        onKeyframeTap: (time) {
                          setState(() {
                            _selectedKeyframeTime =
                                _selectedKeyframeTime == time ? null : time;
                          });
                        },
                        onTrackTap: () {
                          setState(() => _selectedKeyframeTime = null);
                        },
                        onKeyframeDrag: (oldTime, newTime) {
                          if (!hasClip) return;
                          _beforeDrag ??= ref.read(timelineNotifierProvider).project;
                          final kf = keyframes.where((k) => k.time == oldTime).firstOrNull;
                          if (kf == null) return;
                          notifier.moveKeyframe(
                            clip!.id, _selectedProperty,
                            oldTime, newTime, kf.value,
                          );
                          setState(() => _selectedKeyframeTime = newTime);
                        },
                        onKeyframeDragEnd: () {
                          if (_beforeDrag != null && hasClip) {
                            notifier.commitKeyframeMove(clip!.id, _beforeDrag!);
                            _beforeDrag = null;
                          }
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: FilledButton.icon(
                      onPressed: !hasClip ? null : () {
                        if (playheadPos >= clipStart && playheadPos <= clipEnd) {
                          final kfTrack = clip!.keyframes.trackFor(_selectedProperty);
                          final defaultValue = _selectedProperty.defaultValue;
                          final prevValue = kfTrack?.evaluate(playheadPos) ?? defaultValue;
                          notifier.addKeyframe(
                            clip.id,
                            _selectedProperty,
                            Keyframe(time: playheadPos, value: prevValue),
                          );
                          setState(() => _selectedKeyframeTime = playheadPos);
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Keyframe'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Selected keyframe editor
          if (selectedKf != null && hasClip) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Keyframe at ${selectedKf.time.toStringAsFixed(2)}s',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          selectedKf.value.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: selectedKf.value,
                          min: _minForProperty(_selectedProperty),
                          max: _maxForProperty(_selectedProperty),
                          onChanged: (v) {
                            notifier.addKeyframe(
                              clip!.id,
                              _selectedProperty,
                              selectedKf.copyWith(value: v),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interpolation',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: KeyframeInterpolation.values.map((interp) {
                      final isSelected = selectedKf.interpolation == interp;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(interp.label, style: const TextStyle(fontSize: 11)),
                        onSelected: (_) {
                          notifier.addKeyframe(
                            clip!.id,
                            _selectedProperty,
                            selectedKf.copyWith(interpolation: interp),
                          );
                        },
                        selectedColor: scheme.primaryContainer,
                        checkmarkColor: scheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          notifier.removeKeyframe(
                            clip!.id,
                            _selectedProperty,
                            selectedKf.time,
                          );
                          setState(() => _selectedKeyframeTime = null);
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete Keyframe'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          notifier.clearKeyframes(clip!.id, _selectedProperty);
                          setState(() => _selectedKeyframeTime = null);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _minForProperty(KeyframeProperty prop) {
    return switch (prop) {
      KeyframeProperty.scale => 0.0,
      KeyframeProperty.opacity => 0.0,
      KeyframeProperty.volume => 0.0,
      _ => -2.0,
    };
  }

  double _maxForProperty(KeyframeProperty prop) {
    return switch (prop) {
      KeyframeProperty.scale => 3.0,
      KeyframeProperty.opacity => 1.0,
      KeyframeProperty.volume => 2.0,
      _ => 2.0,
    };
  }
}

class _KeyframeStrip extends StatelessWidget {
  const _KeyframeStrip({
    required this.clipStart,
    required this.clipEnd,
    required this.keyframes,
    required this.selectedTime,
    required this.playheadPos,
    required this.onKeyframeTap,
    required this.onTrackTap,
    this.onKeyframeDrag,
    this.onKeyframeDragEnd,
  });

  final double clipStart;
  final double clipEnd;
  final List<Keyframe> keyframes;
  final double? selectedTime;
  final double playheadPos;
  final void Function(double time) onKeyframeTap;
  final void Function() onTrackTap;
  final void Function(double oldTime, double newTime)? onKeyframeDrag;
  final void Function()? onKeyframeDragEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final duration = clipEnd - clipStart;
        const padding = 20.0;
        final trackWidth = constraints.maxWidth - padding * 2;

        double xToTime(double x) {
          final t = (x - padding) / trackWidth;
          return clipStart + t.clamp(0.0, 1.0) * duration;
        }

        Keyframe? hitTest(double x) {
          if (x < padding || x > constraints.maxWidth - padding) return null;
          final tapTime = xToTime(x);
          const hitRadius = 12.0;
          final hitTimeRange = (hitRadius / trackWidth) * duration;
          for (final kf in keyframes) {
            if ((kf.time - tapTime).abs() <= hitTimeRange) return kf;
          }
          return null;
        }

        double? dragStartTime;

        return GestureDetector(
          onTapDown: (details) {
            final hit = hitTest(details.localPosition.dx);
            if (hit != null) {
              onKeyframeTap(hit.time);
            } else {
              onTrackTap();
            }
          },
          onHorizontalDragStart: (details) {
            final hit = hitTest(details.localPosition.dx);
            if (hit != null) {
              dragStartTime = hit.time;
              onKeyframeTap(hit.time);
            }
          },
          onHorizontalDragUpdate: (details) {
            if (dragStartTime != null && onKeyframeDrag != null) {
              final newTime = xToTime(details.localPosition.dx);
              onKeyframeDrag!(dragStartTime!, newTime);
              dragStartTime = newTime;
            }
          },
          onHorizontalDragEnd: (_) {
            if (dragStartTime != null) {
              onKeyframeDragEnd?.call();
              dragStartTime = null;
            }
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _KeyframeStripPainter(
              clipStart: clipStart,
              clipEnd: clipEnd,
              keyframes: keyframes,
              selectedTime: selectedTime,
              playheadPos: playheadPos,
              colorScheme: Theme.of(context).colorScheme,
            ),
          ),
        );
      },
    );
  }
}

class _KeyframeStripPainter extends CustomPainter {
  _KeyframeStripPainter({
    required this.clipStart,
    required this.clipEnd,
    required this.keyframes,
    required this.selectedTime,
    required this.playheadPos,
    required this.colorScheme,
  });

  final double clipStart;
  final double clipEnd;
  final List<Keyframe> keyframes;
  final double? selectedTime;
  final double playheadPos;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final scheme = colorScheme;
    final duration = clipEnd - clipStart;
    if (duration <= 0) return;

    const padding = 20.0;
    final trackWidth = size.width - padding * 2;
    final centerY = size.height / 2;

    double timeToX(double t) =>
        padding + ((t - clipStart) / duration).clamp(0.0, 1.0) * trackWidth;

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = scheme.surfaceContainerHighest,
    );

    // Horizontal line
    final linePaint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(padding, centerY), Offset(size.width - padding, centerY), linePaint);

    // Interpolation curves between keyframes
    if (keyframes.length >= 2) {
      final curvePaint = Paint()
        ..color = scheme.primary.withValues(alpha: 0.4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = ui.Path();
      for (int i = 0; i < keyframes.length; i++) {
        final kf = keyframes[i];
        final x = timeToX(kf.time);
        final y = centerY - (kf.value.clamp(0.0, 2.0) / 2) * (centerY - 4);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, curvePaint);
    }

    // Playhead
    final playheadX = timeToX(playheadPos);
    if (playheadX >= padding && playheadX <= size.width - padding) {
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = scheme.primary
          ..strokeWidth = 2,
      );
    }

    // Diamond markers
    const diamondSize = 8.0;
    for (final kf in keyframes) {
      final x = timeToX(kf.time);
      final isSelected = selectedTime != null && (kf.time - selectedTime!).abs() < 0.001;
      _drawDiamond(canvas, Offset(x, centerY), diamondSize,
          isSelected ? scheme.primary : scheme.onSurfaceVariant);
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Color color) {
    final path = ui.Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _KeyframeStripPainter oldDelegate) {
    return oldDelegate.clipStart != clipStart ||
        oldDelegate.clipEnd != clipEnd ||
        oldDelegate.keyframes != keyframes ||
        oldDelegate.selectedTime != selectedTime ||
        oldDelegate.playheadPos != playheadPos ||
        oldDelegate.colorScheme != colorScheme;
  }
}
