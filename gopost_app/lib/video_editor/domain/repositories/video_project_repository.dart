import 'package:flutter/foundation.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';

/// Saved project metadata for the project list.
@immutable
class SavedProjectMeta {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double durationSeconds;
  final int trackCount;
  final int clipCount;
  final int width;
  final int height;

  const SavedProjectMeta({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.durationSeconds,
    required this.trackCount,
    required this.clipCount,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'trackCount': trackCount,
    'clipCount': clipCount,
    'width': width,
    'height': height,
  };

  factory SavedProjectMeta.fromMap(Map<String, dynamic> m) => SavedProjectMeta(
    id: m['id'] as String,
    name: m['name'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    durationSeconds: (m['durationSeconds'] as num).toDouble(),
    trackCount: m['trackCount'] as int,
    clipCount: m['clipCount'] as int,
    width: m['width'] as int? ?? 1920,
    height: m['height'] as int? ?? 1080,
  );
}

/// Repository interface for video project persistence (DIP).
abstract class VideoProjectRepository {
  /// Save a project to local storage. Returns the project ID.
  Future<String> saveProject(String name, VideoProject project);

  /// Update an existing saved project.
  Future<void> updateProject(String id, VideoProject project);

  /// Load a saved project by ID.
  Future<VideoProject?> loadProject(String id);

  /// List all saved project metadata, ordered by last updated.
  Future<List<SavedProjectMeta>> listProjects();

  /// Delete a saved project.
  Future<void> deleteProject(String id);

  /// Check if the current project has unsaved changes (auto-save support).
  Future<String?> getAutoSaveId();

  /// Auto-save the current project state.
  Future<void> autoSave(String id, VideoProject project);
}
