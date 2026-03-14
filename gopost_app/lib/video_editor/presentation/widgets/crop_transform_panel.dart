import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_keyframe.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

const _aspectRatios = <({String label, int w, int h, IconData icon})>[
  (label: '16:9', w: 1920, h: 1080, icon: Icons.crop_16_9),
  (label: '9:16', w: 1080, h: 1920, icon: Icons.crop_portrait),
  (label: '1:1', w: 1080, h: 1080, icon: Icons.crop_square),
  (label: '4:5', w: 1080, h: 1350, icon: Icons.crop_portrait),
  (label: '4:3', w: 1440, h: 1080, icon: Icons.crop_7_5),
  (label: '21:9', w: 2560, h: 1080, icon: Icons.crop_16_9),
];

class CropTransformPanel extends ConsumerStatefulWidget {
  const CropTransformPanel({super.key});

  @override
  ConsumerState<CropTransformPanel> createState() => _CropTransformPanelState();
}

class _CropTransformPanelState extends ConsumerState<CropTransformPanel> {
  double _posX = 0;
  double _posY = 0;
  double _scale = 1.0;
  double _rotation = 0;
  bool _flipH = false;
  bool _flipV = false;
  VideoProject? _beforeTransform;

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(timelineNotifierProvider.select((s) => s.selectedClip));
    final project = ref.watch(timelineNotifierProvider.select((s) => s.project));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionLabel('Project Aspect Ratio'),
        const SizedBox(height: 8),
        _buildAspectRatioGrid(project),
        if (project != null) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              '${project.width} x ${project.height}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF6B6B88)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionLabel('Clip Transform'),
        const SizedBox(height: 6),
        if (clip == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF6B6B88)),
                SizedBox(width: 6),
                Text('Select a clip to transform', style: TextStyle(fontSize: 11, color: Color(0xFF6B6B88))),
              ],
            ),
          ),
        IgnorePointer(
          ignoring: clip == null,
          child: Opacity(
            opacity: clip == null ? 0.45 : 1.0,
            child: Column(
              children: [
                _buildSlider('Position X', _posX, -1000, 1000, (v) {
                  setState(() => _posX = v);
                  if (clip != null) _setKeyframe(clip.id, KeyframeProperty.positionX, v);
                }),
                _buildSlider('Position Y', _posY, -1000, 1000, (v) {
                  setState(() => _posY = v);
                  if (clip != null) _setKeyframe(clip.id, KeyframeProperty.positionY, v);
                }),
                _buildSlider('Scale', _scale, 0.1, 5.0, (v) {
                  setState(() => _scale = v);
                  if (clip != null) _setKeyframe(clip.id, KeyframeProperty.scale, v);
                }),
                _buildSlider('Rotation', _rotation, -360, 360, (v) {
                  setState(() => _rotation = v);
                  if (clip != null) _setKeyframe(clip.id, KeyframeProperty.rotation, v);
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FlipBtn(
                        icon: Icons.flip,
                        label: 'Flip H',
                        isActive: _flipH,
                        onTap: () {
                          setState(() => _flipH = !_flipH);
                          if (clip != null) _setKeyframe(clip.id, KeyframeProperty.scale, _flipH ? -_scale.abs() : _scale.abs());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FlipBtn(
                        icon: Icons.flip_camera_android,
                        label: 'Flip V',
                        isActive: _flipV,
                        onTap: () => setState(() => _flipV = !_flipV),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PresetBtn(label: 'Fit', onTap: () {
                        setState(() { _posX = 0; _posY = 0; _scale = 1.0; _rotation = 0; });
                        if (clip != null) _resetTransform(clip.id);
                      }),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PresetBtn(label: 'Fill', onTap: () {
                        setState(() { _posX = 0; _posY = 0; _scale = 1.2; _rotation = 0; });
                        if (clip != null) _setKeyframe(clip.id, KeyframeProperty.scale, 1.2);
                      }),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PresetBtn(label: 'Reset', onTap: () {
                        setState(() {
                          _posX = 0; _posY = 0; _scale = 1.0; _rotation = 0;
                          _flipH = false; _flipV = false;
                        });
                        if (clip != null) _resetTransform(clip.id);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionLabel('Ken Burns (Auto Pan & Zoom)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _KenBurnsBtn(label: 'Zoom In', onTap: () { if (clip != null) _applyKenBurns(clip.id, 1.0, 1.4); })),
                    const SizedBox(width: 6),
                    Expanded(child: _KenBurnsBtn(label: 'Zoom Out', onTap: () { if (clip != null) _applyKenBurns(clip.id, 1.4, 1.0); })),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _KenBurnsBtn(label: 'Pan Left', onTap: () { if (clip != null) _applyKenBurnsPan(clip.id, 100, 0, -100, 0); })),
                    const SizedBox(width: 6),
                    Expanded(child: _KenBurnsBtn(label: 'Pan Right', onTap: () { if (clip != null) _applyKenBurnsPan(clip.id, -100, 0, 100, 0); })),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAspectRatioGrid(VideoProject? project) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _aspectRatios.map((ar) {
        final isActive = project != null && project.width == ar.w && project.height == ar.h;
        return GestureDetector(
          onTap: () {
            ref.read(timelineNotifierProvider.notifier).setProjectDimensions(ar.w, ar.h);
          },
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : const Color(0xFF1A1A34),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF303050),
              ),
            ),
            child: Column(
              children: [
                Icon(ar.icon, size: 20,
                  color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88)),
                const SizedBox(height: 4),
                Text(ar.label,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF6C63FF) : const Color(0xFFB0B0C8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _setKeyframe(int clipId, KeyframeProperty prop, double value) {
    _beforeTransform ??= ref.read(timelineNotifierProvider).project;
    final state = ref.read(timelineNotifierProvider);
    final pos = state.playback.positionSeconds;
    final clip = state.selectedClip;
    if (clip == null) return;
    final relativeTime = pos - clip.timelineIn;
    ref.read(timelineNotifierProvider.notifier).addKeyframe(
      clipId, prop,
      Keyframe(time: relativeTime, value: value),
    );
  }

  void _resetTransform(int clipId) {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    notifier.clearKeyframes(clipId, KeyframeProperty.positionX);
    notifier.clearKeyframes(clipId, KeyframeProperty.positionY);
    notifier.clearKeyframes(clipId, KeyframeProperty.scale);
    notifier.clearKeyframes(clipId, KeyframeProperty.rotation);
  }

  void _applyKenBurns(int clipId, double startScale, double endScale) {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.selectedClip;
    if (clip == null) return;
    final notifier = ref.read(timelineNotifierProvider.notifier);
    notifier.addKeyframe(clipId, KeyframeProperty.scale, Keyframe(time: 0, value: startScale));
    notifier.addKeyframe(clipId, KeyframeProperty.scale, Keyframe(time: clip.duration, value: endScale));
  }

  void _applyKenBurnsPan(int clipId, double startX, double startY, double endX, double endY) {
    final state = ref.read(timelineNotifierProvider);
    final clip = state.selectedClip;
    if (clip == null) return;
    final notifier = ref.read(timelineNotifierProvider.notifier);
    notifier.addKeyframe(clipId, KeyframeProperty.positionX, Keyframe(time: 0, value: startX));
    notifier.addKeyframe(clipId, KeyframeProperty.positionX, Keyframe(time: clip.duration, value: endX));
    notifier.addKeyframe(clipId, KeyframeProperty.positionY, Keyframe(time: 0, value: startY));
    notifier.addKeyframe(clipId, KeyframeProperty.positionY, Keyframe(time: clip.duration, value: endY));
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8888A0))),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(value.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFB0B0C8)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlipBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FlipBtn({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.15) : const Color(0xFF1A1A34),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13,
                color: isActive ? const Color(0xFF6C63FF) : const Color(0xFFB0B0C8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A34),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB0B0C8))),
        ),
      ),
    );
  }
}

class _KenBurnsBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KenBurnsBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF26C6DA).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF26C6DA))),
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
