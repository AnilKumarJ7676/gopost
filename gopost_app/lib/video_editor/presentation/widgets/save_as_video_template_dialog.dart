import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';
import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';

/// Dialog for saving a video project as a reusable template.
/// Mirrors the image editor's SaveAsTemplateDialog pattern.
class SaveAsVideoTemplateDialog extends ConsumerStatefulWidget {
  const SaveAsVideoTemplateDialog({super.key});

  @override
  ConsumerState<SaveAsVideoTemplateDialog> createState() =>
      _SaveAsVideoTemplateDialogState();
}

class _VideoPlaceholder {
  int clipId;
  String key;
  String label;
  EditableFieldType fieldType;
  String defaultValue;

  _VideoPlaceholder({
    required this.clipId,
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
    'clip_id': clipId,
  };
}

class _SaveAsVideoTemplateDialogState extends ConsumerState<SaveAsVideoTemplateDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  final List<_VideoPlaceholder> _placeholders = [];
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
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _addPlaceholder(VideoClip clip) {
    if (_placeholders.any((p) => p.clipId == clip.id)) return;
    final type = switch (clip.sourceType) {
      ClipSourceType.video || ClipSourceType.image => EditableFieldType.image,
      ClipSourceType.title => EditableFieldType.text,
      ClipSourceType.color => EditableFieldType.color,
      ClipSourceType.adjustment => EditableFieldType.color,
    };
    setState(() {
      _placeholders.add(_VideoPlaceholder(
        clipId: clip.id,
        key: 'placeholder_clip_${clip.id}',
        label: clip.displayName,
        fieldType: type,
      ));
    });
  }

  void _removePlaceholder(int index) {
    setState(() => _placeholders.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a template name');
      return;
    }

    final project = ref.read(timelineNotifierProvider).project;
    if (project == null) {
      setState(() => _error = 'No project to save');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final content = _exportProjectJson(project);
      final contentBase64 = base64Encode(utf8.encode(content));
      final editableFields = _placeholders.isNotEmpty
          ? _placeholders.map((p) => p.toJson()).toList()
          : null;

      final datasource = ref.read(templateRemoteDataSourceProvider);
      await datasource.createFromEditor(
        name: name,
        description: _descCtrl.text.trim(),
        type: 'video',
        categoryId: _selectedCategoryId,
        tags: _parseTags(),
        width: project.width,
        height: project.height,
        layerCount: project.tracks.length,
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

  List<String> _parseTags() =>
      _tagsCtrl.text.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  String _exportProjectJson(VideoProject project) {
    final placeholderMap = {
      for (final p in _placeholders) p.clipId: p.key,
    };

    final projectMap = project.toMap();

    // Annotate clips that are placeholders
    for (final track in (projectMap['tracks'] as List<dynamic>)) {
      for (final clip in ((track as Map<String, dynamic>)['clips'] as List<dynamic>)) {
        final clipMap = clip as Map<String, dynamic>;
        final clipId = clipMap['id'] as int;
        if (placeholderMap.containsKey(clipId)) {
          clipMap['placeholderKey'] = placeholderMap[clipId];
        }
      }
    }

    return jsonEncode({
      'type': 'video',
      'project': projectMap,
      if (_placeholders.isNotEmpty)
        'editableFields': _placeholders.map((p) => p.toJson()).toList(),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_tagsCtrl.text.trim().isNotEmpty) 'tags': _parseTags(),
      if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineNotifierProvider);
    final allClips = state.project?.allClips ?? [];
    final assignedIds = _placeholders.map((p) => p.clipId).toSet();
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Save as Video Template'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(_nameCtrl, 'Template name *', 'My video template'),
              const SizedBox(height: 12),
              _textField(_descCtrl, 'Description', 'What this template is for'),
              const SizedBox(height: 12),
              _buildCategoryDropdown(scheme),
              const SizedBox(height: 12),
              _textField(_tagsCtrl, 'Tags (comma-separated)', 'social, promo, reel'),
              const SizedBox(height: 16),
              Text(
                'Placeholder Clips',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: scheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Mark clips that users can replace when customizing this template.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ..._placeholders.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final clip = allClips.where((c) => c.id == p.clipId).firstOrNull;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(Icons.movie_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clip?.displayName ?? 'Clip ${p.clipId}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${p.fieldType.name} placeholder',
                                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _removePlaceholder(idx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (allClips.any((c) => !assignedIds.contains(c.id)))
                PopupMenuButton<VideoClip>(
                  onSelected: _addPlaceholder,
                  itemBuilder: (_) => allClips
                      .where((c) => !assignedIds.contains(c.id))
                      .map((c) => PopupMenuItem(value: c, child: Text(c.displayName)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: scheme.onSurfaceVariant, size: 18),
                        const SizedBox(width: 4),
                        Text('Add Placeholder Clip',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(ColorScheme scheme) {
    if (_loadingCategories) {
      return const SizedBox(
        height: 56,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
      hint: Text('Select category', style: TextStyle(color: scheme.onSurfaceVariant)),
      items: _categories
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
          .toList(),
      onChanged: _saving ? null : (val) => setState(() => _selectedCategoryId = val),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      enabled: !_saving,
    );
  }
}
