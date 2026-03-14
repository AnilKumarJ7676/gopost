import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_templates_usecase.dart';

class TemplateListState {
  final List<TemplateEntity> templates;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final TemplateFilter filter;
  final String? nextCursor;
  final bool hasMore;

  const TemplateListState({
    this.templates = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.filter = const TemplateFilter(),
    this.nextCursor,
    this.hasMore = true,
  });

  TemplateListState copyWith({
    List<TemplateEntity>? templates,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    TemplateFilter? filter,
    String? nextCursor,
    bool? hasMore,
    bool clearError = false,
  }) {
    return TemplateListState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// SRP: Only manages the paginated template list state.
class TemplateListNotifier extends StateNotifier<TemplateListState> {
  final GetTemplatesUseCase _getTemplates;

  TemplateListNotifier({required GetTemplatesUseCase getTemplates})
      : _getTemplates = getTemplates,
        super(const TemplateListState());

  Future<void> loadTemplates({TemplateFilter? filter}) async {
    final activeFilter = filter ?? state.filter;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      filter: activeFilter,
    );

    try {
      final result = await _getTemplates(activeFilter.copyWith(clearCursor: true));
      state = state.copyWith(
        templates: result.items,
        isLoading: false,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final filter = state.filter.copyWith(cursor: state.nextCursor);
      final result = await _getTemplates(filter);

      final existingIds = state.templates.map((t) => t.id).toSet();
      final newItems =
          result.items.where((t) => !existingIds.contains(t.id)).toList();

      state = state.copyWith(
        templates: [...state.templates, ...newItems],
        isLoadingMore: false,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    }
  }

  void updateFilter(TemplateFilter filter) {
    loadTemplates(filter: filter.copyWith(clearCursor: true));
  }

  Future<void> refresh() async {
    await loadTemplates(filter: state.filter.copyWith(clearCursor: true));
  }
}
