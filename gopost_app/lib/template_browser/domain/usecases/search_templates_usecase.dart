import 'package:gopost_app/template_browser/domain/entities/paginated_result.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

class SearchTemplatesUseCase {
  final TemplateReadRepository _repository;

  const SearchTemplatesUseCase(this._repository);

  Future<PaginatedResult<TemplateEntity>> call({
    required String query,
    TemplateFilter filter = const TemplateFilter(),
  }) {
    return _repository.getTemplates(filter.copyWith(query: query));
  }
}
