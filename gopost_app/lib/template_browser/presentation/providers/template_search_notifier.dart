import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';
import 'package:gopost_app/template_browser/domain/usecases/search_templates_usecase.dart';

class TemplateSearchState {
  final List<TemplateEntity> results;
  final bool isSearching;
  final String? error;
  final String query;
  final bool hasMore;
  final String? nextCursor;
  final TemplateFilter filter;

  const TemplateSearchState({
    this.results = const [],
    this.isSearching = false,
    this.error,
    this.query = '',
    this.hasMore = false,
    this.nextCursor,
    this.filter = const TemplateFilter(),
  });

  TemplateSearchState copyWith({
    List<TemplateEntity>? results,
    bool? isSearching,
    String? error,
    String? query,
    bool? hasMore,
    String? nextCursor,
    TemplateFilter? filter,
    bool clearError = false,
  }) {
    return TemplateSearchState(
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      filter: filter ?? this.filter,
    );
  }
}

/// SRP: Handles debounced search with pagination support.
class TemplateSearchNotifier extends StateNotifier<TemplateSearchState> {
  final SearchTemplatesUseCase _searchTemplates;
  Timer? _debounceTimer;

  TemplateSearchNotifier({required SearchTemplatesUseCase searchTemplates})
      : _searchTemplates = searchTemplates,
        super(const TemplateSearchState());

  void search(String query) {
    state = state.copyWith(query: query);

    _debounceTimer?.cancel();

    if (query.isEmpty) {
      state = const TemplateSearchState();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    state = state.copyWith(isSearching: true, clearError: true);

    try {
      final result = await _searchTemplates(
        query: query,
        filter: state.filter,
      );
      if (state.query == query) {
        state = state.copyWith(
          results: result.items,
          isSearching: false,
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
        );
      }
    } on Failure catch (e) {
      state = state.copyWith(isSearching: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.isSearching || !state.hasMore || state.nextCursor == null) return;

    state = state.copyWith(isSearching: true);

    try {
      final result = await _searchTemplates(
        query: state.query,
        filter: state.filter.copyWith(cursor: state.nextCursor),
      );

      final existingIds = state.results.map((t) => t.id).toSet();
      final newItems =
          result.items.where((t) => !existingIds.contains(t.id)).toList();

      state = state.copyWith(
        results: [...state.results, ...newItems],
        isSearching: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    } on Failure catch (e) {
      state = state.copyWith(isSearching: false, error: e.message);
    }
  }

  void updateFilter(TemplateFilter filter) {
    state = state.copyWith(filter: filter);
    if (state.query.isNotEmpty) {
      _executeSearch(state.query);
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const TemplateSearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
