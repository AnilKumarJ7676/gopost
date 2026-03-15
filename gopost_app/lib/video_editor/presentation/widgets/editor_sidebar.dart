import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';
import 'package:gopost_app/video_editor/presentation/providers/editor_layout_notifier.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/video_editor/presentation/widgets/audio_controls_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/clip_inspector_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/color_grading_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/crop_transform_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/effects_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/keyframe_editor.dart';
import 'package:gopost_app/video_editor/presentation/widgets/markers_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/media_pool_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/speed_controls_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/text_editor_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/adjustment_layer_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/transition_picker.dart';

const double kPanelWidth = 300;

final _editorPanelOpenProvider = StateProvider<bool>((ref) => true);

const _tabs = <({BottomPanelTab tab, IconData icon, String label})>[
  (tab: BottomPanelTab.timeline, icon: Icons.video_library_outlined, label: 'Media'),
  (tab: BottomPanelTab.inspector, icon: Icons.info_outline_rounded, label: 'Inspector'),
  (tab: BottomPanelTab.text, icon: Icons.text_fields_rounded, label: 'Text'),
  (tab: BottomPanelTab.effects, icon: Icons.auto_fix_high, label: 'Effects'),
  (tab: BottomPanelTab.colorGrading, icon: Icons.palette_outlined, label: 'Color'),
  (tab: BottomPanelTab.transitions, icon: Icons.swap_horiz, label: 'Transitions'),
  (tab: BottomPanelTab.transform, icon: Icons.crop_rotate_rounded, label: 'Transform'),
  (tab: BottomPanelTab.speed, icon: Icons.speed_rounded, label: 'Speed'),
  (tab: BottomPanelTab.keyframes, icon: Icons.timeline, label: 'Keyframes'),
  (tab: BottomPanelTab.audio, icon: Icons.audiotrack, label: 'Audio'),
  (tab: BottomPanelTab.markers, icon: Icons.bookmark_outline_rounded, label: 'Markers'),
  (tab: BottomPanelTab.adjustmentLayers, icon: Icons.layers_outlined, label: 'Adjust'),
];

const double kIconRailWidth = 56;

// ---------------------------------------------------------------------------
// Vertical icon rail (left column, parallel to panel)
// ---------------------------------------------------------------------------
class EditorIconRail extends ConsumerWidget {
  const EditorIconRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(timelineNotifierProvider.select((s) => s.activePanel));
    final panelOpen = ref.watch(_editorPanelOpenProvider);

    return Container(
      width: kIconRailWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E1C),
        border: Border(right: BorderSide(color: Color(0xFF252540), width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconH = ((constraints.maxHeight - 8) / _tabs.length).clamp(44.0, 64.0);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  for (final item in _tabs)
                    _SidebarIcon(
                      icon: item.icon,
                      label: item.label,
                      isActive: activeTab == item.tab && panelOpen,
                      height: iconH,
                      onTap: () {
                        if (activeTab == item.tab) {
                          ref.read(_editorPanelOpenProvider.notifier).state = !panelOpen;
                        } else {
                          ref.read(timelineNotifierProvider.notifier).setActivePanel(item.tab);
                          if (!panelOpen) ref.read(_editorPanelOpenProvider.notifier).state = true;
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible panel area (between icon rail and timeline)
// ---------------------------------------------------------------------------
class EditorPanelArea extends ConsumerWidget {
  const EditorPanelArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(timelineNotifierProvider.select((s) => s.activePanel));
    final sidebarWidth = ref.watch(editorLayoutProvider.select((s) => s.sidebarWidth));
    final isMaximized = ref.watch(editorLayoutProvider.select((s) => s.maximizedPanelId)) == 'sidebar';

    if (sidebarWidth < 1 && !isMaximized) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
      ),
      child: Column(
        children: [
          _buildPanelHeader(ref, activeTab, isMaximized),
          Expanded(
            child: switch (activeTab) {
              BottomPanelTab.timeline => const MediaPoolPanel(),
              BottomPanelTab.inspector => const ClipInspectorPanel(),
              BottomPanelTab.text => const TextEditorPanel(),
              BottomPanelTab.effects => const EffectsPanel(),
              BottomPanelTab.colorGrading => const ColorGradingPanel(),
              BottomPanelTab.transitions => const TransitionPicker(),
              BottomPanelTab.transform => const CropTransformPanel(),
              BottomPanelTab.speed => const SpeedControlsPanel(),
              BottomPanelTab.keyframes => const KeyframeEditor(),
              BottomPanelTab.audio => const AudioControlsPanel(),
              BottomPanelTab.markers => const MarkersPanel(),
              BottomPanelTab.adjustmentLayers => const AdjustmentLayerPanel(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(WidgetRef ref, BottomPanelTab activeTab, bool isMaximized) {
    final label = _tabs.firstWhere((t) => t.tab == activeTab).label;

    return GestureDetector(
      onDoubleTap: () => ref.read(editorLayoutProvider.notifier).toggleMaximize('sidebar'),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF252540), width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 14, color: Color(0xFF505068)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE0E0F0)),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isMaximized ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                size: 18,
              ),
              color: const Color(0xFF8888A0),
              onPressed: () => ref.read(editorLayoutProvider.notifier).toggleMaximize('sidebar'),
              tooltip: isMaximized ? 'Restore' : 'Maximize',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: const Color(0xFF8888A0),
              onPressed: () => ref.read(editorLayoutProvider.notifier).setSidebarWidth(0),
              tooltip: 'Collapse',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared private widgets
// ---------------------------------------------------------------------------

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final double height;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    this.height = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: NeonGlowIcon(
          isActive: isActive,
          baseColor: const Color(0xFF6C63FF),
          child: Container(
            width: kIconRailWidth,
            height: height,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1A1A38) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: height > 50 ? 22 : 18,
                  color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF6B6B88),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? const Color(0xFFD0D0E8) : const Color(0xFF6B6B88),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
