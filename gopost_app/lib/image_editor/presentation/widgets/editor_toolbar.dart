import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';
import 'package:gopost_app/image_editor/domain/entities/editor_tool.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';

/// S5-08: Bottom toolbar with tool icons.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  static const _tools = [
    EditorTool.layers,
    EditorTool.addImage,
    EditorTool.addText,
    EditorTool.sticker,
    EditorTool.filter,
    EditorTool.adjust,
    EditorTool.crop,
    EditorTool.draw,
    EditorTool.export_,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(activeToolProvider);

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(
          top: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final tool = _tools[index];
          final isActive = activeTool == tool;

          return _ToolButton(
            tool: tool,
            isActive: isActive,
            onTap: () =>
                ref.read(activeToolProvider.notifier).selectTool(tool),
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final EditorTool tool;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.isActive,
    required this.onTap,
  });

  IconData get _icon => switch (tool) {
        EditorTool.select => Icons.touch_app,
        EditorTool.move => Icons.open_with,
        EditorTool.layers => Icons.layers,
        EditorTool.addImage => Icons.add_photo_alternate,
        EditorTool.addText => Icons.text_fields,
        EditorTool.addShape => Icons.category,
        EditorTool.sticker => Icons.emoji_emotions,
        EditorTool.filter => Icons.auto_fix_high,
        EditorTool.adjust => Icons.tune,
        EditorTool.crop => Icons.crop,
        EditorTool.mask => Icons.gradient,
        EditorTool.draw => Icons.brush,
        EditorTool.eraser => Icons.auto_fix_off,
        EditorTool.export_ => Icons.save_alt,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeonGlowIcon(
        isActive: isActive,
        baseColor: AppColors.brandPrimary,
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icon,
                size: 22,
                color: isActive
                    ? AppColors.brandPrimary
                    : Colors.white60,
              ),
              const SizedBox(height: 3),
              Text(
                tool.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? AppColors.brandPrimary
                      : Colors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
