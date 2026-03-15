import 'package:gopost_app/template_browser/domain/entities/template_access.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

class RequestTemplateAccessUseCase {
  final TemplateAccessRepository _repository;

  const RequestTemplateAccessUseCase(this._repository);

  Future<TemplateAccess> call(String templateId) {
    return _repository.requestAccess(templateId);
  }
}
