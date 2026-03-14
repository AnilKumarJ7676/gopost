import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_categories_usecase.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_featured_templates_usecase.dart';

class HomeState {
  final List<TemplateEntity> featured;
  final List<TemplateEntity> trending;
  final List<TemplateEntity> recent;
  final List<CategoryEntity> categories;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.featured = const [],
    this.trending = const [],
    this.recent = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    List<TemplateEntity>? featured,
    List<TemplateEntity>? trending,
    List<TemplateEntity>? recent,
    List<CategoryEntity>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      featured: featured ?? this.featured,
      trending: trending ?? this.trending,
      recent: recent ?? this.recent,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// SRP: Orchestrates loading home screen data from multiple use cases.
class HomeNotifier extends StateNotifier<HomeState> {
  final GetFeaturedTemplatesUseCase _getFeatured;
  final GetTrendingTemplatesUseCase _getTrending;
  final GetRecentTemplatesUseCase _getRecent;
  final GetCategoriesUseCase _getCategories;

  HomeNotifier({
    required GetFeaturedTemplatesUseCase getFeatured,
    required GetTrendingTemplatesUseCase getTrending,
    required GetRecentTemplatesUseCase getRecent,
    required GetCategoriesUseCase getCategories,
  })  : _getFeatured = getFeatured,
        _getTrending = getTrending,
        _getRecent = getRecent,
        _getCategories = getCategories,
        super(const HomeState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _getFeatured(),
        _getTrending(limit: 10),
        _getRecent(limit: 10),
        _getCategories(),
      ]);

      state = HomeState(
        featured: results[0] as List<TemplateEntity>,
        trending: results[1] as List<TemplateEntity>,
        recent: results[2] as List<TemplateEntity>,
        categories: results[3] as List<CategoryEntity>,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e, _) {
      // Catch any other exception (e.g. connection refused, parse errors)
      // so the app does not crash when the backend is unavailable.
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}
