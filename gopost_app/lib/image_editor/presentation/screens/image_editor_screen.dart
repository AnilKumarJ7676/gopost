import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/auth/presentation/providers/auth_providers.dart';
import 'package:gopost_app/auth/presentation/widgets/login_required_sheet.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/domain/entities/editor_tool.dart';
import 'package:gopost_app/image_editor/presentation/providers/canvas_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/image_editor/domain/commands/layer_commands.dart';
import 'package:gopost_app/image_editor/presentation/providers/undo_redo_notifier.dart';
import 'package:gopost_app/image_editor/presentation/widgets/save_as_template_dialog.dart';
import 'package:gopost_app/image_editor/presentation/screens/export_screen.dart';
import 'package:gopost_app/image_editor/presentation/widgets/adjustment_panel.dart';
import 'package:gopost_app/image_editor/presentation/widgets/canvas_preview.dart';
import 'package:gopost_app/image_editor/presentation/widgets/crop_panel.dart';
import 'package:gopost_app/image_editor/presentation/widgets/editor_toolbar.dart';
import 'package:gopost_app/image_editor/presentation/widgets/filter_panel.dart';
import 'package:gopost_app/image_editor/presentation/widgets/layer_panel.dart';
import 'package:gopost_app/image_editor/presentation/widgets/mask_panel.dart';
import 'package:gopost_app/image_editor/presentation/widgets/photo_picker_sheet.dart';
import 'package:gopost_app/image_editor/presentation/widgets/sticker_picker_sheet.dart';
import 'package:gopost_app/image_editor/presentation/widgets/text_tool_panel.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// S5-08: Main image editor screen.
/// Composes canvas preview, toolbar, layer panel, and top action bar.
class ImageEditorScreen extends ConsumerStatefulWidget {
  const ImageEditorScreen({super.key});

