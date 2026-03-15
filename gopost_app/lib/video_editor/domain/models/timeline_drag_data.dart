import 'package:flutter/material.dart';
import 'media_asset.dart';
import 'video_effect.dart';
import 'video_transition.dart';

sealed class TimelineDragData {
  const TimelineDragData();
}

class EffectDragData extends TimelineDragData {
  final EffectType effectType;
  final IconData icon;
  const EffectDragData({required this.effectType, required this.icon});
}

class TransitionDragData extends TimelineDragData {
  final TransitionType transitionType;
  final bool isIn;
  final IconData icon;
  const TransitionDragData({
    required this.transitionType,
    required this.icon,
    this.isIn = true,
  });
}

/// Dragged from the AdjustmentLayerPanel onto an effect track.
/// Creates an adjustment layer clip with the given configuration.
class AdjustmentClipDragData extends TimelineDragData {
  final AdjustmentClipData data;
  final IconData icon;
  final String label;
  const AdjustmentClipDragData({
    required this.data,
    required this.icon,
    required this.label,
  });
}

/// Dragged from the presets strip — shortcut for a preset-based adjustment clip.
class PresetClipDragData extends TimelineDragData {
  final PresetFilterId preset;
  final IconData icon;
  const PresetClipDragData({
    required this.preset,
    this.icon = Icons.filter,
  });
}

/// Dragged from the Media Pool onto the timeline.
class MediaAssetDragData extends TimelineDragData {
  final MediaAsset asset;
  const MediaAssetDragData({required this.asset});
}
