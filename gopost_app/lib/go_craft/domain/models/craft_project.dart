import 'package:flutter/foundation.dart';

enum CraftProjectType { image, video }

@immutable
class CraftProject {
  final String id;
  final String name;
  final CraftProjectType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int width;
  final int height;
  final String? thumbnailPath;

  final double? durationSeconds;
  final int? trackCount;
  final int? clipCount;
  final String? sourceTemplateName;

  const CraftProject({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.width,
    required this.height,
    this.thumbnailPath,
    this.durationSeconds,
    this.trackCount,
    this.clipCount,
    this.sourceTemplateName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'width': width,
        'height': height,
        'thumbnailPath': thumbnailPath,
        'durationSeconds': durationSeconds,
        'trackCount': trackCount,
        'clipCount': clipCount,
        'sourceTemplateName': sourceTemplateName,
      };

  factory CraftProject.fromMap(Map<String, dynamic> m) => CraftProject(
        id: m['id'] as String,
        name: m['name'] as String,
        type: CraftProjectType.values[m['type'] as int],
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
        width: m['width'] as int? ?? 1080,
        height: m['height'] as int? ?? 1080,
        thumbnailPath: m['thumbnailPath'] as String?,
        durationSeconds: (m['durationSeconds'] as num?)?.toDouble(),
        trackCount: m['trackCount'] as int?,
        clipCount: m['clipCount'] as int?,
        sourceTemplateName: m['sourceTemplateName'] as String?,
      );
}
