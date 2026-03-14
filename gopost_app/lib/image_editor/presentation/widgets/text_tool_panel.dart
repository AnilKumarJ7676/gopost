import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/image_editor/presentation/providers/text_notifier.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Panel for adding and editing text layers.
class TextToolPanel extends ConsumerStatefulWidget {
  const TextToolPanel({super.key});

  @override
  ConsumerState<TextToolPanel> createState() => _TextToolPanelState();
}

class _TextToolPanelState extends ConsumerState<TextToolPanel> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(textToolProvider.notifier).loadFonts();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textState = ref.watch(textToolProvider);
    final canvasState = ref.watch(canvasProvider);
    final canvasId = canvasState.canvas?.canvasId;
    final canvasWidth = canvasState.canvas?.width ?? 0;

    ref.listen(textToolProvider, (prev, next) {
      if (prev?.config.text != next.config.text) {
        _textController.text = next.config.text;
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      }
    });

    if (_textController.text != textState.config.text) {
      _textController.text = textState.config.text;
    }

    return Container(
      height: 380,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(textState),
            const SizedBox(height: AppSpacing.md),
            _buildFontSizeSlider(textState),
            const SizedBox(height: AppSpacing.md),
            _buildFontStyleToggles(textState),
            const SizedBox(height: AppSpacing.md),
            _buildAlignmentButtons(textState),
            const SizedBox(height: AppSpacing.md),
            _buildColorPicker(textState),
            const SizedBox(height: AppSpacing.md),
            _buildShadowToggle(textState),
            const SizedBox(height: AppSpacing.lg),
            _buildActionButton(
              textState: textState,
              canvasId: canvasId,
              maxWidth: canvasWidth.toDouble(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextToolState textState) {
    return TextField(
      controller: _textController,
      maxLines: 3,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Enter text...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      onChanged: (value) => ref.read(textToolProvider.notifier).updateConfig(
            textState.config.copyWith(text: value),
          ),
    );
  }

  Widget _buildFontSizeSlider(TextToolState textState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Font size',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '${textState.config.fontSize.round()}',
              style: const TextStyle(
                color: AppColors.brandPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.brandPrimary,
            inactiveTrackColor: Colors.white24,
            thumbColor: AppColors.brandPrimary,
          ),
          child: Slider(
            value: textState.config.fontSize.clamp(8.0, 128.0),
            min: 8,
            max: 128,
            onChanged: (v) => ref.read(textToolProvider.notifier).updateConfig(
                  textState.config.copyWith(fontSize: v),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildFontStyleToggles(TextToolState textState) {
    final style = textState.config.style;
    return Row(
      children: [
        _StyleToggle(
          label: 'Bold',
          isActive: style == FontStyle.bold || style == FontStyle.boldItalic,
          onTap: () {
            final next = style == FontStyle.bold || style == FontStyle.boldItalic
                ? (style == FontStyle.boldItalic ? FontStyle.italic : FontStyle.normal)
                : (style == FontStyle.italic ? FontStyle.boldItalic : FontStyle.bold);
            ref.read(textToolProvider.notifier).updateConfig(
                  textState.config.copyWith(style: next),
                );
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        _StyleToggle(
          label: 'Italic',
          isActive: style == FontStyle.italic || style == FontStyle.boldItalic,
          onTap: () {
            final next = style == FontStyle.italic || style == FontStyle.boldItalic
                ? (style == FontStyle.boldItalic ? FontStyle.bold : FontStyle.normal)
                : (style == FontStyle.bold ? FontStyle.boldItalic : FontStyle.italic);
            ref.read(textToolProvider.notifier).updateConfig(
                  textState.config.copyWith(style: next),
                );
          },
        ),
      ],
    );
  }

  Widget _buildAlignmentButtons(TextToolState textState) {
    final alignment = textState.config.alignment;
    return Row(
      children: [
        const Text(
          'Align',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Row(
            children: [
              _AlignmentButton(
                icon: Icons.format_align_left,
                isActive: alignment == TextAlignment.left,
                onTap: () => ref.read(textToolProvider.notifier).updateConfig(
                      textState.config.copyWith(alignment: TextAlignment.left),
                    ),
              ),
              _AlignmentButton(
                icon: Icons.format_align_center,
                isActive: alignment == TextAlignment.center,
                onTap: () => ref.read(textToolProvider.notifier).updateConfig(
                      textState.config.copyWith(alignment: TextAlignment.center),
                    ),
              ),
              _AlignmentButton(
                icon: Icons.format_align_right,
                isActive: alignment == TextAlignment.right,
                onTap: () => ref.read(textToolProvider.notifier).updateConfig(
                      textState.config.copyWith(alignment: TextAlignment.right),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const List<({double r, double g, double b})> _presetColors = [
    (r: 1.0, g: 1.0, b: 1.0),
    (r: 0.0, g: 0.0, b: 0.0),
    (r: 1.0, g: 0.0, b: 0.0),
    (r: 0.0, g: 0.8, b: 0.0),
    (r: 0.0, g: 0.0, b: 1.0),
    (r: 1.0, g: 1.0, b: 0.0),
    (r: 1.0, g: 0.5, b: 0.0),
    (r: 0.8, g: 0.0, b: 0.8),
    (r: 0.5, g: 0.5, b: 0.5),
    (r: 0.6, g: 0.4, b: 0.2),
    (r: 0.0, g: 0.6, b: 0.6),
    (r: 0.6, g: 0.2, b: 0.4),
  ];

  Widget _buildColorPicker(TextToolState textState) {
    final config = textState.config;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _presetColors.map((c) {
        final isSelected = (config.colorR - c.r).abs() < 0.01 &&
            (config.colorG - c.g).abs() < 0.01 &&
            (config.colorB - c.b).abs() < 0.01;
        return GestureDetector(
          onTap: () => ref.read(textToolProvider.notifier).updateConfig(
                config.copyWith(
                  colorR: c.r,
                  colorG: c.g,
                  colorB: c.b,
                ),
              ),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                (c.r * 255).round(),
                (c.g * 255).round(),
                (c.b * 255).round(),
                1,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.brandPrimary : Colors.white38,
                width: isSelected ? 2.5 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShadowToggle(TextToolState textState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Shadow',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Switch(
          value: textState.config.hasShadow,
          onChanged: (v) => ref.read(textToolProvider.notifier).updateConfig(
                textState.config.copyWith(hasShadow: v),
              ),
          activeTrackColor: AppColors.brandPrimary,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required TextToolState textState,
    required int? canvasId,
    required double maxWidth,
  }) {
    final isEditing = textState.isEditing && textState.activeLayerId != null;
    final hasText = textState.config.text.trim().isNotEmpty;
    final canSubmit = hasText && canvasId != null && maxWidth > 0;

    return FilledButton(
      onPressed: canSubmit
          ? () async {
              final id = canvasId;
              if (isEditing) {
                await ref.read(textToolProvider.notifier).updateActiveTextLayer(
                      id,
                      maxWidth.round(),
                    );
              } else {
                await ref.read(textToolProvider.notifier).addTextLayer(
                      id,
                      maxWidth.round(),
                    );
              }
            }
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      child: Text(isEditing ? 'Update' : 'Add Text'),
    );
  }
}

class _StyleToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StyleToggle({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brandPrimary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.brandPrimary : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AlignmentButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AlignmentButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.brandPrimary.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
            border: const Border(
              right: BorderSide(
                color: Colors.white24,
                width: 0.5,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.brandPrimary : Colors.white54,
          ),
        ),
      ),
    );
  }
}
