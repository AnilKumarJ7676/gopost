import 'package:equatable/equatable.dart';

enum TemplateType { video, image }

enum TemplateStatus { draft, review, published, archived }

class TemplateEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final TemplateType type;
  final String categoryId;
  final String? creatorId;
  final TemplateStatus status;
  final String? thumbnailUrl;
  final String? previewUrl;
  final int width;
  final int height;
  final int? durationMs;
  final int layerCount;
  final List<EditableField> editableFields;
  final int usageCount;
  final bool isPremium;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final List<String> tags;
  final String? categoryName;
  final String? creatorName;
  final String? creatorAvatarUrl;

  const TemplateEntity({
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

  bool get isVideo => type == TemplateType.video;
  bool get isImage => type == TemplateType.image;

  String get dimensions => '${width}x$height';
  Duration? get duration =>
      durationMs != null ? Duration(milliseconds: durationMs!) : null;

  @override
  List<Object?> get props => [id];
}

class EditableField extends Equatable {
  final String key;
  final String label;
  final EditableFieldType fieldType;
  final String? defaultValue;

  const EditableField({
    required this.key,
    required this.label,
    required this.fieldType,
    this.defaultValue,
  });

  @override
  List<Object?> get props => [key, label, fieldType, defaultValue];
}

enum EditableFieldType { text, image, color, number }
