import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';

/// Panel for mask editing on the selected layer.
class MaskPanel extends ConsumerStatefulWidget {
  const MaskPanel({super.key});

  @override
  ConsumerState<MaskPanel> createState() => _MaskPanelState();
}

class _MaskPanelState extends ConsumerState<MaskPanel> {
  bool _hasMask = false;
  double _brushSize = 20;
  double _hardness = 0.8;
  bool _isPaintMode = true;
  double _brushOpacity = 1.0;
  bool _redPreview = true;

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final hasSelectedLayer = canvasState.selectedLayerId != null;

    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: !hasSelectedLayer
          ? _buildNoLayerSelected()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMaskToggle(),
                  if (_hasMask) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildBrushModeToggle(),
                    const SizedBox(height: AppSpacing.md),
                    _buildBrushSizeSlider(),
                    const SizedBox(height: AppSpacing.sm),
                    _buildHardnessSlider(),
                    const SizedBox(height: AppSpacing.sm),
                    _buildOpacitySlider(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildActionButtons(),
                    const SizedBox(height: AppSpacing.md),
                    _buildPreviewToggle(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildNoLayerSelected() {
    return const Center(
      child: Text(
        'Select a layer to edit mask',
        style: TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMaskToggle() {
    return Row(
      children: [
        const Text(
          'Mask',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Switch(
          value: _hasMask,
          onChanged: (v) => setState(() => _hasMask = v),
          activeThumbColor: AppColors.brandPrimary,
        ),
      ],
    );
  }

  Widget _buildBrushModeToggle() {
    return Row(
      children: [
        const Text(
          'Mode',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Paint'),
                icon: Icon(Icons.brush, size: 16),
              ),
              ButtonSegment(
                value: false,
                label: Text('Erase'),
                icon: Icon(Icons.auto_fix_off, size: 16),
              ),
            ],
            selected: {_isPaintMode},
            onSelectionChanged: (s) => setState(() => _isPaintMode = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brandPrimaryContainerDark;
                }
                return AppColors.neutralSurfaceVariantDark;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brandPrimary;
                }
                return AppColors.textSecondaryDark;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrushSizeSlider() {
    return _SliderRow(
      label: 'Brush size',
      value: _brushSize,
      min: 1,
      max: 100,
      displayValue: _brushSize.round().toString(),
      onChanged: (v) => setState(() => _brushSize = v),
    );
  }

  Widget _buildHardnessSlider() {
    return _SliderRow(
      label: 'Hardness',
      value: _hardness,
      min: 0,
      max: 1,
      displayValue: (_hardness * 100).round().toString(),
      onChanged: (v) => setState(() => _hardness = v),
    );
  }

  Widget _buildOpacitySlider() {
    return _SliderRow(
      label: 'Opacity',
      value: _brushOpacity,
      min: 0,
      max: 1,
      displayValue: (_brushOpacity * 100).round().toString(),
      onChanged: (v) => setState(() => _brushOpacity = v),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            // Invert mask placeholder
          },
          icon: const Icon(Icons.invert_colors, size: 18),
          label: const Text('Invert Mask'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
            side: const BorderSide(color: AppColors.neutralOutlineDark),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            // Fill white placeholder
          },
          icon: const Icon(Icons.format_paint, size: 18),
          label: const Text('Fill White'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
            side: const BorderSide(color: AppColors.neutralOutlineDark),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            // Fill black placeholder
          },
          icon: const Icon(Icons.format_color_fill, size: 18),
          label: const Text('Fill Black'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
            side: const BorderSide(color: AppColors.neutralOutlineDark),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewToggle() {
    return Row(
      children: [
        const Text(
          'Preview',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Red')),
            ButtonSegment(value: false, label: Text('Black')),
          ],
          selected: {_redPreview},
          onSelectionChanged: (s) => setState(() => _redPreview = s.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.brandPrimaryContainerDark;
              }
              return AppColors.neutralSurfaceVariantDark;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.brandPrimary;
              }
              return AppColors.textSecondaryDark;
            }),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13,
              ),
            ),
            Text(
              displayValue,
              style: const TextStyle(
                color: AppColors.brandPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.brandPrimary,
            inactiveTrackColor: AppColors.neutralSurfaceVariantDark,
            thumbColor: AppColors.brandPrimary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
