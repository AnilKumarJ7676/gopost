import 'package:gopost_app/video_editor/data/datasources/video_project_local_datasource.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/repositories/video_project_repository.dart';

/// Concrete implementation of [VideoProjectRepository] backed by local storage.
/// Follows Single Responsibility: delegates persistence to the datasource.
class VideoProjectRepositoryImpl implements VideoProjectRepository {
  final VideoProjectLocalDatasource _datasource;

  VideoProjectRepositoryImpl(this._datasource);

  String? _autoSaveId;

  @override
  Future<String> saveProject(String name, VideoProject project) async {
    final id = await _datasource.save(name, project);
    _autoSaveId = id;
    return id;
  }

  @override
  Future<void> updateProject(String id, VideoProject project) =>
      _datasource.update(id, project);

  @override
  Future<VideoProject?> loadProject(String id) => _datasource.load(id);

  @override
  Future<List<SavedProjectMeta>> listProjects() => _datasource.list();

  @override
  Future<void> deleteProject(String id) async {
    await _datasource.delete(id);
    if (_autoSaveId == id) _autoSaveId = null;
  }

  @override
  Future<String?> getAutoSaveId() async => _autoSaveId;

  @override
  Future<void> autoSave(String id, VideoProject project) =>
      _datasource.update(id, project);
}
