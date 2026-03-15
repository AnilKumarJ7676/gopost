import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/domain/entities/filter_entity.dart';
import 'package:gopost_app/image_editor/presentation/providers/adjustment_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';

/// Panel with individual adjustment sliders.
class AdjustmentPanel extends ConsumerStatefulWidget {
  const AdjustmentPanel({super.key});

  @override
  ConsumerState<AdjustmentPanel> createState() => _AdjustmentPanelState();
}

class _AdjustmentPanelState extends ConsumerState<AdjustmentPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adjustmentProvider.notifier).loadAdjustments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adjustmentState = ref.watch(adjustmentProvider);
    final canvasState = ref.watch(canvasProvider);
    final canvasId = canvasState.canvas?.canvasId;
    final layerId = canvasState.selectedLayerId;

    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (adjustmentState.hasChanges && canvasId != null && layerId != null)
            _buildResetAllButton(canvasId, layerId),
          Expanded(
            child: _buildAdjustmentList(
              adjustmentState: adjustmentState,
              canvasId: canvasId,
              layerId: layerId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetAllButton(int canvasId, int layerId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: TextButton.icon(
        onPressed: () => ref
            .read(adjustmentProvider.notifier)
            .resetAll(canvasId, layerId),
        icon: const Icon(Icons.refresh, size: 16, color: AppColors.brandPrimary),
        label: const Text(
          'Reset All',
          style: TextStyle(
            color: AppColors.brandPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentList({
    required AdjustmentState adjustmentState,
    required int? canvasId,
    required int? layerId,
  }) {
    if (adjustmentState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }

    if (adjustmentState.adjustments.isEmpty) {
      return const Center(
        child: Text(
          'No adjustments available',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: adjustmentState.adjustments.length,
      itemBuilder: (context, index) {
        final adj = adjustmentState.adjustments[index];
        return _AdjustmentSlider(
          adjustment: adj,
          canvasId: canvasId,
          layerId: layerId,
          onValueChanged: (v) {
            if (canvasId != null && layerId != null) {
              ref.read(adjustmentProvider.notifier).setAdjustment(
                    canvasId,
                    layerId,
                    adj.effectId,
                    v,
                  );
            }
          },
          onReset: () {
            if (canvasId != null && layerId != null) {
              ref.read(adjustmentProvider.notifier).resetAdjustment(
                    canvasId,
                    layerId,
                    adj.effectId,
                  );
            }
          },
          onRefreshPreview: () =>
              ref.read(canvasProvider.notifier).refreshPreview(),
        );
      },
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  final AdjustmentValue adjustment;
  final int? canvasId;
  final int? layerId;
  final ValueChanged<double> onValueChanged;
  final VoidCallback onReset;
  final VoidCallback? onRefreshPreview;

  const _AdjustmentSlider({
    required this.adjustment,
    required this.canvasId,
    required this.layerId,
    required this.onValueChanged,
    required this.onReset,
    this.onRefreshPreview,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeValue(adjustment.value);
    final displayValue = _formatValue(adjustment.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  adjustment.displayName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
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
              IconButton(
                onPressed: adjustment.isDefault ? null : onReset,
                icon: Icon(
                  Icons.refresh,
                  size: 18,
                  color: adjustment.isDefault
                      ? Colors.white24
                      : AppColors.brandPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.brandPrimary,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.brandPrimary,
            ),
            child: Slider(
              value: normalized.clamp(0.0, 1.0),
              onChanged: (v) {
                final actual = adjustment.minValue +
                    v * (adjustment.maxValue - adjustment.minValue);
                onValueChanged(actual);
              },
              onChangeEnd: (_) => onRefreshPreview?.call(),
            ),
          ),
        ],
      ),
    );
  }

  double _normalizeValue(double value) {
    final range = adjustment.maxValue - adjustment.minValue;
    if (range <= 0) return 0.5;
    return (value - adjustment.minValue) / range;
  }

  String _formatValue(double value) {
    if (value.abs() < 0.01) return '0';
    if (value.abs() >= 100) return value.round().toString();
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  }
}
