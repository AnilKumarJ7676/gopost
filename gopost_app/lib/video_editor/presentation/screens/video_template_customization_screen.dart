import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';

/// Screen for customizing a video template's placeholder fields.
/// Follows the same pattern as the image editor's TemplateCustomizationScreen.
class VideoTemplateCustomizationScreen extends ConsumerStatefulWidget {
  final String templateId;
  const VideoTemplateCustomizationScreen({super.key, required this.templateId});

  @override
  ConsumerState<VideoTemplateCustomizationScreen> createState() =>
      _VideoTemplateCustomizationScreenState();
}

class _VideoTemplateCustomizationScreenState
    extends ConsumerState<VideoTemplateCustomizationScreen> {
  bool _loading = true;
  String? _error;
  TemplateEntity? _template;
  final Map<String, dynamic> _customValues = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTemplate());
  }

  Future<void> _loadTemplate() async {
    try {
      final datasource = ref.read(templateRemoteDataSourceProvider);
      final model = await datasource.getTemplateById(widget.templateId);
      final template = model.toEntity();
      _template = template;

      for (final field in template.editableFields) {
        _customValues[field.key] = field.defaultValue ?? '';
      }

      if (!mounted) return;
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _resetField(String key) {
    final field = _template!.editableFields.firstWhere((f) => f.key == key);
    setState(() => _customValues[key] = field.defaultValue ?? '');
  }

  Future<void> _pickMedia(String key) async {
    final result = await _picker.pickVideo(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _customValues[key] = result.path);
    }
  }

  Future<void> _pickImage(String key) async {
    final result = await _picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _customValues[key] = result.path);
    }
  }

  void _export() {
    final params = <String, String>{
      'templateId': widget.templateId,
      if (_customValues.isNotEmpty)
        'customValues': base64Url.encode(utf8.encode(jsonEncode(_customValues))),
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    context.push('/editor/video${query.isEmpty ? '' : '?$query'}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_template?.name ?? 'Customize Template'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _template != null ? _export : null,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Export'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                  ),
                )
              : (_template?.editableFields.isEmpty ?? true)
                  ? _buildNoFields(scheme)
                  : _buildFieldEditor(theme, scheme),
    );
  }

  Widget _buildNoFields(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_off, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No customizable fields in this template.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldEditor(ThemeData theme, ColorScheme scheme) {
    final fields = _template!.editableFields;
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline, size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  '${_template!.width} x ${_template!.height}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                Text(
                  '${fields.length} customizable fields',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fields.length,
            itemBuilder: (context, index) {
              final field = fields[index];
              return _FieldEditor(
                field: field,
                currentValue: _customValues[field.key],
                onChanged: (val) => setState(() => _customValues[field.key] = val),
                onReset: () => _resetField(field.key),
                onPickMedia: () => field.fieldType == EditableFieldType.image
                    ? _pickImage(field.key)
                    : _pickMedia(field.key),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FieldEditor extends StatelessWidget {
  final EditableField field;
  final dynamic currentValue;
  final ValueChanged<dynamic> onChanged;
  final VoidCallback onReset;
  final VoidCallback onPickMedia;

  const _FieldEditor({
    required this.field,
    required this.currentValue,
    required this.onChanged,
    required this.onReset,
    required this.onPickMedia,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForType(field.fieldType), size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: onReset,
                  tooltip: 'Reset to default',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFieldInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldInput(BuildContext context) {
    switch (field.fieldType) {
      case EditableFieldType.text:
        return TextField(
          controller: TextEditingController(text: currentValue?.toString() ?? ''),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'Enter text...',
          ),
          onChanged: onChanged,
        );
      case EditableFieldType.image:
        final path = currentValue?.toString() ?? '';
        return OutlinedButton.icon(
          onPressed: onPickMedia,
          icon: const Icon(Icons.photo_library, size: 18),
          label: Text(
            path.isNotEmpty ? path.split('/').last : 'Choose media...',
            overflow: TextOverflow.ellipsis,
          ),
        );
      case EditableFieldType.color:
        return Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _parseColor(currentValue?.toString()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: currentValue?.toString() ?? '#FFFFFF'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: '#RRGGBB',
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        );
      case EditableFieldType.number:
        return TextField(
          controller: TextEditingController(text: currentValue?.toString() ?? '0'),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'Enter number...',
          ),
          keyboardType: TextInputType.number,
          onChanged: onChanged,
        );
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.white;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return Colors.white;
  }

  IconData _iconForType(EditableFieldType type) => switch (type) {
    EditableFieldType.text => Icons.text_fields,
    EditableFieldType.image => Icons.image,
    EditableFieldType.color => Icons.palette,
    EditableFieldType.number => Icons.numbers,
  };
}
