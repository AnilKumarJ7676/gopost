import 'package:flutter/foundation.dart';

enum EffectCategory { colorTone, blurSharpen, distort, stylize }

enum EffectType {
  brightness(EffectCategory.colorTone, 'Brightness', -100, 100, 0),
  contrast(EffectCategory.colorTone, 'Contrast', -100, 100, 0),
  saturation(EffectCategory.colorTone, 'Saturation', -100, 100, 0),
  exposure(EffectCategory.colorTone, 'Exposure', -2.0, 2.0, 0),
  temperature(EffectCategory.colorTone, 'Temperature', -100, 100, 0),
  tint(EffectCategory.colorTone, 'Tint', -100, 100, 0),
  highlights(EffectCategory.colorTone, 'Highlights', -100, 100, 0),
  shadows(EffectCategory.colorTone, 'Shadows', -100, 100, 0),
  vibrance(EffectCategory.colorTone, 'Vibrance', -100, 100, 0),
  hueRotate(EffectCategory.colorTone, 'Hue', -180, 180, 0),
  gaussianBlur(EffectCategory.blurSharpen, 'Gaussian Blur', 0, 100, 0),
  radialBlur(EffectCategory.blurSharpen, 'Radial Blur', 0, 100, 0),
  tiltShift(EffectCategory.blurSharpen, 'Tilt Shift', 0, 100, 0),
  sharpen(EffectCategory.blurSharpen, 'Sharpen', 0, 100, 0),
  pixelate(EffectCategory.distort, 'Pixelate', 1, 50, 1),
  glitch(EffectCategory.distort, 'Glitch', 0, 100, 0),
  chromatic(EffectCategory.distort, 'Chromatic', 0, 100, 0),
  vignette(EffectCategory.stylize, 'Vignette', 0, 100, 0),
  grain(EffectCategory.stylize, 'Film Grain', 0, 100, 0),
  sepia(EffectCategory.stylize, 'Sepia', 0, 100, 0),
  invert(EffectCategory.stylize, 'Invert', 0, 100, 0),
  posterize(EffectCategory.stylize, 'Posterize', 2, 16, 16);

  final EffectCategory category;
  final String label;
  final double min;
  final double max;
  final double defaultValue;

  const EffectType(this.category, this.label, this.min, this.max, this.defaultValue);
}

@immutable
class VideoEffect {
  final EffectType type;
  final double value;
  final bool enabled;
  final double mix;

  const VideoEffect({
    required this.type,
    required this.value,
    this.enabled = true,
    this.mix = 1.0,
  });

