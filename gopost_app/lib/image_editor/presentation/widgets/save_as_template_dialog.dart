import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/domain/entities/canvas_entity.dart';
import 'package:gopost_app/image_editor/domain/entities/layer_entity.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';

class SaveAsTemplateDialog extends ConsumerStatefulWidget {
  const SaveAsTemplateDialog({super.key});

  @override
  ConsumerState<SaveAsTemplateDialog> createState() =>
      _SaveAsTemplateDialogState();
}

class _PlaceholderDef {
  int layerId;
  String key;
  String label;
  EditableFieldType fieldType;
  String defaultValue;

  _PlaceholderDef({
    required this.layerId,
    required this.key,
    required this.label,
    required this.fieldType,
    this.defaultValue = '',
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'field_type': fieldType.name,
        'default_value': defaultValue,
      };
}

class _SaveAsTemplateDialogState extends ConsumerState<SaveAsTemplateDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _saving = false;
  String? _error;
  final List<_PlaceholderDef> _placeholders = [];
  List<CategoryEntity> _categories = [];
  String? _selectedCategoryId;
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final datasource = ref.read(templateRemoteDataSourceProvider);
      final models = await datasource.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = models.map((m) => m.toEntity()).toList();
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _addPlaceholder(LayerEntity layer) {
    final existing = _placeholders.where((p) => p.layerId == layer.id);
    if (existing.isNotEmpty) return;

    final type = switch (layer.type.name) {
      'text' => EditableFieldType.text,
      'image' || 'sticker' => EditableFieldType.image,
      'solidColor' || 'gradient' => EditableFieldType.color,
      _ => EditableFieldType.text,
    };
    final key = 'placeholder_${layer.id}';
    setState(() {
      _placeholders.add(_PlaceholderDef(
        layerId: layer.id,
        key: key,
        label: layer.name,
        fieldType: type,
      ));
    });
  }

