import 'dart:typed_data';

import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/template_browser/data/datasources/template_remote_datasource.dart';
import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/paginated_result.dart';
import 'package:gopost_app/template_browser/domain/entities/template_access.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';

/// OCP: Extend behavior by adding new datasources (cache) without modifying
/// existing code. LSP: Substitutable for any TemplateRepository consumer.
class TemplateRepositoryImpl implements TemplateRepository {
  final TemplateRemoteDataSource _remote;

  const TemplateRepositoryImpl({required TemplateRemoteDataSource remote})
      : _remote = remote;

  @override
  Future<PaginatedResult<TemplateEntity>> getTemplates(
      TemplateFilter filter) async {
    try {
      final result = await _remote.getTemplates(filter);
      return PaginatedResult(
        items: result.templates.map((m) => m.toEntity()).toList(),
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        totalCount: result.total,
      );
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<TemplateEntity> getTemplateById(String id) async {
    try {
      final model = await _remote.getTemplateById(id);
      return model.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<PaginatedResult<TemplateEntity>> getTemplatesByCategory(
    String categoryId,
    TemplateFilter filter,
  ) async {
    try {
      final result = await _remote.getTemplatesByCategory(categoryId, filter);
      return PaginatedResult(
        items: result.templates.map((m) => m.toEntity()).toList(),
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        totalCount: result.total,
      );
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<List<TemplateEntity>> getFeaturedTemplates() async {
    try {
      final filter = const TemplateFilter(
        sortBy: TemplateSortBy.popular,
        limit: 5,
      );
      final result = await _remote.getTemplates(filter);
      return result.templates.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<List<TemplateEntity>> getTrendingTemplates({int limit = 10}) async {
    try {
      final filter = TemplateFilter(
        sortBy: TemplateSortBy.trending,
        limit: limit,
      );
      final result = await _remote.getTemplates(filter);
      return result.templates.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<List<TemplateEntity>> getRecentTemplates({int limit = 10}) async {
    try {
      final filter = TemplateFilter(
        sortBy: TemplateSortBy.newest,
        limit: limit,
      );
      final result = await _remote.getTemplates(filter);
      return result.templates.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<List<CategoryEntity>> getCategories() async {
    try {
      final models = await _remote.getCategories();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<CategoryEntity> getCategoryById(String id) async {
    try {
      final model = await _remote.getCategoryById(id);
      return model.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<TemplateAccess> requestAccess(String templateId) async {
    try {
      final model = await _remote.requestAccess(templateId);
      return model.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<void> downloadTemplate({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await _remote.downloadFile(
        url: url,
        savePath: savePath,
        onProgress: onProgress,
      );
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<Uint8List> downloadTemplateToBytes({
    required String url,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      return await _remote.downloadToBytes(url: url, onProgress: onProgress);
    } on ServerException catch (e) {
      throw ServerFailure(
          message: e.message, code: e.code, statusCode: e.statusCode);
    } on NetworkException {
      throw const NetworkFailure();
    }
  }
}
