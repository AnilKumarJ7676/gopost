import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gopost_app/core/theme/app_colors.dart' show AppColors;
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/presentation/providers/canvas_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/image_editor/presentation/widgets/canvas_preview.dart';
import 'package:gopost_app/image_editor/presentation/screens/export_screen.dart';
import 'package:gopost_app/image_editor/domain/entities/text_entity.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';

Color _parseColor(String val) {
  if (val.isEmpty) return Colors.grey.shade800;
  try {
    final hex = val.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
  } catch (_) {}
  return Colors.grey.shade800;
}

/// S7-12: Template customization mode.
/// Opens a downloaded template, displays placeholder fields for the user to
/// edit, shows a live preview, and allows export of the customized result.
class TemplateCustomizationScreen extends ConsumerStatefulWidget {
  final String templateId;

  const TemplateCustomizationScreen({super.key, required this.templateId});

  @override
  ConsumerState<TemplateCustomizationScreen> createState() =>
      _TemplateCustomizationScreenState();
}

class _TemplateCustomizationScreenState
    extends ConsumerState<TemplateCustomizationScreen> {
  final Map<String, String> _fieldValues = {};
  final Map<String, String> _imagePaths = {};
  bool _initialized = false;
  int? _highlightedLayerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTemplate());
  }

  Future<void> _initTemplate() async {
    final canvasState = ref.read(canvasProvider);
    if (canvasState.canvas == null) {
      final detail = ref.read(templateDetailProvider(widget.templateId));
      final template = detail.template;
      if (template != null) {
        final config = CanvasConfig(
          width: template.width,
          height: template.height,
          dpi: 72,
          transparentBackground: false,
        );
        await ref.read(canvasProvider.notifier).createCanvas(config);
      }
    }

    final detail = ref.read(templateDetailProvider(widget.templateId));
    final template = detail.template;
    if (template != null) {
      for (final field in template.editableFields) {
        _fieldValues[field.key] = field.defaultValue ?? '';
      }
    }
    setState(() => _initialized = true);
  }

  void _updateField(String key, String value) {
    setState(() => _fieldValues[key] = value);
    _applyFieldToCanvas(key, value);
  }

  void _applyFieldToCanvas(String key, String value) {
    final canvasState = ref.read(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final canvas = canvasState.canvas;
    if (canvas == null) return;

    final layer = canvasState.layers
        .where((l) => l.placeholderKey == key)
        .firstOrNull;
    if (layer == null) return;

    final detail = ref.read(templateDetailProvider(widget.templateId));
    final field = detail.template?.editableFields
        .where((f) => f.key == key)
        .firstOrNull;
    if (field == null) return;

    switch (field.fieldType) {
      case EditableFieldType.text:
        final textRepo = ref.read(textRepositoryProvider);
        final config = TextLayerConfig(
          text: value.isEmpty ? (field.defaultValue ?? '') : value,
          fontSize: 24,
        );
        textRepo.updateTextLayer(canvas.canvasId, layer.id, config, canvas.width);
      case EditableFieldType.color:
        final color = _parseColor(value);
        canvasNotifier.setLayerOpacity(layer.id, color.a / 255.0);
      case EditableFieldType.number:
        final num = double.tryParse(value);
        if (num != null) {
          canvasNotifier.setLayerOpacity(layer.id, (num / 100.0).clamp(0.0, 1.0));
        }
      case EditableFieldType.image:
        break;
    }
  }

  void _resetField(EditableField field) {
    final defaultVal = field.defaultValue ?? '';
    setState(() {
      _fieldValues[field.key] = defaultVal;
      _imagePaths.remove(field.key);
    });
    _applyFieldToCanvas(field.key, defaultVal);
  }

  void _resetAllFields(TemplateEntity template) {
    setState(() {
      for (final field in template.editableFields) {
        _fieldValues[field.key] = field.defaultValue ?? '';
        _imagePaths.remove(field.key);
      }
    });
    for (final field in template.editableFields) {
      _applyFieldToCanvas(field.key, field.defaultValue ?? '');
    }
  }

  Future<void> _pickImage(String fieldKey) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (picked == null) return;

      final canvasState = ref.read(canvasProvider);
      final canvas = canvasState.canvas;
      if (canvas == null) return;

      final layer = canvasState.layers
          .where((l) => l.placeholderKey == fieldKey)
          .firstOrNull;

      final importRepo = ref.read(imageImportRepositoryProvider);
      final bytes = await picked.readAsBytes();
      final decoded = await importRepo.decodeImageBytes(bytes);

      if (layer != null) {
        final canvasNotifier = ref.read(canvasProvider.notifier);
        await canvasNotifier.removeLayer(layer.id);
      }
      final canvasNotifier = ref.read(canvasProvider.notifier);
      await canvasNotifier.addImageLayer(
        decoded.pixels,
        decoded.width,
        decoded.height,
      );

      if (!mounted) return;
      setState(() {
        _imagePaths[fieldKey] = picked.path;
        _fieldValues[fieldKey] = picked.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import image: $e')),
      );
    }
  }

  Future<void> _pickColor(String fieldKey) async {
    final currentColor = _parseColor(_fieldValues[fieldKey] ?? '');
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initialColor: currentColor),
    );
    if (result != null) {
      final hex =
          '#${result.red.toRadixString(16).padLeft(2, '0')}${result.green.toRadixString(16).padLeft(2, '0')}${result.blue.toRadixString(16).padLeft(2, '0')}';
      _updateField(fieldKey, hex);
    }
  }

  void _exportCustomized() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(templateDetailProvider(widget.templateId));
    final template = detailState.template;
    final canvasState = ref.watch(canvasProvider);

    if (!_initialized || detailState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.editorBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (template == null) {
      return Scaffold(
        backgroundColor: AppColors.editorBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.semanticErrorDark, size: 48),
              const SizedBox(height: AppSpacing.md),
              const Text('Template not found',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.editorBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, template),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                            child: _buildPreviewArea(canvasState, template)),
                        _buildPlaceholderPanel(template, width: 300),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                          child: _buildPreviewArea(canvasState, template)),
                      _buildPlaceholderPanel(template,
                          width: double.infinity, maxHeight: 240),
                    ],
                  );
                },
              ),
            ),
            _buildBottomBar(context, template),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TemplateEntity template) {
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
            onPressed: () => context.pop(),
            icon:
                const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            tooltip: 'Back',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Customize Template',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _resetAllFields(template),
            icon: const Icon(Icons.restart_alt, color: Colors.white38, size: 20),
            tooltip: 'Reset All',
          ),
          TextButton.icon(
            onPressed: _exportCustomized,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(
      CanvasState canvasState, TemplateEntity template) {
    if (canvasState.canvas == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        const CanvasPreview(),
        if (_highlightedLayerId != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PlaceholderOverlayPainter(
                  canvasWidth: canvasState.canvas!.width,
                  canvasHeight: canvasState.canvas!.height,
                  layers: canvasState.layers,
                  highlightedId: _highlightedLayerId,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderPanel(TemplateEntity template,
      {double width = 300, double? maxHeight}) {
    final fields = template.editableFields;
    if (fields.isEmpty) {
      return Container(
        width: width == double.infinity ? null : width,
        height: maxHeight,
        decoration: const BoxDecoration(
          color: AppColors.editorSurface,
          border: Border(
            left: BorderSide(color: Colors.white10, width: 0.5),
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'This template has no customizable fields.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      width: width == double.infinity ? null : width,
      height: maxHeight,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(
          left: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined,
                    color: AppColors.brandPrimaryDark, size: 16),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Edit Placeholders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${fields.length} field${fields.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: fields.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final field = fields[index];
                return _PlaceholderFieldEditor(
                  field: field,
                  value: _fieldValues[field.key] ?? '',
                  imagePath: _imagePaths[field.key],
                  onChanged: (v) => _updateField(field.key, v),
                  onReset: () => _resetField(field),
                  onPickImage: () => _pickImage(field.key),
                  onPickColor: () => _pickColor(field.key),
                  onFocusChanged: (focused) {
                    final canvasState = ref.read(canvasProvider);
                    final layer = canvasState.layers
                        .where((l) => l.placeholderKey == field.key)
                        .firstOrNull;
                    setState(() {
                      _highlightedLayerId = focused ? layer?.id : null;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, TemplateEntity template) {
    final fieldsModified = template.editableFields.any((f) {
      final current = _fieldValues[f.key] ?? '';
      return current != (f.defaultValue ?? '');
    });

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(
          top: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text('Cancel'),
            ),
          ),
          if (fieldsModified) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _resetAllFields(template),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white12),
                ),
                child: const Text('Reset'),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _exportCustomized,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Export Customized'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder field editor widget
// ---------------------------------------------------------------------------

class _PlaceholderFieldEditor extends StatefulWidget {
  final EditableField field;
  final String value;
  final String? imagePath;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;
  final VoidCallback onPickImage;
  final VoidCallback onPickColor;
  final ValueChanged<bool> onFocusChanged;

  const _PlaceholderFieldEditor({
    required this.field,
    required this.value,
    this.imagePath,
    required this.onChanged,
    required this.onReset,
    required this.onPickImage,
    required this.onPickColor,
    required this.onFocusChanged,
  });

  @override
  State<_PlaceholderFieldEditor> createState() =>
      _PlaceholderFieldEditorState();
}

class _PlaceholderFieldEditorState extends State<_PlaceholderFieldEditor> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      widget.onFocusChanged(_focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _PlaceholderFieldEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: widget.onFocusChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _fieldIcon(widget.field.fieldType),
                size: 14,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.field.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onReset,
                borderRadius: BorderRadius.circular(4),
                child: Tooltip(
                  message: 'Reset to default',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.restart_alt,
                      size: 14,
                      color: widget.value != (widget.field.defaultValue ?? '')
                          ? AppColors.brandPrimaryDark
                          : Colors.white24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return switch (widget.field.fieldType) {
      EditableFieldType.text => TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: AppColors.brandPrimary, width: 1.5),
            ),
            hintText: widget.field.defaultValue ?? 'Enter text...',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          ),
          maxLines: null,
          onChanged: widget.onChanged,
        ),
      EditableFieldType.color => GestureDetector(
          onTap: widget.onPickColor,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _parseColor(widget.value),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.palette_outlined,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  widget.value.isEmpty ? 'Tap to pick color' : widget.value,
                  style: TextStyle(
                    color: widget.value.isEmpty
                        ? Colors.white54
                        : _contrastText(_parseColor(widget.value)),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      EditableFieldType.image => Column(
          children: [
            if (widget.imagePath != null)
              Container(
                height: 60,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.semanticSuccessDark, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.imagePath!.split('/').last,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onPickImage,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(
                  widget.imagePath == null ? 'Choose Image' : 'Change Image',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white12),
                ),
              ),
            ),
          ],
        ),
      EditableFieldType.number => TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: AppColors.brandPrimary, width: 1.5),
            ),
            hintText: widget.field.defaultValue ?? '0',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          ),
          onChanged: widget.onChanged,
        ),
    };
  }

  Color _contrastText(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white70;
  }

  IconData _fieldIcon(EditableFieldType type) {
    return switch (type) {
      EditableFieldType.text => Icons.text_fields,
      EditableFieldType.image => Icons.image_outlined,
      EditableFieldType.color => Icons.palette_outlined,
      EditableFieldType.number => Icons.tag,
    };
  }
}

// ---------------------------------------------------------------------------
// Placeholder overlay painter
// ---------------------------------------------------------------------------

class _PlaceholderOverlayPainter extends CustomPainter {
  final int canvasWidth;
  final int canvasHeight;
  final List layers;
  final int? highlightedId;

  _PlaceholderOverlayPainter({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.layers,
    this.highlightedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightedId == null) return;

    final layer =
        layers.where((l) => l.id == highlightedId).firstOrNull;
    if (layer == null) return;

    final scaleX = size.width / canvasWidth;
    final scaleY = size.height / canvasHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (size.width - canvasWidth * scale) / 2;
    final offsetY = (size.height - canvasHeight * scale) / 2;

    final x = offsetX + layer.tx * scale;
    final y = offsetY + layer.ty * scale;
    final w = layer.contentWidth * layer.sx * scale;
    final h = layer.contentHeight * layer.sy * scale;

    final rect = Rect.fromLTWH(x, y, w, h);

    final paint = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);

    final border = Paint()
      ..color = AppColors.brandPrimaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _PlaceholderOverlayPainter old) {
    return old.highlightedId != highlightedId;
  }
}

// ---------------------------------------------------------------------------
// Color picker dialog
// ---------------------------------------------------------------------------

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _lightness;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initialColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
  }

  Color get _currentColor =>
      HSLColor.fromAHSL(1, _hue, _saturation, _lightness).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.editorSurface,
      title: const Text('Pick Color',
          style: TextStyle(color: AppColors.textPrimaryDark)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSlider('Hue', _hue, 0, 360, (v) => setState(() => _hue = v)),
          _buildSlider('Saturation', _saturation, 0, 1,
              (v) => setState(() => _saturation = v)),
          _buildSlider('Lightness', _lightness, 0, 1,
              (v) => setState(() => _lightness = v)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _presetColors)
                GestureDetector(
                  onTap: () {
                    final hsl = HSLColor.fromColor(c);
                    setState(() {
                      _hue = hsl.hue;
                      _saturation = hsl.saturation;
                      _lightness = hsl.lightness;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentColor),
          child: const Text('Select'),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: AppColors.brandPrimary,
            inactiveColor: Colors.white12,
          ),
        ),
      ],
    );
  }

  static const _presetColors = [
    Color(0xFFFF0000),
    Color(0xFFFF6B00),
    Color(0xFFFFD700),
    Color(0xFF00CC00),
    Color(0xFF0088FF),
    Color(0xFF6C5CE7),
    Color(0xFFFF69B4),
    Color(0xFFFFFFFF),
    Color(0xFF888888),
    Color(0xFF000000),
  ];
}
