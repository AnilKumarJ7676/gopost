import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gopost_app/video_editor/domain/models/editor_layout_state.dart';

const double kMinSidebarWidth = 0;
const double kMaxSidebarWidth = 600;
const double kMinUpperFraction = 0.15;
const double kMaxUpperFraction = 0.85;
const double kLayoutMinTrackHeight = 24;
const double kLayoutMaxTrackHeight = 200;
const double kSidebarCollapseThreshold = 80;

const String _kLayoutKey = 'editor_layout_v1';
const String _kPresetsKey = 'editor_layout_presets_v1';

final editorLayoutProvider =
    StateNotifierProvider<EditorLayoutNotifier, EditorLayoutState>((ref) {
  return EditorLayoutNotifier();
});

class EditorLayoutNotifier extends StateNotifier<EditorLayoutState> {
  EditorLayoutNotifier() : super(const EditorLayoutState()) {
    _loadFromPrefs();
  }

  Map<String, EditorLayoutState> _savedPresets = {};

  // ---------------------------------------------------------------------------
  // Horizontal splitter: upper/timeline fraction
  // ---------------------------------------------------------------------------

  void setUpperFraction(double fraction) {
    state = state.copyWith(
      upperFraction: fraction.clamp(kMinUpperFraction, kMaxUpperFraction),
    );
    _saveToPrefs();
  }

  void dragHorizontalSplitter(double delta, double totalHeight) {
    if (totalHeight <= 0) return;
    final newFraction = state.upperFraction + delta / totalHeight;
    setUpperFraction(newFraction);
  }

  void resetHorizontalSplitter() {
    setUpperFraction(0.556);
  }

  // ---------------------------------------------------------------------------
  // Vertical splitter: sidebar width
  // ---------------------------------------------------------------------------

  void setSidebarWidth(double width) {
    final clamped = width.clamp(kMinSidebarWidth, kMaxSidebarWidth);
    // Snap to collapsed if below threshold
    final effective = clamped < kSidebarCollapseThreshold ? 0.0 : clamped;
    state = state.copyWith(sidebarWidth: effective);
    _saveToPrefs();
  }

  void dragVerticalSplitter(double delta) {
    setSidebarWidth(state.sidebarWidth + delta);
  }

  void resetVerticalSplitter() {
    setSidebarWidth(300);
  }

  void toggleSidebar() {
    if (state.sidebarWidth > 0) {
      setSidebarWidth(0);
    } else {
      setSidebarWidth(300);
    }
  }

  // ---------------------------------------------------------------------------
  // Per-track height
  // ---------------------------------------------------------------------------

  void setTrackHeight(int trackIndex, double height) {
    final clamped = height.clamp(kLayoutMinTrackHeight, kLayoutMaxTrackHeight);
    final updated = Map<int, double>.from(state.trackHeights);
    updated[trackIndex] = clamped;
    state = state.copyWith(trackHeights: updated);
  }

  void setAllTrackHeights(double height) {
    state = state.copyWith(
      defaultTrackHeight: height.clamp(kLayoutMinTrackHeight, kLayoutMaxTrackHeight),
      trackHeights: const {},
    );
  }

  void resetTrackHeight(int trackIndex) {
    final updated = Map<int, double>.from(state.trackHeights);
    updated.remove(trackIndex);
    state = state.copyWith(trackHeights: updated);
  }

  // ---------------------------------------------------------------------------
  // Maximize / restore
  // ---------------------------------------------------------------------------

  void toggleMaximize(String panelId) {
    if (state.maximizedPanelId == panelId) {
      state = state.copyWith(clearMaximized: true);
    } else {
      state = state.copyWith(maximizedPanelId: panelId);
    }
  }

  void clearMaximize() {
    state = state.copyWith(clearMaximized: true);
  }

  // ---------------------------------------------------------------------------
  // Layout presets
  // ---------------------------------------------------------------------------

  void applyPreset(LayoutPreset preset) {
    if (preset == LayoutPreset.custom) {
      final saved = _savedPresets['custom'];
      if (saved != null) {
        state = saved.copyWith(activePreset: LayoutPreset.custom);
      }
    } else {
      state = EditorLayoutState.forPreset(preset);
    }
    _saveToPrefs();
  }

  void saveCurrentAsPreset(String name) {
    _savedPresets[name] = state;
    _savePresetsToPrefs();
  }

  Map<String, EditorLayoutState> get savedPresets =>
      Map.unmodifiable(_savedPresets);

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kLayoutKey);
      if (json != null) {
        state = EditorLayoutState.fromJson(json);
      }

      final presetsJson = prefs.getString(_kPresetsKey);
      if (presetsJson != null) {
        final map = jsonDecode(presetsJson) as Map<String, dynamic>;
        _savedPresets = map.map(
          (k, v) => MapEntry(k, EditorLayoutState.fromMap(v as Map<String, dynamic>)),
        );
      }
    } catch (_) {
      // Corrupted prefs — use defaults
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLayoutKey, state.toJson());
    } catch (_) {}
  }

  Future<void> _savePresetsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _savedPresets.map((k, v) => MapEntry(k, v.toMap()));
      await prefs.setString(_kPresetsKey, jsonEncode(map));
    } catch (_) {}
  }
}
