import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';

class TemplateModel {
  final String id;
  final String name;
  final String description;
  final String type;
  final String categoryId;
  final String? creatorId;
  final String status;
  final String? thumbnailUrl;
  final String? previewUrl;
  final int width;
  final int height;
  final int? durationMs;
  final int layerCount;
  final List<EditableFieldModel> editableFields;
  final int usageCount;
  final bool isPremium;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? publishedAt;
  final List<String> tags;
  final String? categoryName;
  final String? creatorName;
  final String? creatorAvatarUrl;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.categoryId,
    this.creatorId,
    required this.status,
    this.thumbnailUrl,
    this.previewUrl,
    required this.width,
    required this.height,
    this.durationMs,
    required this.layerCount,
    this.editableFields = const [],
    this.usageCount = 0,
    this.isPremium = false,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.tags = const [],
    this.categoryName,
    this.creatorName,
    this.creatorAvatarUrl,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      type: json['type'] as String,
      categoryId: (json['category_id'] as String?) ?? '',
      creatorId: json['creator_id'] as String?,
      status: (json['status'] as String?) ?? 'published',
      thumbnailUrl: json['thumbnail_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 1080,
      height: (json['height'] as num?)?.toInt() ?? 1920,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      layerCount: (json['layer_count'] as num?)?.toInt() ?? 0,
      editableFields: (json['editable_fields'] as List<dynamic>?)
              ?.map((e) =>
                  EditableFieldModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      isPremium: (json['is_premium'] as bool?) ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      publishedAt: json['published_at'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      categoryName: json['category_name'] as String?,
      creatorName: json['creator_name'] as String?,
      creatorAvatarUrl: json['creator_avatar_url'] as String?,
    );
  }

  TemplateEntity toEntity() {
    return TemplateEntity(
      id: id,
      name: name,
      description: description,
      type: type == 'video' ? TemplateType.video : TemplateType.image,
      categoryId: categoryId,
      creatorId: creatorId,
      status: _parseStatus(status),
      thumbnailUrl: thumbnailUrl,
      previewUrl: previewUrl,
      width: width,
      height: height,
      durationMs: durationMs,
      layerCount: layerCount,
      editableFields: editableFields.map((e) => e.toEntity()).toList(),
      usageCount: usageCount,
      isPremium: isPremium,
      version: version,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      publishedAt: publishedAt != null ? DateTime.parse(publishedAt!) : null,
      tags: tags,
      categoryName: categoryName,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
    );
  }

  static TemplateStatus _parseStatus(String status) {
    return switch (status) {
      'draft' => TemplateStatus.draft,
      'review' => TemplateStatus.review,
      'published' => TemplateStatus.published,
      'archived' => TemplateStatus.archived,
      _ => TemplateStatus.published,
    };
  }
}

class EditableFieldModel {
  final String key;
  final String label;
  final String type;
  final String? defaultValue;

  const EditableFieldModel({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
  });

  factory EditableFieldModel.fromJson(Map<String, dynamic> json) {
    return EditableFieldModel(
      key: json['key'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      defaultValue: json['default_value'] as String?,
    );
  }

  EditableField toEntity() {
    return EditableField(
      key: key,
      label: label,
      fieldType: switch (type) {
        'text' => EditableFieldType.text,
        'image' => EditableFieldType.image,
        'color' => EditableFieldType.color,
        'number' => EditableFieldType.number,
        _ => EditableFieldType.text,
      },
      defaultValue: defaultValue,
    );
  }
}
