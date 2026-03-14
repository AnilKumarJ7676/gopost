import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

const _speedPresets = <double>[0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 8.0];

class SpeedControlsPanel extends ConsumerStatefulWidget {
  const SpeedControlsPanel({super.key});

  @override
  ConsumerState<SpeedControlsPanel> createState() => _SpeedControlsPanelState();
}

class _SpeedControlsPanelState extends ConsumerState<SpeedControlsPanel> {
  double _customSpeed = 1.0;
  bool _isDraggingSlider = false;
  double? _lastSyncedSpeed;

  @override
  Widget build(BuildContext context) {
    final clipId = ref.watch(timelineNotifierProvider.select((s) => s.selectedClipId));
    final project = ref.watch(timelineNotifierProvider.select((s) => s.project));
    final clip = clipId != null && project != null ? project.findClip(clipId) : null;
    final hasClip = clip != null;
    final speed = clip?.speed ?? 1.0;
    final duration = clip?.duration ?? 0.0;
    final resolvedClipId = clip?.id ?? 0;
    final hasSpeedRamp = clip?.keyframes.trackFor(KeyframeProperty.speed) != null &&
        (clip?.keyframes.trackFor(KeyframeProperty.speed)?.keyframes.isNotEmpty ?? false);

    if (!_isDraggingSlider && _lastSyncedSpeed != speed) {
      _customSpeed = speed.abs();
      _lastSyncedSpeed = speed;
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (!hasClip)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF6B6B88)),
                SizedBox(width: 6),
                Text('Select a clip to adjust speed', style: TextStyle(fontSize: 13, color: Color(0xFF6B6B88))),
              ],
            ),
          ),
        IgnorePointer(
          ignoring: !hasClip,
          child: Opacity(
            opacity: hasClip ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentInfo(speed, duration, hasSpeedRamp),
                const SizedBox(height: 14),
                _SectionLabel('Speed Presets'),
                const SizedBox(height: 8),
                _buildSpeedGrid(resolvedClipId, speed),
                const SizedBox(height: 14),
                _SectionLabel('Custom Speed'),
                const SizedBox(height: 8),
                _buildCustomSlider(resolvedClipId),
                const SizedBox(height: 16),
                _SectionLabel('Special'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SpecialBtn(
                        icon: Icons.replay_rounded,
                        label: 'Reverse',
                        isActive: speed < 0,
                        color: const Color(0xFFAB47BC),
                        onTap: () { if (hasClip) ref.read(timelineNotifierProvider.notifier).reverseClip(clip.id); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SpecialBtn(
                        icon: Icons.pause_circle_outline_rounded,
                        label: 'Freeze Frame',
                        color: const Color(0xFF26C6DA),
                        onTap: () { if (hasClip) ref.read(timelineNotifierProvider.notifier).freezeFrame(clip.id); },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionLabel('Rate Stretch'),
                const SizedBox(height: 8),
                _buildRateStretchControls(resolvedClipId, duration),
                const SizedBox(height: 16),
                _SectionLabel('Speed Ramp Presets'),
                const SizedBox(height: 8),
                _buildSpeedRampPresets(resolvedClipId, hasSpeedRamp),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentInfo(double speed, double duration, bool hasSpeedRamp) {
    final isReverse = speed < 0;
    final absSpeed = speed.abs();
    final label = isReverse ? '${absSpeed}x (Reverse)' : '${absSpeed}x';
    final newDuration = absSpeed > 0 ? duration / absSpeed : duration;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF303050)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${absSpeed}x',
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE0E0F0))),
                Text('Duration: ${_formatDuration(newDuration)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8888A0))),
                if (hasSpeedRamp)
                  const Text('Speed ramp active',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFFF7043))),
              ],
            ),
          ),
          if (isReverse)
            const Icon(Icons.replay_rounded, size: 18, color: Color(0xFFAB47BC)),
          if (hasSpeedRamp)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.graphic_eq_rounded, size: 18, color: Color(0xFFFF7043)),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedGrid(int clipId, double currentSpeed) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _speedPresets.map((speed) {
        final isActive = (currentSpeed.abs() - speed).abs() < 0.01;
        final isSlowMo = speed < 1.0;
        final isFast = speed > 1.0;
        final color = isSlowMo
            ? const Color(0xFF26C6DA)
            : isFast
                ? const Color(0xFFFF7043)
                : const Color(0xFF6C63FF);

        return GestureDetector(
          onTap: () {
            ref.read(timelineNotifierProvider.notifier).setClipSpeed(
              clipId, currentSpeed < 0 ? -speed : speed,
            );
          },
          child: Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.2) : const Color(0xFF1A1A34),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? color : const Color(0xFF303050),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${speed}x',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isActive ? color : const Color(0xFFB0B0C8),
                  ),
                ),
                if (isSlowMo)
                  Text('slow', style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.6)))
                else if (isFast)
                  Text('fast', style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.6))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomSlider(int clipId) {
    return Column(
      children: [
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: _customSpeed.clamp(0.1, 8.0),
            min: 0.1,
            max: 8.0,
            divisions: 79,
            label: '${_customSpeed.toStringAsFixed(2)}x',
            onChanged: (v) => setState(() {
              _isDraggingSlider = true;
              _customSpeed = v;
            }),
            onChangeEnd: (v) {
              _isDraggingSlider = false;
              final state = ref.read(timelineNotifierProvider);
              final clip = state.selectedClip;
              if (clip != null) {
                final sign = clip.speed < 0 ? -1 : 1;
                ref.read(timelineNotifierProvider.notifier).setClipSpeed(clip.id, v * sign);
              }
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0.1x', style: TextStyle(fontSize: 11, color: Color(0xFF6B6B88))),
            Text(
              '${_customSpeed.toStringAsFixed(2)}x',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFF6C63FF)),
            ),
            const Text('8.0x', style: TextStyle(fontSize: 11, color: Color(0xFF6B6B88))),
          ],
        ),
      ],
    );
  }

  Widget _buildRateStretchControls(int clipId, double duration) {
    return Row(
      children: [
        for (final factor in [0.5, 0.75, 1.5, 2.0])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _StretchBtn(
                label: '${factor}x dur',
                onTap: () {
                  ref.read(timelineNotifierProvider.notifier).rateStretch(clipId, duration * factor);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpeedRampPresets(int clipId, bool hasSpeedRamp) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _RampPresetBtn(
                label: 'Ramp Up',
                subtitle: '0.5x → 2.0x',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFFF7043),
                onTap: () => _applySpeedRamp(clipId, 0.5, 2.0),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _RampPresetBtn(
                label: 'Ramp Down',
                subtitle: '2.0x → 0.5x',
                icon: Icons.trending_down_rounded,
                color: const Color(0xFF26C6DA),
                onTap: () => _applySpeedRamp(clipId, 2.0, 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _RampPresetBtn(
                label: 'Pulse',
                subtitle: '1x → 3x → 1x',
                icon: Icons.graphic_eq_rounded,
                color: const Color(0xFFAB47BC),
                onTap: () => _applyPulseRamp(clipId),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _RampPresetBtn(
                label: 'Slow-mo Hit',
                subtitle: '1x → 0.2x → 1x',
                icon: Icons.slow_motion_video_rounded,
                color: const Color(0xFF66BB6A),
                onTap: () => _applySlowMoHit(clipId),
              ),
            ),
          ],
        ),
        if (hasSpeedRamp) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: TextButton.icon(
              onPressed: () => ref.read(timelineNotifierProvider.notifier).clearSpeedRamp(clipId),
              icon: const Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFFEF5350)),
              label: const Text('Clear Speed Ramp',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFEF5350))),
            ),
          ),
        ],
      ],
    );
  }

  void _applySpeedRamp(int clipId, double startSpeed, double endSpeed) {
    ref.read(timelineNotifierProvider.notifier).applySpeedRamp(clipId, [
      (position: 0.0, speed: startSpeed),
      (position: 1.0, speed: endSpeed),
    ]);
  }

  void _applyPulseRamp(int clipId) {
    ref.read(timelineNotifierProvider.notifier).applySpeedRamp(clipId, [
      (position: 0.0, speed: 1.0),
      (position: 0.25, speed: 3.0),
      (position: 0.5, speed: 1.0),
      (position: 0.75, speed: 3.0),
      (position: 1.0, speed: 1.0),
    ]);
  }

  void _applySlowMoHit(int clipId) {
    ref.read(timelineNotifierProvider.notifier).applySpeedRamp(clipId, [
      (position: 0.0, speed: 1.0),
      (position: 0.3, speed: 1.0),
      (position: 0.4, speed: 0.2),
      (position: 0.6, speed: 0.2),
      (position: 0.7, speed: 1.0),
      (position: 1.0, speed: 1.0),
    ]);
  }

  String _formatDuration(double s) {
    if (s < 60) return '${s.toStringAsFixed(2)}s';
    return '${(s / 60).floor()}m ${(s % 60).toStringAsFixed(1)}s';
  }
}

class _SpecialBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _SpecialBtn({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StretchBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StretchBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A34),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0B0C8))),
        ),
      ),
    );
  }
}

class _RampPresetBtn extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RampPresetBtn({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8888A0), letterSpacing: 0.8,
    ));
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF404060)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B88)),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
