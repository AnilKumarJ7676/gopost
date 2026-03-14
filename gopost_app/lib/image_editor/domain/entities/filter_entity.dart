import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Domain entity for a preset filter.
class FilterPreset {
  final int index;
  final String name;
  final String category;
  final double intensity;

  const FilterPreset({
    required this.index,
    required this.name,
    required this.category,
    this.intensity = 100,
  });

  FilterPreset copyWith({double? intensity}) =>
      FilterPreset(
        index: index,
        name: name,
        category: category,
        intensity: intensity ?? this.intensity,
      );

  static FilterPreset fromInfo(PresetFilterInfo info) =>
      FilterPreset(index: info.index, name: info.name, category: info.category);
}

/// Domain entity for an adjustment value.
class AdjustmentValue {
  final String effectId;
  final String displayName;
  final double value;
  final double defaultValue;
  final double minValue;
  final double maxValue;

  const AdjustmentValue({
    required this.effectId,
    required this.displayName,
    required this.value,
    required this.defaultValue,
    required this.minValue,
    required this.maxValue,
  });

  AdjustmentValue copyWith({double? value}) =>
      AdjustmentValue(
        effectId: effectId,
        displayName: displayName,
        value: value ?? this.value,
        defaultValue: defaultValue,
        minValue: minValue,
        maxValue: maxValue,
      );

  bool get isDefault => (value - defaultValue).abs() < 0.01;
}

/// Grouped preset filters by category.
class FilterCategory {
  final String name;
  final List<FilterPreset> filters;

  const FilterCategory({required this.name, required this.filters});
}
