import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

class ColorGradingPanel extends ConsumerStatefulWidget {
  const ColorGradingPanel({super.key});

  @override
  ConsumerState<ColorGradingPanel> createState() => _ColorGradingPanelState();
}

class _ColorGradingPanelState extends ConsumerState<ColorGradingPanel> {
  VideoProject? _beforeGrading;

  static const _sliderDefs = <({String label, IconData icon, String field})>[
    (label: 'Brightness', icon: Icons.brightness_6_rounded, field: 'brightness'),
    (label: 'Contrast', icon: Icons.contrast_rounded, field: 'contrast'),
    (label: 'Saturation', icon: Icons.color_lens_rounded, field: 'saturation'),
    (label: 'Exposure', icon: Icons.exposure_rounded, field: 'exposure'),
    (label: 'Temperature', icon: Icons.wb_sunny_rounded, field: 'temperature'),
    (label: 'Tint', icon: Icons.colorize_rounded, field: 'tint'),
    (label: 'Highlights', icon: Icons.highlight_rounded, field: 'highlights'),
    (label: 'Shadows', icon: Icons.dark_mode_rounded, field: 'shadows'),
    (label: 'Vibrance', icon: Icons.vibration_rounded, field: 'vibrance'),
    (label: 'Hue', icon: Icons.palette_rounded, field: 'hue'),
  ];

  double _fieldValue(ColorGrading g, String field) => switch (field) {
    'brightness' => g.brightness,
    'contrast' => g.contrast,
    'saturation' => g.saturation,
    'exposure' => g.exposure,
    'temperature' => g.temperature,
    'tint' => g.tint,
    'highlights' => g.highlights,
    'shadows' => g.shadows,
    'vibrance' => g.vibrance,
    'hue' => g.hue,
    _ => 0,
  };

  ({double min, double max}) _fieldRange(String field) => switch (field) {
    'exposure' => (min: -2.0, max: 2.0),
    'hue' => (min: -180.0, max: 180.0),
    _ => (min: -100.0, max: 100.0),
  };

  ColorGrading _withField(ColorGrading g, String field, double v) => switch (field) {
    'brightness' => g.copyWith(brightness: v),
    'contrast' => g.copyWith(contrast: v),
    'saturation' => g.copyWith(saturation: v),
    'exposure' => g.copyWith(exposure: v),
    'temperature' => g.copyWith(temperature: v),
    'tint' => g.copyWith(tint: v),
    'highlights' => g.copyWith(highlights: v),
    'shadows' => g.copyWith(shadows: v),
    'vibrance' => g.copyWith(vibrance: v),
    'hue' => g.copyWith(hue: v),
    _ => g,
  };

