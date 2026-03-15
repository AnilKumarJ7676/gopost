import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:gopost_app/go_craft/domain/models/craft_project.dart';

/// Tracks image project metadata in a local JSON registry.
/// The actual project data is saved by the image editor engine;
/// this datasource only manages the listing metadata.
class ImageProjectLocalDatasource {
  static const _registryDir = 'image_projects';
  static const _registryFile = 'registry.json';

  Future<File> _registryPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_registryDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$_registryFile');
  }

  Future<List<CraftProject>> list() async {
    final file = await _registryPath();
    if (!await file.exists()) return [];

    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      final projects = raw
          .map((e) => CraftProject.fromMap(e as Map<String, dynamic>))
          .toList();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (_) {
      return [];
    }
  }

  Future<void> register(CraftProject project) async {
    final projects = await list();
    final existing = projects.indexWhere((p) => p.id == project.id);
    if (existing >= 0) {
      projects[existing] = project;
    } else {
      projects.insert(0, project);
    }
    await _persist(projects);
  }

  Future<void> delete(String id) async {
    final projects = await list();
    projects.removeWhere((p) => p.id == id);
    await _persist(projects);
  }

  Future<void> _persist(List<CraftProject> projects) async {
    final file = await _registryPath();
    await file.writeAsString(jsonEncode(projects.map((p) => p.toMap()).toList()));
  }
}
