import 'dart:typed_data';

import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/paginated_result.dart';
import 'package:gopost_app/template_browser/domain/entities/template_access.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';

/// Read-only operations for browsing and searching templates.
/// ISP: Separated from write/admin operations.
abstract class TemplateReadRepository {
  Future<PaginatedResult<TemplateEntity>> getTemplates(TemplateFilter filter);
  Future<TemplateEntity> getTemplateById(String id);
  Future<PaginatedResult<TemplateEntity>> getTemplatesByCategory(
    String categoryId,
    TemplateFilter filter,
  );
  Future<List<TemplateEntity>> getFeaturedTemplates();
  Future<List<TemplateEntity>> getTrendingTemplates({int limit = 10});
  Future<List<TemplateEntity>> getRecentTemplates({int limit = 10});
}

/// Category-specific read operations.
abstract class CategoryRepository {
  Future<List<CategoryEntity>> getCategories();
  Future<CategoryEntity> getCategoryById(String id);
}

/// Template access/download operations requiring authentication.
abstract class TemplateAccessRepository {
  Future<TemplateAccess> requestAccess(String templateId);
  Future<void> downloadTemplate({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  });
  /// Download template to memory (for passing to native engine).
  Future<Uint8List> downloadTemplateToBytes({
    required String url,
    void Function(int received, int total)? onProgress,
  });
}

/// Composite interface for convenience when a single dependency is preferred.
abstract class TemplateRepository
    implements
        TemplateReadRepository,
        CategoryRepository,
        TemplateAccessRepository {}
