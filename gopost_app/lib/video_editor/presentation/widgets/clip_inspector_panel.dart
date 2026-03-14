import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

const _blendModes = <int, String>{
  0: 'Normal',
  1: 'Multiply',
  2: 'Screen',
  3: 'Overlay',
  4: 'Soft Light',
  5: 'Hard Light',
  6: 'Color Dodge',
  7: 'Color Burn',
  8: 'Darken',
  9: 'Lighten',
  10: 'Difference',
  11: 'Exclusion',
  12: 'Hue',
  13: 'Saturation',
  14: 'Color',
  15: 'Luminosity',
};

class ClipInspectorPanel extends ConsumerStatefulWidget {
  const ClipInspectorPanel({super.key});

  @override
  ConsumerState<ClipInspectorPanel> createState() => _ClipInspectorPanelState();
}

class _ClipInspectorPanelState extends ConsumerState<ClipInspectorPanel> {
  VideoProject? _opacityBefore;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineNotifierProvider);
    final clip = state.selectedClip;

    if (clip == null) {
      return const _EmptyHint(
        icon: Icons.info_outline_rounded,
        message: 'Select a clip to inspect its properties',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildHeader(clip),
        const SizedBox(height: 14),
        _SectionLabel('Timing'),
        const SizedBox(height: 6),
        _buildInfoRow('In', _formatTime(clip.timelineIn)),
        _buildInfoRow('Out', _formatTime(clip.timelineOut)),
        _buildInfoRow('Duration', _formatDuration(clip.duration)),
        _buildInfoRow('Source In', _formatTime(clip.sourceIn)),
        _buildInfoRow('Source Out', _formatTime(clip.sourceOut)),
        const SizedBox(height: 14),
        _SectionLabel('Properties'),
        const SizedBox(height: 6),
        _buildInfoRow('Speed', '${clip.speed}x'),
        _buildInfoRow('Track', '${clip.trackIndex}'),
        _buildInfoRow('Source', clip.sourceType.name),
        const SizedBox(height: 14),
        _SectionLabel('Opacity'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 3,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: clip.opacity,
                  min: 0.0,
                  max: 1.0,
                  onChangeStart: (_) {
                    _opacityBefore = state.project;
                  },
                  onChanged: (v) {
                    ref.read(timelineNotifierProvider.notifier).setClipOpacity(clip.id, v);
                  },
                  onChangeEnd: (_) {
                    if (_opacityBefore != null) {
                      ref.read(timelineNotifierProvider.notifier).commitClipOpacity(clip.id, _opacityBefore!);
                      _opacityBefore = null;
                    }
                  },
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${(clip.opacity * 100).round()}%',
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFFB0B0C8)),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionLabel('Blend Mode'),
        const SizedBox(height: 6),
        _buildBlendModeDropdown(clip),
        const SizedBox(height: 14),
        _SectionLabel('Audio'),
        const SizedBox(height: 6),
        _buildInfoRow('Volume', '${(clip.audio.volume * 100).round()}%'),
        _buildInfoRow('Pan', clip.audio.pan.toStringAsFixed(2)),
        _buildInfoRow('Fade In', '${clip.audio.fadeInSeconds}s'),
        _buildInfoRow('Fade Out', '${clip.audio.fadeOutSeconds}s'),
        _buildInfoRow('Muted', clip.audio.isMuted ? 'Yes' : 'No'),
        const SizedBox(height: 14),
        _SectionLabel('Effects'),
        const SizedBox(height: 6),
        if (clip.effects.isEmpty)
          const Text('No effects applied', style: TextStyle(fontSize: 13, color: Color(0xFF6B6B88)))
        else
          ...clip.effects.map((fx) => _buildInfoRow(
            fx.type.name,
            '${fx.value.toStringAsFixed(1)} ${fx.enabled ? '' : '(off)'}',
          )),
        const SizedBox(height: 14),
        _SectionLabel('Transitions'),
        const SizedBox(height: 6),
        _buildInfoRow('In', clip.transitionIn.isNone ? 'None' : '${clip.transitionIn.type.name} ${clip.transitionIn.durationSeconds}s'),
        _buildInfoRow('Out', clip.transitionOut.isNone ? 'None' : '${clip.transitionOut.type.name} ${clip.transitionOut.durationSeconds}s'),
        const SizedBox(height: 14),
        _SectionLabel('Actions'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.copy_rounded,
                label: 'Duplicate',
                onTap: () => ref.read(timelineNotifierProvider.notifier).duplicateClip(clip.id),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionBtn(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFEF5350),
                onTap: () => ref.read(timelineNotifierProvider.notifier).removeClip(clip.id),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(VideoClip clip) {
    final typeIcon = switch (clip.sourceType) {
      ClipSourceType.video => Icons.videocam_rounded,
      ClipSourceType.image => Icons.photo_rounded,
      ClipSourceType.title => Icons.title_rounded,
      ClipSourceType.color => Icons.color_lens_rounded,
      ClipSourceType.adjustment => Icons.auto_fix_high_rounded,
    };
    final typeColor = switch (clip.sourceType) {
      ClipSourceType.video => const Color(0xFF26C6DA),
      ClipSourceType.image => const Color(0xFFFF7043),
      ClipSourceType.title => const Color(0xFFAB47BC),
      ClipSourceType.color => const Color(0xFF66BB6A),
      ClipSourceType.adjustment => const Color(0xFF42A5F5),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(typeIcon, size: 24, color: typeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clip.displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE0E0F0)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('ID: ${clip.id}  •  ${clip.sourceType.name}',
                  style: TextStyle(fontSize: 12, color: typeColor.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlendModeDropdown(VideoClip clip) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF303050)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: clip.blendMode,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A34),
          style: const TextStyle(fontSize: 14, color: Color(0xFFE0E0F0)),
          items: _blendModes.entries.map((e) =>
            DropdownMenuItem(value: e.key, child: Text(e.value)),
          ).toList(),
          onChanged: (v) {
            if (v != null) {
              ref.read(timelineNotifierProvider.notifier).setClipBlendMode(clip.id, v);
            }
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B88))),
          ),
          Expanded(
            child: Text(value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFFD0D0E8)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(double s) {
    final m = (s / 60).floor();
    final sec = (s % 60).floor();
    final ms = ((s % 1) * 100).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  String _formatDuration(double s) {
    if (s < 60) return '${s.toStringAsFixed(2)}s';
    return '${(s / 60).floor()}m ${(s % 60).toStringAsFixed(1)}s';
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF6C63FF),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
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