  VideoEffect copyWith({double? value, bool? enabled, double? mix}) {
    return VideoEffect(
      type: type,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
      mix: mix ?? this.mix,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.index,
    'value': value,
    'enabled': enabled,
    'mix': mix,
  };

  factory VideoEffect.fromMap(Map<String, dynamic> map) => VideoEffect(
    type: EffectType.values[map['type'] as int],
    value: (map['value'] as num).toDouble(),
    enabled: map['enabled'] as bool? ?? true,
    mix: (map['mix'] as num?)?.toDouble() ?? 1.0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoEffect && type == other.type && value == other.value && enabled == other.enabled && mix == other.mix;

  @override
  int get hashCode => Object.hash(type, value, enabled, mix);
}

enum PresetFilterId {
  none('None'),
  natural('Natural'),
  daylight('Daylight'),
  goldenHour('Golden Hour'),
  overcast('Overcast'),
  portrait('Portrait'),
  softSkin('Soft Skin'),
  studio('Studio'),
  warmPortrait('Warm Portrait'),
  vintage('Vintage'),
  polaroid('Polaroid'),
  kodachrome('Kodachrome'),
  retro('Retro'),
  cinematic('Cinematic'),
  tealOrange('Teal & Orange'),
  noir('Noir'),
  desaturated('Desaturated'),
  bwClassic('B&W Classic'),
  bwHigh('B&W High Contrast'),
  bwSelenium('B&W Selenium'),
  bwInfrared('B&W Infrared');

  final String label;
  const PresetFilterId(this.label);
}

/// Visual style for an adjustment clip on the timeline.
enum AdjustmentClipStyle {
  /// Animated gradient waveform — used for color/tone adjustments.
  colorWave,
  /// Pulsing blur rings — used for blur/sharpen effects.
  blurPulse,
  /// Glitch-style scanlines — used for distort effects.
  distortScan,
  /// Artistic dot pattern — used for stylize effects.
  stylizeDots,
  /// Preset color swatch strip — used for color presets.
  presetStrip,
}

/// The data payload that an adjustment layer clip carries.
///
/// Sits on a `TrackType.effect` track above video and applies non-destructively
/// to all clips on lower tracks within its timeline range. Modelled after
/// Premiere Pro's Adjustment Layers and DaVinci Resolve's Adjustment Clips.
@immutable
class AdjustmentClipData {
  /// Active effects on this adjustment layer (brightness, blur, vignette, etc.).
  final List<VideoEffect> effects;

  /// Color grading values (merged with effects for the final composite).
  final ColorGrading colorGrading;

  /// Preset filter applied (if any).
  final PresetFilterId preset;

  /// Primary visual style on the timeline — inferred from the dominant effect.
  final AdjustmentClipStyle style;

  /// User-facing label shown on the clip (e.g. "Brightness +20" or "Cinematic").
  final String label;

  /// The signature color for the clip's timeline visualization.
  final int colorValue;

  const AdjustmentClipData({
    this.effects = const [],
    this.colorGrading = const ColorGrading(),
    this.preset = PresetFilterId.none,
    this.style = AdjustmentClipStyle.colorWave,
    this.label = 'Adjustment',
    this.colorValue = 0xFF6C63FF,
  });

  bool get isEmpty => effects.isEmpty && colorGrading.isDefault && preset == PresetFilterId.none;
  bool get hasEffects => effects.any((e) => e.enabled);
  bool get hasColorGrading => !colorGrading.isDefault;
  bool get hasPreset => preset != PresetFilterId.none;

  AdjustmentClipData copyWith({
    List<VideoEffect>? effects,
    ColorGrading? colorGrading,
    PresetFilterId? preset,
    AdjustmentClipStyle? style,
    String? label,
    int? colorValue,
  }) {
    return AdjustmentClipData(
      effects: effects ?? this.effects,
      colorGrading: colorGrading ?? this.colorGrading,
      preset: preset ?? this.preset,
      style: style ?? this.style,
      label: label ?? this.label,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() => {
    'effects': effects.map((e) => e.toMap()).toList(),
    'colorGrading': colorGrading.toMap(),
    'preset': preset.index,
    'style': style.index,
    'label': label,
    'colorValue': colorValue,
  };

  factory AdjustmentClipData.fromMap(Map<String, dynamic> m) {
    return AdjustmentClipData(
      effects: (m['effects'] as List<dynamic>?)
          ?.map((e) => VideoEffect.fromMap(e as Map<String, dynamic>))
          .toList() ?? const [],
      colorGrading: m['colorGrading'] != null
          ? ColorGrading.fromMap(m['colorGrading'] as Map<String, dynamic>)
          : const ColorGrading(),
      preset: PresetFilterId.values[m['preset'] as int? ?? 0],
      style: AdjustmentClipStyle.values[m['style'] as int? ?? 0],
      label: m['label'] as String? ?? 'Adjustment',
      colorValue: m['colorValue'] as int? ?? 0xFF6C63FF,
    );
  }

  /// Infer the best visual style from the current effect configuration.
  static AdjustmentClipStyle inferStyle(List<VideoEffect> effects, PresetFilterId preset) {
    if (preset != PresetFilterId.none) return AdjustmentClipStyle.presetStrip;
    if (effects.isEmpty) return AdjustmentClipStyle.colorWave;
    final dominant = effects.first.type;
    return switch (dominant.category) {
      EffectCategory.colorTone => AdjustmentClipStyle.colorWave,
      EffectCategory.blurSharpen => AdjustmentClipStyle.blurPulse,
      EffectCategory.distort => AdjustmentClipStyle.distortScan,
      EffectCategory.stylize => AdjustmentClipStyle.stylizeDots,
    };
  }

  /// Build a display label from effects.
  static String buildLabel(List<VideoEffect> effects, PresetFilterId preset) {
    if (preset != PresetFilterId.none) return preset.label;
    if (effects.isEmpty) return 'Adjustment';
    if (effects.length == 1) {
      final e = effects.first;
      return '${e.type.label} ${e.value >= 0 ? "+" : ""}${e.value.toStringAsFixed(0)}';
    }
    return '${effects.length} Effects';
  }

  /// Pick a signature color based on the dominant effect category.
  static int pickColor(List<VideoEffect> effects, PresetFilterId preset) {
    if (preset != PresetFilterId.none) return 0xFFAB47BC; // purple for presets
    if (effects.isEmpty) return 0xFF6C63FF; // default indigo
    return switch (effects.first.type.category) {
      EffectCategory.colorTone => 0xFFFF7043, // warm orange
      EffectCategory.blurSharpen => 0xFF26C6DA, // cyan
      EffectCategory.distort => 0xFFEF5350, // red
      EffectCategory.stylize => 0xFFAB47BC, // purple
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustmentClipData &&
          const ListEquality().equals(effects, other.effects) &&
          colorGrading == other.colorGrading &&
          preset == other.preset &&
          style == other.style &&
          label == other.label &&
          colorValue == other.colorValue;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(effects), colorGrading, preset, style, label, colorValue,
  );
}

/// Deep list equality helper for [AdjustmentClipData].
class ListEquality {
  const ListEquality();
  bool equals(List<VideoEffect> a, List<VideoEffect> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

@immutable
class ColorGrading {
  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double temperature;
  final double tint;
  final double highlights;
  final double shadows;
  final double vibrance;
  final double hue;

  const ColorGrading({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.exposure = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.vibrance = 0,
    this.hue = 0,
  });

  bool get isDefault =>
      brightness == 0 && contrast == 0 && saturation == 0 &&
      exposure == 0 && temperature == 0 && tint == 0 &&
      highlights == 0 && shadows == 0 && vibrance == 0 && hue == 0;

  ColorGrading copyWith({
    double? brightness, double? contrast, double? saturation,
    double? exposure, double? temperature, double? tint,
    double? highlights, double? shadows, double? vibrance, double? hue,
  }) {
    return ColorGrading(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      exposure: exposure ?? this.exposure,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      vibrance: vibrance ?? this.vibrance,
      hue: hue ?? this.hue,
    );
  }

  Map<String, dynamic> toMap() => {
    'brightness': brightness, 'contrast': contrast,
    'saturation': saturation, 'exposure': exposure,
    'temperature': temperature, 'tint': tint,
    'highlights': highlights, 'shadows': shadows,
    'vibrance': vibrance, 'hue': hue,
  };

  factory ColorGrading.fromMap(Map<String, dynamic> m) => ColorGrading(
    brightness: (m['brightness'] as num?)?.toDouble() ?? 0,
    contrast: (m['contrast'] as num?)?.toDouble() ?? 0,
    saturation: (m['saturation'] as num?)?.toDouble() ?? 0,
    exposure: (m['exposure'] as num?)?.toDouble() ?? 0,
    temperature: (m['temperature'] as num?)?.toDouble() ?? 0,
    tint: (m['tint'] as num?)?.toDouble() ?? 0,
    highlights: (m['highlights'] as num?)?.toDouble() ?? 0,
    shadows: (m['shadows'] as num?)?.toDouble() ?? 0,
    vibrance: (m['vibrance'] as num?)?.toDouble() ?? 0,
    hue: (m['hue'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorGrading &&
      brightness == other.brightness && contrast == other.contrast &&
      saturation == other.saturation && exposure == other.exposure &&
      temperature == other.temperature && tint == other.tint &&
      highlights == other.highlights && shadows == other.shadows &&
      vibrance == other.vibrance && hue == other.hue;

  @override
  int get hashCode => Object.hash(brightness, contrast, saturation, exposure,
      temperature, tint, highlights, shadows, vibrance, hue);
}
