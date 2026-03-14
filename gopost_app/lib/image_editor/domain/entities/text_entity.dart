import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Domain entity for a text layer's editable configuration.
class TextLayerConfig {
  final String text;
  final String fontFamily;
  final FontStyle style;
  final double fontSize;
  final double colorR, colorG, colorB, colorA;
  final TextAlignment alignment;
  final double lineHeight;
  final double letterSpacing;
  final bool hasShadow;
  final double shadowOffsetX, shadowOffsetY, shadowBlur;
  final double shadowColorR, shadowColorG, shadowColorB, shadowColorA;
  final bool hasOutline;
  final double outlineWidth;
  final double outlineColorR, outlineColorG, outlineColorB, outlineColorA;

  const TextLayerConfig({
    this.text = '',
    this.fontFamily = 'System',
    this.style = FontStyle.normal,
    this.fontSize = 32,
    this.colorR = 1, this.colorG = 1, this.colorB = 1, this.colorA = 1,
    this.alignment = TextAlignment.center,
    this.lineHeight = 1.2,
    this.letterSpacing = 0,
    this.hasShadow = false,
    this.shadowOffsetX = 2, this.shadowOffsetY = 2, this.shadowBlur = 4,
    this.shadowColorR = 0, this.shadowColorG = 0,
    this.shadowColorB = 0, this.shadowColorA = 0.5,
    this.hasOutline = false,
    this.outlineWidth = 1,
    this.outlineColorR = 0, this.outlineColorG = 0,
    this.outlineColorB = 0, this.outlineColorA = 1,
  });

  TextLayerConfig copyWith({
    String? text,
    String? fontFamily,
    FontStyle? style,
    double? fontSize,
    double? colorR, double? colorG, double? colorB, double? colorA,
    TextAlignment? alignment,
    double? lineHeight,
    double? letterSpacing,
    bool? hasShadow,
    bool? hasOutline,
    double? outlineWidth,
  }) => TextLayerConfig(
    text: text ?? this.text,
    fontFamily: fontFamily ?? this.fontFamily,
    style: style ?? this.style,
    fontSize: fontSize ?? this.fontSize,
    colorR: colorR ?? this.colorR,
    colorG: colorG ?? this.colorG,
    colorB: colorB ?? this.colorB,
    colorA: colorA ?? this.colorA,
    alignment: alignment ?? this.alignment,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    hasShadow: hasShadow ?? this.hasShadow,
    shadowOffsetX: shadowOffsetX,
    shadowOffsetY: shadowOffsetY,
    shadowBlur: shadowBlur,
    shadowColorR: shadowColorR,
    shadowColorG: shadowColorG,
    shadowColorB: shadowColorB,
    shadowColorA: shadowColorA,
    hasOutline: hasOutline ?? this.hasOutline,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    outlineColorR: outlineColorR,
    outlineColorG: outlineColorG,
    outlineColorB: outlineColorB,
    outlineColorA: outlineColorA,
  );

  TextConfig toEngineConfig() => TextConfig(
    text: text,
    fontFamily: fontFamily,
    style: style,
    fontSize: fontSize,
    colorR: colorR, colorG: colorG, colorB: colorB, colorA: colorA,
    alignment: alignment,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
    hasShadow: hasShadow,
    shadowColorR: shadowColorR, shadowColorG: shadowColorG,
    shadowColorB: shadowColorB, shadowColorA: shadowColorA,
    shadowOffsetX: shadowOffsetX, shadowOffsetY: shadowOffsetY,
    shadowBlur: shadowBlur,
    hasOutline: hasOutline,
    outlineColorR: outlineColorR, outlineColorG: outlineColorG,
    outlineColorB: outlineColorB, outlineColorA: outlineColorA,
    outlineWidth: outlineWidth,
  );
}
