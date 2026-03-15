import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/timeline_drag_data.dart';
import 'package:gopost_app/video_editor/domain/models/video_effect.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/video_editor/presentation/widgets/effects_panel.dart';

/// Panel that provides draggable adjustment layer tiles.
///
/// Users drag these onto an effect track in the timeline to create
/// adjustment layer clips. Each tile represents either:
/// - A single effect (brightness, blur, vignette, etc.)
/// - A color preset (Cinematic, Vintage, etc.)
/// - A custom combination
///
/// This is the primary entry point for the adjustment layer workflow,
/// replacing the old per-clip-only effect application.
class AdjustmentLayerPanel extends ConsumerStatefulWidget {
  const AdjustmentLayerPanel({super.key});

  @override
  ConsumerState<AdjustmentLayerPanel> createState() => _AdjustmentLayerPanelState();
}

class _AdjustmentLayerPanelState extends ConsumerState<AdjustmentLayerPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _tabs = ['Effects', 'Presets', 'Custom'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Adjustment Layers',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                _QuickAddButton(onPressed: _addEmptyAdjustmentClip),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorColor: scheme.primary,
            tabs: _tabs.map((t) => Tab(text: t, height: 36)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _EffectTilesGrid(),
                _PresetTilesGrid(),
                _CustomCombinationBuilder(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addEmptyAdjustmentClip() {
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final pos = ref.read(timelineNotifierProvider).playback.positionSeconds;
    notifier.createAdjustmentClip(
      data: const AdjustmentClipData(),
      atTime: pos,
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-add button
// ---------------------------------------------------------------------------

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add empty adjustment layer at playhead',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Effects tile grid — draggable tiles for each effect type
// ---------------------------------------------------------------------------

class _EffectTilesGrid extends StatelessWidget {
  static const _categoryOrder = EffectCategory.values;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final category in _categoryOrder) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 6),
            child: Text(
              _categoryLabel(category),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: EffectType.values
                .where((e) => e.category == category)
                .map((type) => _EffectDraggableTile(effectType: type))
                .toList(),
          ),
        ],
      ],
    );
  }

  String _categoryLabel(EffectCategory cat) => switch (cat) {
    EffectCategory.colorTone => 'COLOR & TONE',
    EffectCategory.blurSharpen => 'BLUR & SHARPEN',
    EffectCategory.distort => 'DISTORT',
    EffectCategory.stylize => 'STYLIZE',
  };
}

class _EffectDraggableTile extends StatelessWidget {
  const _EffectDraggableTile({required this.effectType});
  final EffectType effectType;

  @override
  Widget build(BuildContext context) {
    final icon = EffectsPanel.iconForEffect(effectType);
    final color = Color(AdjustmentClipData.pickColor(
      [VideoEffect(type: effectType, value: effectType.defaultValue == 0 ? 50 : effectType.defaultValue)],
      PresetFilterId.none,
    ));

    return LongPressDraggable<TimelineDragData>(
      data: AdjustmentClipDragData(
        data: AdjustmentClipData(
          effects: [VideoEffect(type: effectType, value: effectType.defaultValue == 0 ? 50 : effectType.defaultValue)],
        ),
        icon: icon,
        label: effectType.label,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                effectType.label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTile(context, icon, color),
      ),
      child: _buildTile(context, icon, color),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            effectType.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preset tiles grid — draggable presets
// ---------------------------------------------------------------------------

class _PresetTilesGrid extends StatelessWidget {
  static const _presets = PresetFilterId.values;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.2,
      ),
      itemCount: _presets.length - 1, // skip 'none'
      itemBuilder: (context, index) {
        final preset = _presets[index + 1];
        return _PresetDraggableTile(preset: preset);
      },
    );
  }
}

class _PresetDraggableTile extends StatelessWidget {
  const _PresetDraggableTile({required this.preset});
  final PresetFilterId preset;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFAB47BC);

    return LongPressDraggable<TimelineDragData>(
      data: PresetClipDragData(preset: preset),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                preset.label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          preset.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom combination builder — pick multiple effects + values
// ---------------------------------------------------------------------------

class _CustomCombinationBuilder extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CustomCombinationBuilder> createState() => _CustomCombinationBuilderState();
}

class _CustomCombinationBuilderState extends ConsumerState<_CustomCombinationBuilder> {
  final List<VideoEffect> _selectedEffects = [];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (_selectedEffects.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '${_selectedEffects.length} effects selected',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedEffects.clear()),
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildAddButton(scheme),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final type in EffectType.values)
                _CustomEffectRow(
                  effectType: type,
                  isSelected: _selectedEffects.any((e) => e.type == type),
                  currentValue: _selectedEffects
                      .where((e) => e.type == type)
                      .firstOrNull
                      ?.value,
                  onToggle: () => _toggleEffect(type),
                  onValueChanged: (v) => _updateValue(type, v),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(ColorScheme scheme) {
    final data = AdjustmentClipData(effects: _selectedEffects);

    return LongPressDraggable<TimelineDragData>(
      data: AdjustmentClipDragData(
        data: data,
        icon: Icons.auto_fix_high,
        label: AdjustmentClipData.buildLabel(_selectedEffects, PresetFilterId.none),
      ),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: Text(
            'Custom: ${_selectedEffects.length} effects',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: FilledButton.icon(
        onPressed: _addCustomAdjustmentClip,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add to Timeline'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 36),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _toggleEffect(EffectType type) {
    setState(() {
      final idx = _selectedEffects.indexWhere((e) => e.type == type);
      if (idx >= 0) {
        _selectedEffects.removeAt(idx);
      } else {
        final defaultVal = type.defaultValue == 0
            ? (type.max - type.min) * 0.25 + type.min
            : type.defaultValue;
        _selectedEffects.add(VideoEffect(type: type, value: defaultVal));
      }
    });
  }

  void _updateValue(EffectType type, double value) {
    setState(() {
      final idx = _selectedEffects.indexWhere((e) => e.type == type);
      if (idx >= 0) {
        _selectedEffects[idx] = _selectedEffects[idx].copyWith(value: value);
      }
    });
  }

  void _addCustomAdjustmentClip() {
    if (_selectedEffects.isEmpty) return;
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final pos = ref.read(timelineNotifierProvider).playback.positionSeconds;
    notifier.createAdjustmentClip(
      data: AdjustmentClipData(effects: List.from(_selectedEffects)),
      atTime: pos,
    );
  }
}

class _CustomEffectRow extends StatelessWidget {
  const _CustomEffectRow({
    required this.effectType,
    required this.isSelected,
    this.currentValue,
    required this.onToggle,
    required this.onValueChanged,
  });

  final EffectType effectType;
  final bool isSelected;
  final double? currentValue;
  final VoidCallback onToggle;
  final ValueChanged<double> onValueChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = EffectsPanel.iconForEffect(effectType);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? scheme.primary.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 20,
                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18, color: scheme.onSurface),
                  const SizedBox(width: 8),
                  Text(
                    effectType.label,
                    style: TextStyle(fontSize: 13, color: scheme.onSurface),
                  ),
                  if (isSelected && currentValue != null) ...[
                    const Spacer(),
                    Text(
                      currentValue!.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 8, bottom: 6),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: currentValue ?? effectType.defaultValue,
                  min: effectType.min,
                  max: effectType.max,
                  onChanged: onValueChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
