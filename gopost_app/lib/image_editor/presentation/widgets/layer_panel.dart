import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/domain/commands/layer_commands.dart';
import 'package:gopost_app/image_editor/domain/entities/layer_entity.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// S5-08: Layer panel displayed as a side sheet.
class LayerPanel extends ConsumerWidget {
  const LayerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final layers = canvasState.layers;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth > 1024 ? 300.0 : (screenWidth > 600 ? 260.0 : 220.0);

    return Container(
      width: panelWidth,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(
          left: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, ref),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: layers.isEmpty
                ? _buildEmptyState()
                : _buildLayerList(layers, canvasState.selectedLayerId, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Text(
            'Layers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _HeaderAction(
            icon: Icons.add,
            tooltip: 'Add layer',
            onTap: () {
              final notifier = ref.read(canvasProvider.notifier);
              ref.read(undoRedoProvider.notifier).execute(
                    AddSolidLayerCommand(notifier, r: 1, g: 1, b: 1, a: 1),
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No layers yet.\nImport an image to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildLayerList(
      List<LayerEntity> layers, int? selectedId, WidgetRef ref) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: layers.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final n = layers.length;
        final oldIdx = n - 1 - oldIndex;
        final newIdx = n - 1 - newIndex;
        final layer = layers[oldIdx];
        final notifier = ref.read(canvasProvider.notifier);
        ref.read(undoRedoProvider.notifier).execute(
              ReorderLayerCommand(notifier,
                  layerId: layer.id, oldIndex: oldIdx, newIndex: newIdx),
            );
      },
      itemBuilder: (context, index) {
        final reversedIndex = layers.length - 1 - index;
        final layer = layers[reversedIndex];
        final isSelected = layer.id == selectedId;

        final notifier = ref.read(canvasProvider.notifier);
        final undoRedo = ref.read(undoRedoProvider.notifier);
        return ReorderableDragStartListener(
          key: ValueKey(layer.id),
          index: index,
          child: _LayerTile(
            layer: layer,
            isSelected: isSelected,
            onTap: () => notifier.selectLayer(layer.id),
            onToggleVisibility: () => undoRedo.execute(
                  SetLayerVisibleCommand(notifier,
                      layerId: layer.id,
                      previousVisible: layer.visible,
                      newVisible: !layer.visible),
                ),
            onDelete: () => undoRedo.execute(
                  RemoveLayerCommand(notifier, layerId: layer.id),
                ),
            onOpacityChanged: (v) => undoRedo.execute(
                  SetLayerOpacityCommand(notifier,
                      layerId: layer.id,
                      previousOpacity: layer.opacity,
                      newOpacity: v),
                ),
            onBlendModeChanged: (v) => undoRedo.execute(
                  SetLayerBlendModeCommand(notifier,
                      layerId: layer.id,
                      previousMode: layer.blendMode,
                      newMode: v),
                ),
            onToggleLock: () {}, // Lock is UI-only for now
          ),
        );
      },
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
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
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }
}

class _LayerTile extends StatefulWidget {
  final LayerEntity layer;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDelete;
  final ValueChanged<double>? onOpacityChanged;
  final ValueChanged<BlendMode>? onBlendModeChanged;
  final VoidCallback? onToggleLock;

  const _LayerTile({
    required this.layer,
    required this.isSelected,
    required this.onTap,
    required this.onToggleVisibility,
    required this.onDelete,
    this.onOpacityChanged,
    this.onBlendModeChanged,
    this.onToggleLock,
  });

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile> {
  bool _expanded = false;

  IconData get _typeIcon => switch (widget.layer.type) {
        LayerType.image => Icons.image,
        LayerType.solidColor => Icons.format_color_fill,
        LayerType.text => Icons.text_fields,
        LayerType.shape => Icons.category,
        LayerType.group => Icons.folder,
        LayerType.adjustment => Icons.tune,
        LayerType.gradient => Icons.gradient,
        LayerType.sticker => Icons.emoji_emotions,
      };

  static const _blendModeLabels = {
    BlendMode.normal: 'Normal',
    BlendMode.multiply: 'Multiply',
    BlendMode.screen: 'Screen',
    BlendMode.overlay: 'Overlay',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: widget.isSelected
              ? Border.all(color: AppColors.brandPrimaryDark, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onToggleVisibility,
                      child: Icon(
                        widget.layer.visible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 16,
                        color: widget.layer.visible
                            ? Colors.white60
                            : Colors.white24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Icon(_typeIcon, size: 16, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.layer.name,
                            style: TextStyle(
                              color: widget.layer.visible
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.layer.opacity < 1.0)
                            Text(
                              '${(widget.layer.opacity * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white30, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    if (widget.isSelected)
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && widget.isSelected) _buildDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Text('Opacity',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppColors.brandPrimary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: widget.layer.opacity,
                    onChanged: (v) => widget.onOpacityChanged?.call(v),
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${(widget.layer.opacity * 100).round()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Text('Blend',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BlendMode>(
                      value: widget.layer.blendMode,
                      isExpanded: true,
                      dropdownColor: AppColors.editorSurface,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                      iconSize: 16,
                      iconEnabledColor: Colors.white54,
                      items: _blendModeLabels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) widget.onBlendModeChanged?.call(v);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              GestureDetector(
                onTap: widget.onToggleLock,
                child: Row(
                  children: [
                    Icon(
                      widget.layer.locked ? Icons.lock : Icons.lock_open,
                      size: 14,
                      color: widget.layer.locked
                          ? AppColors.brandPrimary
                          : Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.layer.locked ? 'Locked' : 'Unlocked',
                      style: TextStyle(
                        color: widget.layer.locked
                            ? Colors.white70
                            : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
