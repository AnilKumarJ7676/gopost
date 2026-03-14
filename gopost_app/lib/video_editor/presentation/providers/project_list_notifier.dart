import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gopost_app/video_editor/data/datasources/video_project_local_datasource.dart';
import 'package:gopost_app/video_editor/data/repositories/video_project_repository_impl.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/domain/repositories/video_project_repository.dart';

/// State for the "My Projects" screen.
@immutable
class ProjectListState {
  final List<SavedProjectMeta> projects;
  final bool isLoading;
  final String? error;

  const ProjectListState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectListState copyWith({
    List<SavedProjectMeta>? projects,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ProjectListState(
        projects: projects ?? this.projects,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Manages saved video projects list. Follows SRP: only project CRUD.
class ProjectListNotifier extends StateNotifier<ProjectListState> {
  ProjectListNotifier(this._repo) : super(const ProjectListState()) {
    loadProjects();
  }

  final VideoProjectRepository _repo;

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projects = await _repo.listProjects();
      state = state.copyWith(projects: projects, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String> saveProject(String name, VideoProject project) async {
    final id = await _repo.saveProject(name, project);
    await loadProjects();
    return id;
  }

  Future<void> updateProject(String id, VideoProject project) async {
    await _repo.updateProject(id, project);
    await loadProjects();
  }

  Future<VideoProject?> loadProject(String id) async {
    return _repo.loadProject(id);
  }

  Future<void> deleteProject(String id) async {
    await _repo.deleteProject(id);
    await loadProjects();
  }

  Future<void> autoSave(String id, VideoProject project) async {
    await _repo.autoSave(id, project);
  }
}

/// Provider for the local datasource.
final videoProjectDatasourceProvider = Provider<VideoProjectLocalDatasource>((ref) {
  return VideoProjectLocalDatasource();
});

/// Provider for the project repository (DIP: depends on abstract interface).
final videoProjectRepositoryProvider = Provider<VideoProjectRepository>((ref) {
  return VideoProjectRepositoryImpl(ref.watch(videoProjectDatasourceProvider));
});

/// Provider for the project list notifier.
final projectListNotifierProvider =
    StateNotifierProvider<ProjectListNotifier, ProjectListState>((ref) {
  return ProjectListNotifier(ref.watch(videoProjectRepositoryProvider));
});
