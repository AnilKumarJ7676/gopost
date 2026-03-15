import 'package:equatable/equatable.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Domain entity mirroring engine's LayerInfo with identity semantics.
class LayerEntity extends Equatable {
  final int id;
  final LayerType type;
  final String name;
  final double opacity;
  final BlendMode blendMode;
  final bool visible;
  final bool locked;
  final double tx, ty;
  final double sx, sy;
  final double rotation;
  final int contentWidth;
  final int contentHeight;

  /// Non-null when this layer is a template placeholder. Value is the unique
  /// key that maps to an [EditableField].
  final String? placeholderKey;

  const LayerEntity({
    required this.id,
    required this.type,
    required this.name,
    this.opacity = 1.0,
    this.blendMode = BlendMode.normal,
    this.visible = true,
    this.locked = false,
    this.tx = 0,
    this.ty = 0,
    this.sx = 1,
    this.sy = 1,
    this.rotation = 0,
    this.contentWidth = 0,
    this.contentHeight = 0,
    this.placeholderKey,
  });

  bool get isPlaceholder => placeholderKey != null;

  LayerEntity copyWith({
    String? name,
    double? opacity,
    BlendMode? blendMode,
    bool? visible,
    bool? locked,
    double? tx,
    double? ty,
    double? sx,
    double? sy,
    double? rotation,
    String? placeholderKey,
    bool clearPlaceholder = false,
  }) {
    return LayerEntity(
      id: id,
      type: type,
      name: name ?? this.name,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      tx: tx ?? this.tx,
      ty: ty ?? this.ty,
      sx: sx ?? this.sx,
      sy: sy ?? this.sy,
      rotation: rotation ?? this.rotation,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      placeholderKey: clearPlaceholder ? null : (placeholderKey ?? this.placeholderKey),
    );
  }

  static LayerEntity fromLayerInfo(LayerInfo info) {
    return LayerEntity(
      id: info.id,
      type: info.type,
      name: info.name,
      opacity: info.opacity,
      blendMode: info.blendMode,
      visible: info.visible,
      locked: info.locked,
      tx: info.tx,
      ty: info.ty,
      sx: info.sx,
      sy: info.sy,
      rotation: info.rotation,
      contentWidth: info.contentWidth,
      contentHeight: info.contentHeight,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, name, opacity, blendMode, visible, locked,
       tx, ty, sx, sy, rotation, contentWidth, contentHeight, placeholderKey];
}
