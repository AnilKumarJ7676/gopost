import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

class GetTemplateDetailUseCase {
  final TemplateReadRepository _repository;

  const GetTemplateDetailUseCase(this._repository);

  Future<TemplateEntity> call(String id) {
    return _repository.getTemplateById(id);
  }
}
