import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

class GetCategoriesUseCase {
  final CategoryRepository _repository;

  const GetCategoriesUseCase(this._repository);

  Future<List<CategoryEntity>> call() {
    return _repository.getCategories();
  }
}