  @override
  Widget build(BuildContext context) {
    final clipId = ref.watch(timelineNotifierProvider.select((s) => s.selectedClipId));
    final project = ref.watch(timelineNotifierProvider.select((s) => s.project));
    final clip = clipId != null && project != null ? project.findClip(clipId) : null;
    final notifier = ref.read(timelineNotifierProvider.notifier);

    final hasClip = clipId != null && clip != null;
    final grading = clip?.colorGrading ?? const ColorGrading();
    final preset = clip?.presetFilter ?? PresetFilterId.none;

    return Column(
      children: [
        _buildPresetRow(clipId, preset, notifier),
        if (!hasClip)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.palette_outlined, size: 36, color: Color(0xFF303050)),
                  SizedBox(height: 8),
                  Text(
                    'Select a clip to adjust colors',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B6B88)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'or drag presets to the timeline',
                    style: TextStyle(fontSize: 11, color: Color(0xFF505068)),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              itemCount: _sliderDefs.length,
              itemBuilder: (context, i) {
                final def = _sliderDefs[i];
                final range = _fieldRange(def.field);
                final val = _fieldValue(grading, def.field);
                return _GradingSliderRow(
                  label: def.label,
                  icon: def.icon,
                  value: val,
                  min: range.min,
                  max: range.max,
                  onChanged: (v) {
                    notifier.setColorGrading(clipId, _withField(grading, def.field, v));
                  },
                  onDragStart: () => _beforeGrading = project,
                  onDragEnd: () {
                    if (_beforeGrading != null) {
                      notifier.commitColorGrading(clipId, _beforeGrading!);
                      _beforeGrading = null;
                    }
                  },
                  onReset: () {
                    notifier.setColorGrading(clipId, _withField(grading, def.field, 0));
                  },
                );
              },
            ),
          ),
          _buildGradingDragHandle(grading, preset),
          _buildResetBar(clipId, grading, preset, notifier),
        ],
      ],
    );
  }

  Widget _buildGradingDragHandle(ColorGrading grading, PresetFilterId preset) {
    final hasGrading = !grading.isDefault || preset != PresetFilterId.none;
    if (!hasGrading) return const SizedBox.shrink();

    final effects = <VideoEffect>[];
    for (final def in _sliderDefs) {
      final v = _fieldValue(grading, def.field);
      if (v.abs() >= 0.01) {
        final effectType = _fieldToEffectType(def.field);
        if (effectType != null) {
          effects.add(VideoEffect(type: effectType, value: v));
        }
      }
    }

    final dragData = AdjustmentClipDragData(
      data: AdjustmentClipData(
        effects: effects,
        colorGrading: grading,
        preset: preset,
        style: AdjustmentClipData.inferStyle(effects, preset),
        label: preset != PresetFilterId.none
            ? preset.label
            : AdjustmentClipData.buildLabel(effects, preset),
        colorValue: AdjustmentClipData.pickColor(effects, preset),
      ),
      icon: Icons.tune_rounded,
      label: preset != PresetFilterId.none ? preset.label : 'Color Grading',
    );

    return LongPressDraggable<TimelineDragData>(
      data: dragData,
      delay: const Duration(milliseconds: 150),
      hapticFeedbackOnStart: true,
      onDragStarted: () => HapticFeedback.mediumImpact(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.5), blurRadius: 14)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                preset != PresetFilterId.none ? preset.label : 'Color Grading',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.timeline_rounded, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.drag_indicator_rounded, size: 16, color: Color(0xFF6C63FF)),
            SizedBox(width: 4),
            Text(
              'Drag current grading to timeline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C63FF),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.timeline_rounded, size: 14, color: Color(0xFF6C63FF)),
          ],
        ),
      ),
    );
  }

  static EffectType? _fieldToEffectType(String field) => switch (field) {
    'brightness' => EffectType.brightness,
    'contrast' => EffectType.contrast,
    'saturation' => EffectType.saturation,
    'exposure' => EffectType.exposure,
    'temperature' => EffectType.temperature,
    'tint' => EffectType.tint,
    'highlights' => EffectType.highlights,
    'shadows' => EffectType.shadows,
    'vibrance' => EffectType.vibrance,
    'hue' => EffectType.hueRotate,
    _ => null,
  };

  Widget _buildPresetRow(int? clipId, PresetFilterId active, TimelineNotifier notifier) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        border: Border(bottom: BorderSide(color: Color(0xFF252540))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'Presets — tap to apply, drag to timeline',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B6B88), letterSpacing: 0.4),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: PresetFilterId.values.map((p) {
                final isActive = active == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _DraggablePresetPill(
                    preset: p,
                    isActive: isActive,
                    onTap: clipId != null ? () => notifier.setPresetFilter(clipId, p) : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetBar(int clipId, ColorGrading grading, PresetFilterId preset, TimelineNotifier notifier) {
    final canReset = !grading.isDefault || preset != PresetFilterId.none;
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        border: Border(top: BorderSide(color: Color(0xFF252540))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF6B6B88)),
          const SizedBox(width: 6),
          Text(
            canReset ? 'Modified' : 'Default',
            style: TextStyle(
              fontSize: 12,
              color: canReset ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: canReset ? () => notifier.resetColorGrading(clipId) : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Reset All',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: canReset ? const Color(0xFFEF5350) : const Color(0xFF404060),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradingSliderRow extends StatelessWidget {
  const _GradingSliderRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onReset,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final VoidCallback onReset;

  bool get _isDefault => value.abs() < 0.01;

  String get _display {
    if (value.abs() < 0.01) return '0';
    if (max <= 2.0) return value.toStringAsFixed(2);
    if (value.abs() >= 100 || value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  Color get _accentColor {
    if (_isDefault) return const Color(0xFF6B6B88);
    if (value > 0) return const Color(0xFF6C63FF);
    return const Color(0xFF26C6DA);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Icon(icon, size: 16, color: _accentColor),
            ),
            SizedBox(
              width: 78,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _isDefault ? FontWeight.w400 : FontWeight.w600,
                  color: _isDefault ? const Color(0xFF8888A0) : const Color(0xFFE0E0F0),
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _accentColor,
                  inactiveTrackColor: const Color(0xFF252540),
                  thumbColor: _accentColor,
                  overlayColor: _accentColor.withValues(alpha: 0.12),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  onChangeStart: (_) => onDragStart(),
                  onChangeEnd: (_) => onDragEnd(),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                _display,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: _accentColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: _isDefault ? null : onReset,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 15,
                  color: _isDefault ? const Color(0xFF303050) : _accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggablePresetPill extends StatelessWidget {
  const _DraggablePresetPill({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  final PresetFilterId preset;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (preset == PresetFilterId.none) {
      return _PresetPill(preset: preset, isActive: isActive, onTap: onTap);
    }

    final pill = _PresetPill(preset: preset, isActive: isActive, onTap: onTap);
    final color = _PresetPill._colorFor(preset);

    return LongPressDraggable<TimelineDragData>(
      data: PresetClipDragData(preset: preset, icon: Icons.filter),
      delay: const Duration(milliseconds: 200),
      hapticFeedbackOnStart: true,
      onDragStarted: () => HapticFeedback.selectionClick(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                preset.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.timeline_rounded, size: 13, color: Colors.white70),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: pill),
      child: pill,
    );
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  final PresetFilterId preset;
  final bool isActive;
  final VoidCallback? onTap;

  static Color _colorFor(PresetFilterId p) => switch (p) {
    PresetFilterId.none => Colors.grey,
    PresetFilterId.natural => const Color(0xFF8B7355),
    PresetFilterId.daylight => const Color(0xFFFFE4B5),
    PresetFilterId.goldenHour => const Color(0xFFFF8C00),
    PresetFilterId.overcast => const Color(0xFF708090),
    PresetFilterId.portrait => const Color(0xFFE8B4B8),
    PresetFilterId.softSkin => const Color(0xFFFFDAB9),
    PresetFilterId.studio => const Color(0xFFE0E0E0),
    PresetFilterId.warmPortrait => const Color(0xFFDEB887),
    PresetFilterId.vintage => const Color(0xFFD2691E),
    PresetFilterId.polaroid => const Color(0xFFF5DEB3),
    PresetFilterId.kodachrome => const Color(0xFFCD853F),
    PresetFilterId.retro => const Color(0xFFBC8F8F),
    PresetFilterId.cinematic => const Color(0xFF2F4F4F),
    PresetFilterId.tealOrange => const Color(0xFF20B2AA),
    PresetFilterId.noir => const Color(0xFF1C1C1C),
    PresetFilterId.desaturated => const Color(0xFFA9A9A9),
    PresetFilterId.bwClassic => const Color(0xFF696969),
    PresetFilterId.bwHigh => const Color(0xFF404040),
    PresetFilterId.bwSelenium => const Color(0xFFC0C0C0),
    PresetFilterId.bwInfrared => const Color(0xFF8B008B),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(preset);
    return GestureDetector(
      onTap: onTap,
      child: NeonGlow(
        isActive: isActive,
        baseColor: color,
        borderRadius: 6,
        glowSpread: 1,
        glowBlur: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.2)
                : const Color(0xFF1A1A34),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.6) : const Color(0xFF303050),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                preset.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? Colors.white : const Color(0xFFB0B0C8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
