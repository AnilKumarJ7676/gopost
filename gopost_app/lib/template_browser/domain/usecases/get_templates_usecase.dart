import 'package:gopost_app/template_browser/domain/entities/paginated_result.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

class GetTemplatesUseCase {
  final TemplateReadRepository _repository;

  const GetTemplatesUseCase(this._repository);

  Future<PaginatedResult<TemplateEntity>> call(TemplateFilter filter) {
    return _repository.getTemplates(filter);
  }
}
