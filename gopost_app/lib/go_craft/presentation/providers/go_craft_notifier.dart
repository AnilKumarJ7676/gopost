import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gopost_app/go_craft/data/image_project_local_datasource.dart';
import 'package:gopost_app/go_craft/domain/models/craft_project.dart';
import 'package:gopost_app/video_editor/domain/repositories/video_project_repository.dart';
import 'package:gopost_app/video_editor/presentation/providers/project_list_notifier.dart';

@immutable
class GoCraftState {
  final List<CraftProject> projects;
  final bool isLoading;
  final String? error;

  const GoCraftState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  GoCraftState copyWith({
    List<CraftProject>? projects,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      GoCraftState(
        projects: projects ?? this.projects,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class GoCraftNotifier extends StateNotifier<GoCraftState> {
  GoCraftNotifier(this._videoRepo, this._imageDatasource)
      : super(const GoCraftState()) {
    loadProjects();
  }

  final VideoProjectRepository _videoRepo;
  final ImageProjectLocalDatasource _imageDatasource;

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _loadVideoProjects(),
        _imageDatasource.list(),
      ]);

      final videoProjects = results[0] as List<CraftProject>;
      final imageProjects = results[1] as List<CraftProject>;

      final combined = [...videoProjects, ...imageProjects];
      combined.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      state = state.copyWith(projects: combined, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<CraftProject>> _loadVideoProjects() async {
    final metas = await _videoRepo.listProjects();
    return metas
        .map((m) => CraftProject(
              id: m.id,
              name: m.name,
              type: CraftProjectType.video,
              createdAt: m.createdAt,
              updatedAt: m.updatedAt,
              width: m.width,
              height: m.height,
              durationSeconds: m.durationSeconds,
              trackCount: m.trackCount,
              clipCount: m.clipCount,
            ))
        .toList();
  }

  Future<void> deleteProject(CraftProject project) async {
    if (project.type == CraftProjectType.video) {
      await _videoRepo.deleteProject(project.id);
    } else {
      await _imageDatasource.delete(project.id);
    }
    await loadProjects();
  }

  Future<void> refresh() => loadProjects();
}

final imageProjectDatasourceProvider =
    Provider<ImageProjectLocalDatasource>((ref) {
  return ImageProjectLocalDatasource();
});

final goCraftNotifierProvider =
    StateNotifierProvider<GoCraftNotifier, GoCraftState>((ref) {
  return GoCraftNotifier(
    ref.watch(videoProjectRepositoryProvider),
    ref.watch(imageProjectDatasourceProvider),
  );
});
