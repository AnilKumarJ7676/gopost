import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/video_editor/domain/models/editor_layout_state.dart';
import 'package:gopost_app/video_editor/presentation/providers/editor_layout_notifier.dart';
import 'package:gopost_app/video_editor/presentation/providers/project_list_notifier.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/video_editor/presentation/screens/export_screen.dart';
import 'package:gopost_app/video_editor/presentation/widgets/dock_system.dart';
import 'package:gopost_app/video_editor/presentation/widgets/editor_sidebar.dart';
import 'package:gopost_app/video_editor/presentation/widgets/resizable_split.dart';
import 'package:gopost_app/video_editor/presentation/widgets/save_as_video_template_dialog.dart';
import 'package:gopost_app/video_editor/presentation/widgets/timeline_panel.dart';
import 'package:gopost_app/video_editor/presentation/widgets/video_preview_panel.dart';

final _editorDarkTheme = ThemeData.dark(useMaterial3: true).copyWith(
  scaffoldBackgroundColor: const Color(0xFF0D0D1A),
  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF12122A),
    surfaceContainer: Color(0xFF16162E),
    surfaceContainerHigh: Color(0xFF1A1A34),
    surfaceContainerHighest: Color(0xFF20203A),
    surfaceContainerLowest: Color(0xFF0D0D1A),
    primary: Color(0xFF6C63FF),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF26C6DA),
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF26C6DA),
    secondaryContainer: Color(0xFFAB47BC),
    onSecondaryContainer: Colors.white,
    tertiary: Color(0xFF66BB6A),
    tertiaryContainer: Color(0xFFFF7043),
    onTertiaryContainer: Colors.white,
    error: Color(0xFFEF5350),
    outline: Color(0xFF303050),
    outlineVariant: Color(0xFF252540),
    onSurface: Color(0xFFE0E0F0),
    onSurfaceVariant: Color(0xFF8888A0),
  ),
  dividerColor: const Color(0xFF252540),
  cardColor: const Color(0xFF16162E),
  canvasColor: const Color(0xFF12122A),
  sliderTheme: const SliderThemeData(
    activeTrackColor: Color(0xFF6C63FF),
    inactiveTrackColor: Color(0xFF303050),
    thumbColor: Color(0xFF6C63FF),
    overlayColor: Color(0x206C63FF),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF1A1A34),
    selectedColor: const Color(0xFF6C63FF),
    labelStyle: const TextStyle(fontSize: 14, color: Color(0xFFD0D0E8)),
    secondaryLabelStyle: const TextStyle(fontSize: 14, color: Colors.white),
    side: const BorderSide(color: Color(0xFF303050)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Color(0xFF1A1A34),
    textStyle: TextStyle(color: Color(0xFFD0D0E8)),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xFF1A1A34),
    titleTextStyle: TextStyle(color: Color(0xFFE0E0F0), fontSize: 20, fontWeight: FontWeight.w600),
    contentTextStyle: TextStyle(color: Color(0xFF9090A8), fontSize: 15),
  ),
);

class VideoEditorScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const VideoEditorScreen({super.key, this.projectId});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  late final FocusNode _focusNode;
  final TextEditingController _projectNameCtrl = TextEditingController(text: 'Untitled project');

  // Floating panels
  final List<FloatingPanelState> _floatingPanels = [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initEditor());
  }

  Future<void> _initEditor() async {
    final projectId = widget.projectId;
    if (projectId != null && projectId.isNotEmpty) {
      final project = await ref.read(projectListNotifierProvider.notifier).loadProject(projectId);
      if (mounted && project != null) {
        await ref.read(timelineNotifierProvider.notifier).loadProject(project);
      } else if (mounted) {
        await ref.read(timelineNotifierProvider.notifier).initTimeline();
      }
    } else {
      await ref.read(timelineNotifierProvider.notifier).initTimeline();
    }
    if (mounted) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _projectNameCtrl.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final notifier = ref.read(timelineNotifierProvider.notifier);
    final key = event.logicalKey;
    final isCmd = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    if (isCmd && isShift && key == LogicalKeyboardKey.keyZ) { notifier.redo(); return KeyEventResult.handled; }
    if (isCmd && key == LogicalKeyboardKey.keyZ) { notifier.undo(); return KeyEventResult.handled; }
    if (isCmd && key == LogicalKeyboardKey.keyS) { _saveProject(ref.read(timelineNotifierProvider)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.space) { notifier.togglePlayback(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyJ) { notifier.shuttleReverse(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyK) { notifier.shuttleStop(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyL) { notifier.shuttleForward(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowLeft) { isShift ? notifier.stepBackwardN(10) : notifier.stepBackward(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowRight) { isShift ? notifier.stepForwardN(10) : notifier.stepForward(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.home) { notifier.jumpToStart(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.end) { notifier.jumpToEnd(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyI && !isCmd) { notifier.setInPoint(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyO && !isCmd) { notifier.setOutPoint(); return KeyEventResult.handled; }
    if (isAlt && key == LogicalKeyboardKey.keyX) { notifier.clearInOutPoints(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowUp) { notifier.jumpToPreviousSnapPoint(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowDown) { notifier.jumpToNextSnapPoint(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      final selected = ref.read(timelineNotifierProvider).selectedClipId;
      if (selected != null) { notifier.removeClip(selected); return KeyEventResult.handled; }
    }
    if (key == LogicalKeyboardKey.keyM && !isCmd) { notifier.addMarker(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.bracketLeft) { notifier.navigateToPreviousMarker(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.bracketRight) { notifier.navigateToNextMarker(); return KeyEventResult.handled; }
    if (isCmd && key == LogicalKeyboardKey.keyD) {
      final selected = ref.read(timelineNotifierProvider).selectedClipId;
      if (selected != null) { notifier.duplicateClip(selected); return KeyEventResult.handled; }
    }
    if (isCmd && (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd)) { notifier.zoomIn(); return KeyEventResult.handled; }
    if (isCmd && (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract)) { notifier.zoomOut(); return KeyEventResult.handled; }

    return KeyEventResult.ignored;
  }

  void _openExport() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportScreen()));
  }

  Future<void> _saveProject(TimelineState state) async {
    if (state.project == null) return;
    final nameCtrl = TextEditingController(text: _projectNameCtrl.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Project'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Project name', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    nameCtrl.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      _projectNameCtrl.text = result;
      await ref.read(projectListNotifierProvider.notifier).saveProject(result, state.project!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project saved'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _saveAsTemplate() {
    showDialog(context: context, builder: (_) => const SaveAsVideoTemplateDialog());
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(editorLayoutProvider);
    final layoutNotifier = ref.read(editorLayoutProvider.notifier);

    return Theme(
      data: _editorDarkTheme,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          body: Stack(
            children: [
              // Main editor layout
              _buildMainLayout(layout, layoutNotifier),
              // Floating panels overlay
              for (int i = 0; i < _floatingPanels.length; i++)
                FloatingPanel(
                  key: ValueKey('float_${_floatingPanels[i].id}'),
                  panelState: _floatingPanels[i],
                  title: _floatingPanels[i].title,
                  onStateChanged: (newState) {
                    setState(() => _floatingPanels[i] = newState);
                  },
                  onClose: () {
                    setState(() => _floatingPanels.removeAt(i));
                  },
                  onRedock: () {
                    setState(() => _floatingPanels.removeAt(i));
                  },
                  child: const Center(
                    child: Text('Panel content', style: TextStyle(color: Color(0xFF6B6B88))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainLayout(EditorLayoutState layout, EditorLayoutNotifier layoutNotifier) {
    // If a panel is maximized, show only that panel
    if (layout.maximizedPanelId != null) {
      return Column(
        children: [
          _buildTopBar(layout, layoutNotifier),
          Expanded(
            child: GestureDetector(
              onDoubleTap: () => layoutNotifier.clearMaximize(),
              child: _resolveMaximizedPanel(layout.maximizedPanelId!),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildTopBar(layout, layoutNotifier),
        Expanded(
          child: HorizontalSplit(
            fraction: layout.upperFraction,
            minTopFraction: kMinUpperFraction,
            maxTopFraction: kMaxUpperFraction,
            onFractionChanged: (f) => layoutNotifier.setUpperFraction(f),
            onDoubleTap: () => layoutNotifier.resetHorizontalSplitter(),
            // Upper area: icon rail + sidebar + preview
            top: Row(
              children: [
                const RepaintBoundary(child: EditorIconRail()),
                RepaintBoundary(
                  child: _buildSidebarWithSplitter(layout, layoutNotifier),
                ),
                const Expanded(child: RepaintBoundary(child: VideoPreviewPanel())),
              ],
            ),
            // Lower area: timeline
            bottom: const RepaintBoundary(child: TimelinePanel()),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarWithSplitter(EditorLayoutState layout, EditorLayoutNotifier layoutNotifier) {
    final sidebarWidth = layout.sidebarWidth;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sidebarWidth >= 1)
          SizedBox(
            width: sidebarWidth.clamp(0.0, kMaxSidebarWidth),
            child: const EditorPanelArea(),
          ),
        _SidebarSplitter(
          onDrag: (dx) {
            var newWidth = sidebarWidth + dx;
            if (newWidth < kSidebarCollapseThreshold) newWidth = 0;
            layoutNotifier.setSidebarWidth(
              newWidth.clamp(0, kMaxSidebarWidth),
            );
          },
          onDoubleTap: () => layoutNotifier.resetVerticalSplitter(),
        ),
      ],
    );
  }

  Widget _resolveMaximizedPanel(String panelId) {
    return switch (panelId) {
      'preview' => const VideoPreviewPanel(),
      'timeline' => const TimelinePanel(),
      'sidebar' => const EditorPanelArea(),
      _ => const VideoPreviewPanel(),
    };
  }

  Widget _buildTopBar(EditorLayoutState layout, EditorLayoutNotifier layoutNotifier) {
    final state = ref.watch(timelineNotifierProvider);
    final notifier = ref.read(timelineNotifierProvider.notifier);

    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E1C),
        border: Border(bottom: BorderSide(color: Color(0xFF252540), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF8888A0),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
          Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF252540)),
          const Icon(Icons.play_circle_filled_rounded, size: 24, color: Color(0xFF6C63FF)),
          const SizedBox(width: 10),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _projectNameCtrl,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFE0E0F0)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Layout preset selector
          LayoutPresetSelector(
            activePreset: layout.activePreset,
            onPresetSelected: (preset) => layoutNotifier.applyPreset(preset),
            onSaveCustom: () => layoutNotifier.saveCurrentAsPreset('custom'),
          ),
          const Spacer(),
          if (state.isReady) ...[
            if (state.project != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A34),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF303050)),
                  ),
                  child: Text(
                    '${state.project!.width}x${state.project!.height}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF8888A0)),
                  ),
                ),
              ),
            _topBarButton(icon: Icons.undo_rounded, tooltip: 'Undo (Ctrl+Z)', onPressed: state.canUndo ? notifier.undo : null),
            _topBarButton(icon: Icons.redo_rounded, tooltip: 'Redo (Ctrl+Shift+Z)', onPressed: state.canRedo ? notifier.redo : null),
            Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF252540)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, size: 24, color: Color(0xFF8888A0)),
              onSelected: (action) {
                switch (action) {
                  case 'save': _saveProject(state);
                  case 'template': _saveAsTemplate();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'save', child: Text('Save Project')),
                PopupMenuItem(value: 'template', child: Text('Save as Template')),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: state.project != null ? _openExport : null,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                minimumSize: const Size(0, 40),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _topBarButton({required IconData icon, required String tooltip, VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 24),
      color: onPressed != null ? const Color(0xFFB0B0C8) : const Color(0xFF404060),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    );
  }
}

class _SidebarSplitter extends StatefulWidget {
  final ValueChanged<double> onDrag;
  final VoidCallback? onDoubleTap;

  const _SidebarSplitter({required this.onDrag, this.onDoubleTap});

  @override
  State<_SidebarSplitter> createState() => _SidebarSplitterState();
}

class _SidebarSplitterState extends State<_SidebarSplitter> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _hovering || _dragging;
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
      onHorizontalDragEnd: (_) => setState(() => _dragging = false),
      onDoubleTap: widget.onDoubleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Container(
          width: 6,
          color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF252540),
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF404060),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
