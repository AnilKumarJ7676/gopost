import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

class EffectsPanel extends ConsumerStatefulWidget {
  const EffectsPanel({super.key});

  static IconData iconForEffect(EffectType type) {
    return switch (type) {
      EffectType.brightness => Icons.brightness_6,
      EffectType.contrast => Icons.contrast,
      EffectType.saturation => Icons.color_lens,
      EffectType.exposure => Icons.exposure,
      EffectType.temperature => Icons.wb_sunny,
      EffectType.tint => Icons.colorize,
      EffectType.highlights => Icons.highlight,
      EffectType.shadows => Icons.dark_mode,
      EffectType.vibrance => Icons.vibration,
      EffectType.hueRotate => Icons.palette,
      EffectType.gaussianBlur => Icons.blur_on,
      EffectType.radialBlur => Icons.blur_circular,
      EffectType.tiltShift => Icons.blur_linear,
      EffectType.sharpen => Icons.filter_center_focus,
      EffectType.pixelate => Icons.grid_4x4,
      EffectType.glitch => Icons.broken_image,
      EffectType.chromatic => Icons.visibility,
      EffectType.vignette => Icons.lens,
      EffectType.grain => Icons.grain,
      EffectType.sepia => Icons.filter,
      EffectType.invert => Icons.invert_colors,
      EffectType.posterize => Icons.contrast,
    };
  }

  @override
  ConsumerState<EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends ConsumerState<EffectsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _categories = EffectCategory.values;
  static const _categoryLabels = {
    EffectCategory.colorTone: 'Color & Tone',
    EffectCategory.blurSharpen: 'Blur & Sharpen',
    EffectCategory.distort: 'Distort',
    EffectCategory.stylize: 'Stylize',
  };
  static const _categoryIcons = {
    EffectCategory.colorTone: Icons.palette_outlined,
    EffectCategory.blurSharpen: Icons.blur_on_outlined,
    EffectCategory.distort: Icons.grid_4x4_outlined,
    EffectCategory.stylize: Icons.auto_fix_high_outlined,
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clipId = ref.watch(timelineNotifierProvider.select((s) => s.selectedClipId));
    final project = ref.watch(timelineNotifierProvider.select((s) => s.project));
    final clip = clipId != null && project != null ? project.findClip(clipId) : null;
    final appliedEffects = clip?.effects ?? [];

    return Column(
      children: [
        _buildTabBar(),
        if (clipId == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Long-press any effect & drag to timeline',
              style: TextStyle(fontSize: 11, color: Color(0xFF505068)),
            ),
          ),
        Expanded(
          child: AnimatedBuilder(
            animation: _tabCtrl,
            builder: (context, _) {
              final cat = _categories[_tabCtrl.index];
              return _buildEffectList(cat, clipId, appliedEffects);
            },
          ),
        ),
        if (clipId != null && appliedEffects.isNotEmpty)
          _buildClearAll(clipId),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF14142B),
        border: Border(bottom: BorderSide(color: Color(0xFF252540))),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: const Color(0xFF6C63FF),
        indicatorWeight: 2,
        labelColor: const Color(0xFF6C63FF),
        unselectedLabelColor: const Color(0xFF6B6B88),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        dividerHeight: 0,
        tabs: _categories.map((cat) {
          return Tab(
            height: 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_categoryIcons[cat], size: 16),
                const SizedBox(width: 5),
                Text(_categoryLabels[cat] ?? cat.name),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEffectList(EffectCategory cat, int? clipId, List<VideoEffect> applied) {
    final effects = EffectType.values.where((e) => e.category == cat).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: effects.length,
      itemBuilder: (context, i) {
        final type = effects[i];
        final effect = applied.where((e) => e.type == type).firstOrNull;
        return _EffectRow(
          key: ValueKey(type),
          type: type,
          applied: effect,
          clipId: clipId,
        );
      },
    );
  }

  Widget _buildClearAll(int clipId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF252540))),
      ),
      child: SizedBox(
        height: 32,
        child: TextButton.icon(
          onPressed: () => ref.read(timelineNotifierProvider.notifier).clearEffects(clipId),
          icon: const Icon(Icons.clear_all_rounded, size: 18, color: Color(0xFFEF5350)),
          label: const Text(
            'Clear All Effects',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFEF5350)),
          ),
        ),
      ),
    );
  }
}

class _EffectRow extends ConsumerStatefulWidget {
  const _EffectRow({
    super.key,
    required this.type,
    required this.applied,
    required this.clipId,
  });

  final EffectType type;
  final VideoEffect? applied;
  final int? clipId;

