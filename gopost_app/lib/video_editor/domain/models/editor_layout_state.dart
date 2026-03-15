import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Named layout presets.
enum LayoutPreset { edit, color, audio, custom }

/// Persisted layout configuration for the video editor.
@immutable
class EditorLayoutState {
  /// Fraction of total height for the upper area (preview + sidebar).
  /// The timeline gets (1 - upperFraction).
  /// Range: [0.15 .. 0.85]
  final double upperFraction;

  /// Width of the sidebar panel in pixels. 0 = collapsed.
  final double sidebarWidth;

  /// Per-track heights keyed by track index.
  /// Missing entries fall back to [defaultTrackHeight].
  final Map<int, double> trackHeights;

  /// Default height for tracks without a per-track override.
  final double defaultTrackHeight;

  /// Currently active layout preset.
  final LayoutPreset activePreset;

  /// Whether a panel is maximized (header double-click).
  /// null = no panel maximized.
  final String? maximizedPanelId;

  const EditorLayoutState({
    this.upperFraction = 0.556,
    this.sidebarWidth = 300,
    this.trackHeights = const {},
    this.defaultTrackHeight = 68,
    this.activePreset = LayoutPreset.edit,
    this.maximizedPanelId,
  });

  double get timelineFraction => 1.0 - upperFraction;

  EditorLayoutState copyWith({
    double? upperFraction,
    double? sidebarWidth,
    Map<int, double>? trackHeights,
    double? defaultTrackHeight,
    LayoutPreset? activePreset,
    String? maximizedPanelId,
    bool clearMaximized = false,
  }) {
    return EditorLayoutState(
      upperFraction: upperFraction ?? this.upperFraction,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      trackHeights: trackHeights ?? this.trackHeights,
      defaultTrackHeight: defaultTrackHeight ?? this.defaultTrackHeight,
      activePreset: activePreset ?? this.activePreset,
      maximizedPanelId: clearMaximized ? null : (maximizedPanelId ?? this.maximizedPanelId),
    );
  }

  double trackHeight(int trackIndex) {
    return trackHeights[trackIndex] ?? defaultTrackHeight;
  }

  Map<String, dynamic> toMap() => {
    'upperFraction': upperFraction,
    'sidebarWidth': sidebarWidth,
    'trackHeights': trackHeights.map((k, v) => MapEntry(k.toString(), v)),
    'defaultTrackHeight': defaultTrackHeight,
    'activePreset': activePreset.index,
  };

  factory EditorLayoutState.fromMap(Map<String, dynamic> m) {
    final rawHeights = m['trackHeights'] as Map<String, dynamic>? ?? {};
    return EditorLayoutState(
      upperFraction: (m['upperFraction'] as num?)?.toDouble() ?? 0.556,
      sidebarWidth: (m['sidebarWidth'] as num?)?.toDouble() ?? 300,
      trackHeights: rawHeights.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble())),
      defaultTrackHeight: (m['defaultTrackHeight'] as num?)?.toDouble() ?? 68,
      activePreset: LayoutPreset.values[(m['activePreset'] as int?) ?? 0],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory EditorLayoutState.fromJson(String json) {
    return EditorLayoutState.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Preset defaults.
  static const EditorLayoutState editPreset = EditorLayoutState(
    upperFraction: 0.556,
    sidebarWidth: 300,
    defaultTrackHeight: 68,
    activePreset: LayoutPreset.edit,
  );

  static const EditorLayoutState colorPreset = EditorLayoutState(
    upperFraction: 0.50,
    sidebarWidth: 340,
    defaultTrackHeight: 50,
    activePreset: LayoutPreset.color,
  );

  static const EditorLayoutState audioPreset = EditorLayoutState(
    upperFraction: 0.35,
    sidebarWidth: 260,
    defaultTrackHeight: 90,
    activePreset: LayoutPreset.audio,
  );

  static EditorLayoutState forPreset(LayoutPreset preset) {
    return switch (preset) {
      LayoutPreset.edit => editPreset,
      LayoutPreset.color => colorPreset,
      LayoutPreset.audio => audioPreset,
      LayoutPreset.custom => editPreset,
    };
  }
}

/// State for a floating (undocked) panel.
@immutable
class FloatingPanelState {
  final String id;
  final String title;
  final double x;
  final double y;
  final double width;
  final double height;

  const FloatingPanelState({
    required this.id,
    required this.title,
    this.x = 100,
    this.y = 100,
    this.width = 320,
    this.height = 400,
  });

  FloatingPanelState copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return FloatingPanelState(
      id: id,
      title: title,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// State for a tab group (multiple panels docked as tabs).
@immutable
class TabGroupState {
  final String groupId;
  final List<String> tabIds;
  final int activeIndex;

  const TabGroupState({
    required this.groupId,
    required this.tabIds,
    this.activeIndex = 0,
  });

  TabGroupState copyWith({
    List<String>? tabIds,
    int? activeIndex,
  }) {
    return TabGroupState(
      groupId: groupId,
      tabIds: tabIds ?? this.tabIds,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}
