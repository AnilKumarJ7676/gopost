import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_template_detail_usecase.dart';

class TemplateDetailState {
  final TemplateEntity? template;
  final bool isLoading;
  final String? error;

  const TemplateDetailState({
    this.template,
    this.isLoading = false,
    this.error,
  });

  TemplateDetailState copyWith({
    TemplateEntity? template,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TemplateDetailState(
      template: template ?? this.template,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// SRP: Only manages loading a single template detail.
class TemplateDetailNotifier extends StateNotifier<TemplateDetailState> {
  final GetTemplateDetailUseCase _getDetail;

  TemplateDetailNotifier({required GetTemplateDetailUseCase getDetail})
      : _getDetail = getDetail,
        super(const TemplateDetailState());

  Future<void> load(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final template = await _getDetail(id);
      state = TemplateDetailState(template: template);
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }
}