  @override
  ConsumerState<_EffectRow> createState() => _EffectRowState();
}

class _EffectRowState extends ConsumerState<_EffectRow> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _EffectRow old) {
    super.didUpdateWidget(old);
    if (widget.applied == null && old.applied != null) {
      _expanded = false;
    }
  }

  AdjustmentClipDragData _buildDragData() {
    final effect = VideoEffect(
      type: widget.type,
      value: widget.applied?.value ?? widget.type.defaultValue,
    );
    const noPreset = PresetFilterId.none;
    return AdjustmentClipDragData(
      data: AdjustmentClipData(
        effects: [effect],
        style: AdjustmentClipData.inferStyle([effect], noPreset),
        label: AdjustmentClipData.buildLabel([effect], noPreset),
        colorValue: AdjustmentClipData.pickColor([effect], noPreset),
      ),
      icon: EffectsPanel.iconForEffect(widget.type),
      label: widget.type.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.applied != null;
    final isEnabled = widget.applied?.enabled ?? true;
    final icon = EffectsPanel.iconForEffect(widget.type);
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final accent = isOn && isEnabled ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88);

    final rowContent = Container(
      decoration: BoxDecoration(
        color: isOn
            ? const Color(0xFF6C63FF).withValues(alpha: 0.08)
            : const Color(0xFF1A1A34).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOn && isEnabled
              ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
              : const Color(0xFF252540),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (widget.clipId == null) return;
              if (!isOn) {
                notifier.addEffect(
                  widget.clipId!,
                  VideoEffect(type: widget.type, value: widget.type.defaultValue),
                );
                setState(() => _expanded = true);
              } else {
                setState(() => _expanded = !_expanded);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.type.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                            color: isOn
                                ? const Color(0xFFE0E0F0)
                                : const Color(0xFFB0B0C8),
                          ),
                        ),
                        if (isOn)
                          Text(
                            _formatValue(widget.applied!.value, widget.type),
                            style: TextStyle(
                              fontSize: 11,
                              color: accent.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOn && widget.clipId != null) ...[
                    SizedBox(
                      height: 24,
                      width: 38,
                      child: FittedBox(
                        child: Switch.adaptive(
                          value: isEnabled,
                          onChanged: (_) => notifier.toggleEffect(widget.clipId!, widget.type),
                          activeTrackColor: const Color(0xFF6C63FF),
                          activeThumbColor: const Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => notifier.removeEffect(widget.clipId!, widget.type),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B6B88)),
                      ),
                    ),
                  ] else if (!isOn)
                    const Icon(Icons.add_rounded, size: 20, color: Color(0xFF6B6B88)),
                ],
              ),
          ),
          ),
          if (isOn && isEnabled && _expanded && widget.clipId != null) ...[
            Container(height: 1, color: const Color(0xFF252540).withValues(alpha: 0.5)),
            _EffectSlider(
              type: widget.type,
              value: widget.applied!.value,
              clipId: widget.clipId!,
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LongPressDraggable<TimelineDragData>(
        data: _buildDragData(),
        delay: const Duration(milliseconds: 200),
        hapticFeedbackOnStart: true,
        onDragStarted: () => HapticFeedback.mediumImpact(),
        feedback: _EffectDragFeedback(
          icon: icon,
          label: widget.type.label,
          color: const Color(0xFF6C63FF),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: rowContent),
        child: rowContent,
      ),
    );
  }

  String _formatValue(double v, EffectType type) {
    if (v.abs() < 0.01) return '${type.min.round()} — ${type.max.round()}';
    if (v.abs() >= 100 || v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}

class _EffectDragFeedback extends StatelessWidget {
  const _EffectDragFeedback({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
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
    );
  }
}

class _EffectSlider extends ConsumerWidget {
  const _EffectSlider({
    required this.type,
    required this.value,
    required this.clipId,
  });

  final EffectType type;
  final double value;
  final int clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final isDefault = (value - type.defaultValue).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              _display(value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Color(0xFF6C63FF),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF6C63FF),
                inactiveTrackColor: const Color(0xFF303050),
                thumbColor: const Color(0xFF6C63FF),
                overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value.clamp(type.min, type.max),
                min: type.min,
                max: type.max,
                onChanged: (v) => notifier.updateEffectValue(clipId, type, v),
              ),
            ),
          ),
          GestureDetector(
            onTap: isDefault
                ? null
                : () => notifier.updateEffectValue(clipId, type, type.defaultValue),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: isDefault
                    ? const Color(0xFF303050)
                    : const Color(0xFF6C63FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _display(double v) {
    if (v.abs() < 0.01) return '0';
    if (v.abs() >= 100 || v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}
