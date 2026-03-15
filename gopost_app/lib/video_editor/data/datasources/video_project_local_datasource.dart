import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:gopost_app/video_editor/domain/models/media_asset.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/repositories/video_project_repository.dart';

/// Local file-system data source for video projects.
/// Projects are stored as JSON in the app's documents directory.
class VideoProjectLocalDatasource {
  static const _projectsDir = 'video_projects';
  static const _metaFile = 'meta.json';
  static const _projectFile = 'project.json';
  static const _mediaPoolFile = 'media_pool.json';

  Future<Directory> _projectsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/$_projectsDir');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<Directory> _projectDir(String id) async {
    final root = await _projectsRoot();
    final dir = Directory('${root.path}/$id');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> save(String name, VideoProject project) async {
    final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final dir = await _projectDir(id);

    final meta = SavedProjectMeta(
      id: id,
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      durationSeconds: project.duration,
      trackCount: project.tracks.length,
      clipCount: project.allClips.length,
      width: project.width,
      height: project.height,
    );

    await File('${dir.path}/$_metaFile').writeAsString(jsonEncode(meta.toMap()));
    await File('${dir.path}/$_projectFile').writeAsString(jsonEncode(project.toMap()));
    return id;
  }

  Future<void> update(String id, VideoProject project) async {
    final dir = await _projectDir(id);
    final metaFile = File('${dir.path}/$_metaFile');
    if (!await metaFile.exists()) return;

    final existingMeta = SavedProjectMeta.fromMap(
      jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
    );
    final updatedMeta = SavedProjectMeta(
      id: id,
      name: existingMeta.name,
      createdAt: existingMeta.createdAt,
      updatedAt: DateTime.now(),
      durationSeconds: project.duration,
      trackCount: project.tracks.length,
      clipCount: project.allClips.length,
      width: project.width,
      height: project.height,
    );

    await metaFile.writeAsString(jsonEncode(updatedMeta.toMap()));
    await File('${dir.path}/$_projectFile').writeAsString(jsonEncode(project.toMap()));
  }

  Future<VideoProject?> load(String id) async {
    final dir = await _projectDir(id);
    final file = File('${dir.path}/$_projectFile');
    if (!await file.exists()) return null;

    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return VideoProject.fromMap(raw);
  }

  Future<List<SavedProjectMeta>> list() async {
    final root = await _projectsRoot();
    if (!await root.exists()) return [];

    final entries = root.listSync().whereType<Directory>();
    final results = <SavedProjectMeta>[];

    for (final dir in entries) {
      final metaFile = File('${dir.path}/$_metaFile');
      if (!await metaFile.exists()) continue;
      try {
        final raw = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        results.add(SavedProjectMeta.fromMap(raw));
      } catch (_) {
        // Skip corrupted metadata
      }
    }
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  Future<void> delete(String id) async {
    final dir = await _projectDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ---------------------------------------------------------------------------
  // Media Pool persistence
  // ---------------------------------------------------------------------------

  Future<void> saveMediaPool(String projectId, MediaPoolData poolData) async {
    final dir = await _projectDir(projectId);
    await File('${dir.path}/$_mediaPoolFile')
        .writeAsString(jsonEncode(poolData.toMap()));
  }

  Future<MediaPoolData?> loadMediaPool(String projectId) async {
    final dir = await _projectDir(projectId);
    final file = File('${dir.path}/$_mediaPoolFile');
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return MediaPoolData.fromMap(raw);
    } catch (_) {
      return null;
    }
  }
}