  void _removePlaceholder(int index) {
    setState(() => _placeholders.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a template name');
      return;
    }

    final canvasState = ref.read(canvasProvider);
    final canvas = canvasState.canvas;
    if (canvas == null) {
      setState(() => _error = 'No canvas to save');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final content = _exportProjectJson(canvas, canvasState.layers);
      final contentBase64 = base64Encode(utf8.encode(content));

      final editableFields = _placeholders.isNotEmpty
          ? _placeholders.map((p) => p.toJson()).toList()
          : null;

      final datasource = ref.read(templateRemoteDataSourceProvider);
      await datasource.createFromEditor(
        name: name,
        description: _descController.text.trim(),
        type: 'image',
        categoryId: _selectedCategoryId,
        tags: _parseTags(),
        width: canvas.width,
        height: canvas.height,
        layerCount: canvasState.layers.length,
        editableFields: editableFields,
        contentBase64: contentBase64,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  List<String> _parseTags() {
    return _tagsController.text
        .trim()
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _exportProjectJson(CanvasEntity canvas, List<LayerEntity> layers) {
    final placeholderMap = {
      for (final p in _placeholders) p.layerId: p.key,
    };
    final defaultValueMap = {
      for (final p in _placeholders) p.key: p.defaultValue,
    };

    final map = {
      'canvas': {
        'width': canvas.width,
        'height': canvas.height,
        'dpi': canvas.dpi,
        'transparentBackground': canvas.transparentBackground,
      },
      'layers': layers
          .map((l) => {
                'id': l.id,
                'type': l.type.name,
                'name': l.name,
                'opacity': l.opacity,
                'blendMode': l.blendMode.name,
                'visible': l.visible,
                'locked': l.locked,
                'tx': l.tx,
                'ty': l.ty,
                'sx': l.sx,
                'sy': l.sy,
                'rotation': l.rotation,
                'contentWidth': l.contentWidth,
                'contentHeight': l.contentHeight,
                if (placeholderMap.containsKey(l.id))
                  'placeholderKey': placeholderMap[l.id],
              })
          .toList(),
      if (_placeholders.isNotEmpty)
        'editableFields': _placeholders
            .map((p) => {
                  ...p.toJson(),
                  if (defaultValueMap[p.key]?.isNotEmpty ?? false)
                    'default_value': defaultValueMap[p.key],
                })
            .toList(),
      if (_descController.text.trim().isNotEmpty)
        'description': _descController.text.trim(),
      if (_tagsController.text.trim().isNotEmpty)
        'tags': _parseTags(),
      if (_selectedCategoryId != null)
        'category_id': _selectedCategoryId,
    };
    return jsonEncode(map);
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final layers = canvasState.layers;
    final assignedIds = _placeholders.map((p) => p.layerId).toSet();

    return AlertDialog(
      backgroundColor: AppColors.editorSurface,
      title: const Text(
        'Save as Template',
        style: TextStyle(color: AppColors.textPrimaryDark),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                  _nameController, 'Template name *', 'My template'),
              const SizedBox(height: AppSpacing.md),
              _buildTextField(
                  _descController, 'Description', 'What this template is for'),
              const SizedBox(height: AppSpacing.md),
              _buildCategoryDropdown(),
              const SizedBox(height: AppSpacing.md),
              _buildTextField(_tagsController, 'Tags (comma-separated)',
                  'social, story, promo'),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Placeholder Layers',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Mark layers that users can customize when using this template.',
                style:
                    TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._placeholders.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final layer =
                    layers.where((l) => l.id == p.layerId).firstOrNull;
                return _PlaceholderTile(
                  placeholder: p,
                  layerName: layer?.name ?? 'Layer ${p.layerId}',
                  onRemove: () => _removePlaceholder(idx),
                  onTypeChanged: (type) {
                    setState(() => _placeholders[idx].fieldType = type);
                  },
                  onLabelChanged: (label) {
                    _placeholders[idx].label = label;
                  },
                  onDefaultValueChanged: (val) {
                    _placeholders[idx].defaultValue = val;
                  },
                );
              }),
              if (layers.any((l) => !assignedIds.contains(l.id)))
                PopupMenuButton<LayerEntity>(
                  onSelected: _addPlaceholder,
                  itemBuilder: (_) => layers
                      .where((l) => !assignedIds.contains(l.id))
                      .map((l) => PopupMenuItem(
                            value: l,
                            child:
                                Text(l.name.isEmpty ? 'Layer ${l.id}' : l.name),
                          ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondaryDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add,
                            color: AppColors.textSecondaryDark, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Add Placeholder Layer',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.semanticError,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    if (_loadingCategories) {
      return const SizedBox(
        height: 56,
        child: Center(
            child: SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      dropdownColor: AppColors.editorSurface,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
      ),
      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14),
      hint: const Text('Select category',
          style: TextStyle(color: AppColors.textSecondaryDark)),
      items: _categories
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name),
              ))
          .toList(),
      onChanged: _saving
          ? null
          : (val) => setState(() => _selectedCategoryId = val),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
      ),
      style: const TextStyle(color: AppColors.textPrimaryDark),
      enabled: !_saving,
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  final _PlaceholderDef placeholder;
  final String layerName;
  final VoidCallback onRemove;
  final ValueChanged<EditableFieldType> onTypeChanged;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String> onDefaultValueChanged;

  const _PlaceholderTile({
    required this.placeholder,
    required this.layerName,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onLabelChanged,
    required this.onDefaultValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.editorSurface.withValues(alpha: 0.8),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers,
                    size: 16, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    layerName,
                    style: const TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textSecondaryDark,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: placeholder.label,
                    style: const TextStyle(
                        color: AppColors.textPrimaryDark, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(
                          color: AppColors.textSecondaryDark, fontSize: 11),
                    ),
                    onChanged: onLabelChanged,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<EditableFieldType>(
                  value: placeholder.fieldType,
                  dropdownColor: AppColors.editorSurface,
                  style: const TextStyle(
                      color: AppColors.textPrimaryDark, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: EditableFieldType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onTypeChanged(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              initialValue: placeholder.defaultValue,
              style: const TextStyle(
                  color: AppColors.textPrimaryDark, fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Default value',
                isDense: true,
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                    color: AppColors.textSecondaryDark, fontSize: 11),
                hintText: 'Initial value for this field',
                hintStyle: TextStyle(
                    color: AppColors.textSecondaryDark, fontSize: 11),
              ),
              onChanged: onDefaultValueChanged,
            ),
          ],
        ),
      ),
    );
  }
}
