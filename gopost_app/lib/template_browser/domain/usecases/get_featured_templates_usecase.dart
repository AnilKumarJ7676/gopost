import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

class GetFeaturedTemplatesUseCase {
  final TemplateReadRepository _repository;

  const GetFeaturedTemplatesUseCase(this._repository);

  Future<List<TemplateEntity>> call() {
    return _repository.getFeaturedTemplates();
  }
}

class GetTrendingTemplatesUseCase {
  final TemplateReadRepository _repository;

  const GetTrendingTemplatesUseCase(this._repository);

  Future<List<TemplateEntity>> call({int limit = 10}) {
    return _repository.getTrendingTemplates(limit: limit);
  }
}

class GetRecentTemplatesUseCase {
  final TemplateReadRepository _repository;

  const GetRecentTemplatesUseCase(this._repository);

  Future<List<TemplateEntity>> call({int limit = 10}) {
    return _repository.getRecentTemplates(limit: limit);
  }
}
