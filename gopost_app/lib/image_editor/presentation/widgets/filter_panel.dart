import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';
import 'package:gopost_app/image_editor/domain/entities/filter_entity.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/image_editor/presentation/providers/filter_notifier.dart';

/// Bottom panel for browsing and applying preset filters.
class FilterPanel extends ConsumerStatefulWidget {
  const FilterPanel({super.key});

  @override
  ConsumerState<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<FilterPanel> {
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(filterProvider.notifier).loadPresets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(filterProvider);
    final canvasState = ref.watch(canvasProvider);
    final canvasId = canvasState.canvas?.canvasId;
    final layerId = canvasState.selectedLayerId;

    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoryTabs(filterState.categories),
          Expanded(
            child: _buildFilterGrid(
              filterState: filterState,
              categories: filterState.categories,
              canvasId: canvasId,
              layerId: layerId,
            ),
          ),
          if (filterState.activePresetIndex != null && canvasId != null && layerId != null)
            _buildIntensitySlider(
              intensity: filterState.intensity,
              canvasId: canvasId,
              layerId: layerId,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(List<FilterCategory> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: NeonGlow(
              isActive: isSelected,
              baseColor: AppColors.brandPrimary,
              borderRadius: 20,
              glowSpread: 1,
              glowBlur: 8,
              child: FilterChip(
                label: Text(categories[index].name),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategoryIndex = index),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                selectedColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                side: BorderSide(
                  color: isSelected ? AppColors.brandPrimary : Colors.white24,
                  width: isSelected ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.brandPrimary : Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFilterGrid({
    required FilterState filterState,
    required List<FilterCategory> categories,
    required int? canvasId,
    required int? layerId,
  }) {
    if (filterState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }

    if (categories.isEmpty || _selectedCategoryIndex >= categories.length) {
      return const Center(
        child: Text(
          'No filters available',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    final category = categories[_selectedCategoryIndex];
    final filters = category.filters;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final preset = filters[index];
        final isActive = filterState.activePresetIndex == preset.index;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: GestureDetector(
            onTap: () async {
              if (canvasId == null || layerId == null) return;
              await ref.read(filterProvider.notifier).selectPreset(
                    canvasId,
                    layerId,
                    preset.index,
                  );
              final err = ref.read(filterProvider).error;
              if (mounted && err != null && err.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Filter failed: $err')),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NeonGlow(
                  isActive: isActive,
                  baseColor: AppColors.brandPrimary,
                  borderRadius: AppRadius.sm,
                  glowSpread: 1.5,
                  glowBlur: 10,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: isActive ? null : Border.all(
                        color: Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          color: isActive ? AppColors.brandPrimary : Colors.white70,
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: 72,
                  child: Text(
                    preset.name,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntensitySlider({
    required double intensity,
    required int canvasId,
    required int layerId,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Intensity',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '${intensity.round()}',
                style: const TextStyle(
                  color: AppColors.brandPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
              value: intensity.clamp(0.0, 100.0),
              min: 0,
              max: 100,
              onChanged: (v) => ref.read(filterProvider.notifier).setIntensity(
                    canvasId,
                    layerId,
                    v,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