  @override
  ConsumerState<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends ConsumerState<ImageEditorScreen> {
  bool _showLayerPanel = false;
  String? _activeBottomPanel;

  bool get _isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final canvasState = ref.read(canvasProvider);
      if (canvasState.canvas == null) {
        _createDefaultCanvas();
      }
    });
  }

  Future<void> _createDefaultCanvas() async {
    const config = CanvasConfig(
      width: 1080,
      height: 1080,
      dpi: 72,
      transparentBackground: true,
    );
    await ref.read(canvasProvider.notifier).createCanvas(config);
    ref.read(undoRedoProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final activeTool = ref.watch(activeToolProvider);
    final canvasState = ref.watch(canvasProvider);

    ref.listen<EditorTool>(activeToolProvider, (prev, next) {
      if (next == EditorTool.layers) {
        setState(() {
          _showLayerPanel = !_showLayerPanel;
          _activeBottomPanel = null;
        });
      } else if (next == EditorTool.addImage) {
        _showPhotoPicker();
      } else if (next == EditorTool.filter) {
        setState(() {
          _activeBottomPanel = _activeBottomPanel == 'filter' ? null : 'filter';
          _showLayerPanel = false;
        });
      } else if (next == EditorTool.adjust) {
        setState(() {
          _activeBottomPanel = _activeBottomPanel == 'adjust' ? null : 'adjust';
          _showLayerPanel = false;
        });
      } else if (next == EditorTool.addText) {
        setState(() {
          _activeBottomPanel = _activeBottomPanel == 'text' ? null : 'text';
          _showLayerPanel = false;
        });
      } else if (next == EditorTool.sticker) {
        _showStickerPicker();
      } else if (next == EditorTool.crop) {
        setState(() {
          _activeBottomPanel = _activeBottomPanel == 'crop' ? null : 'crop';
          _showLayerPanel = false;
        });
      } else if (next == EditorTool.mask) {
        setState(() {
          _activeBottomPanel = _activeBottomPanel == 'mask' ? null : 'mask';
          _showLayerPanel = false;
        });
      } else if (next == EditorTool.export_) {
        _handleExport();
      }
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            () => ref.read(undoRedoProvider.notifier).undo(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            () => ref.read(undoRedoProvider.notifier).redo(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            () => ref.read(undoRedoProvider.notifier).undo(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            () => ref.read(undoRedoProvider.notifier).redo(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.editorBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, canvasState),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildMainArea(canvasState)),
                      if (_showLayerPanel) const LayerPanel(),
                    ],
                  ),
                ),
                if (_activeBottomPanel != null) _buildBottomPanel(),
                const EditorToolbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CanvasState canvasState) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitDialog(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            tooltip: 'Back',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              canvasState.canvas != null
                  ? '${canvasState.canvas!.width}×${canvasState.canvas!.height}'
                  : 'Image Editor',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _TopBarAction(
            icon: Icons.undo,
            tooltip: 'Undo (${_isMacOS ? '⌘' : 'Ctrl+'}Z)',
            enabled: ref.watch(undoRedoProvider.select((s) => s.canUndo)),
            onTap: () => ref.read(undoRedoProvider.notifier).undo(),
          ),
          _TopBarAction(
            icon: Icons.redo,
            tooltip: 'Redo (${_isMacOS ? '⇧⌘' : 'Ctrl+'}${_isMacOS ? 'Z' : 'Y'})',
            enabled: ref.watch(undoRedoProvider.select((s) => s.canRedo)),
            onTap: () => ref.read(undoRedoProvider.notifier).redo(),
          ),
          _TopBarAction(
            icon: Icons.save_outlined,
            tooltip: 'Save Project',
            onTap: _saveProject,
          ),
          _TopBarAction(
            icon: Icons.upload_file_outlined,
            tooltip: 'Save as Template',
            onTap: _saveAsTemplate,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildZoomIndicator(),
        ],
      ),
    );
  }

  Widget _buildZoomIndicator() {
    final viewport = ref.watch(
        canvasProvider.select((s) => s.viewport));
    final zoom = (viewport.zoom * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$zoom%',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }

  Widget _buildMainArea(CanvasState canvasState) {
    if (canvasState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (canvasState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.semanticErrorDark,
                size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              canvasState.error!,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: _createDefaultCanvas,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const CanvasPreview();
  }

  Widget _buildBottomPanel() {
    return switch (_activeBottomPanel) {
      'filter' => const FilterPanel(),
      'adjust' => const AdjustmentPanel(),
      'crop' => const CropPanel(),
      'text' => const TextToolPanel(),
      'mask' => const MaskPanel(),
      _ => const SizedBox.shrink(),
    };
  }

  void _handleExport() {
    final authState = ref.read(authStateProvider);
    if (authState.isGuest) {
      LoginRequiredSheet.show(context, feature: 'export your designs');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExportScreen()),
    );
  }

  void _saveProject() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Project saved'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final canvasState = ref.read(canvasProvider);
    if (canvasState.canvas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a canvas first')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const SaveAsTemplateDialog(),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved')),
      );
    }
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StickerPickerSheet(
        onStickerSelected: (emoji) {
          final notifier = ref.read(canvasProvider.notifier);
          ref.read(undoRedoProvider.notifier).execute(
                AddSolidLayerCommand(notifier, r: 1, g: 1, b: 1, a: 0),
              );
        },
      ),
    );
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PhotoPickerSheet(
        onImageSelected: (path, bytes) async {
          final notifier = ref.read(canvasProvider.notifier);
          final undoRedo = ref.read(undoRedoProvider.notifier);
          final importRepo =
              ref.read(imageImportRepositoryProvider);
          try {
            final decoded = await importRepo.decodeImageBytes(bytes);
            await undoRedo.execute(
              AddImageLayerCommand(notifier,
                  pixels: decoded.pixels,
                  width: decoded.width,
                  height: decoded.height),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Import failed: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final canvasState = ref.read(canvasProvider);
    if (canvasState.layers.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      ref.read(undoRedoProvider.notifier).clear();
      await ref.read(canvasProvider.notifier).destroyCanvas();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _TopBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _TopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18,
              color: enabled ? Colors.white54 : Colors.white12),
        ),
      ),
    );
  }
}
