import 'dart:io';
import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/image_editor/domain/repositories/project_repository.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:path_provider/path_provider.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectManager _projectManager;

  ProjectRepositoryImpl(this._projectManager);

  @override
  Future<void> saveProject(int canvasId, String filePath) async {
    try {
      await _projectManager.saveProject(canvasId, filePath);
    } catch (e) {
      throw ServerException(message: 'Save project failed: $e');
    }
  }

  @override
  Future<int> loadProject(String filePath) async {
    try {
      return await _projectManager.loadProject(filePath);
    } catch (e) {
      throw ServerException(message: 'Load project failed: $e');
    }
  }

  @override
  Future<String> getAutoSavePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final autoSaveDir = Directory('${dir.path}/GoPost/autosave');
    if (!await autoSaveDir.exists()) {
      await autoSaveDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${autoSaveDir.path}/project_$timestamp.gpimg';
  }
}
