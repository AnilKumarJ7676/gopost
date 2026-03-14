import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/template_browser/data/models/category_model.dart';
import 'package:gopost_app/template_browser/data/models/template_access_model.dart';
import 'package:gopost_app/template_browser/data/models/template_model.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';

abstract class TemplateRemoteDataSource {
  Future<({List<TemplateModel> templates, String? nextCursor, bool hasMore, int total})>
      getTemplates(TemplateFilter filter);
  Future<TemplateModel> getTemplateById(String id);
  Future<({List<TemplateModel> templates, String? nextCursor, bool hasMore, int total})>
      getTemplatesByCategory(String categoryId, TemplateFilter filter);
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel> getCategoryById(String id);
  Future<TemplateAccessModel> requestAccess(String templateId);
  /// Save as template from editor. Sends name, dimensions, layer count,
  /// optional placeholders, and base64-encoded project content packed
  /// server-side into encrypted `.gpt` format.
  Future<TemplateModel> createFromEditor({
    required String name,
    String description = '',
    required String type,
    String? categoryId,
    List<String> tags = const [],
    required int width,
    required int height,
    required int layerCount,
    List<Map<String, dynamic>>? editableFields,
    required String contentBase64,
  });
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  });
  Future<Uint8List> downloadToBytes({
    required String url,
    void Function(int received, int total)? onProgress,
  });
}

class TemplateRemoteDataSourceImpl implements TemplateRemoteDataSource {
  final Dio _dio;

  const TemplateRemoteDataSourceImpl(this._dio);

  @override
  Future<({List<TemplateModel> templates, String? nextCursor, bool hasMore, int total})>
      getTemplates(TemplateFilter filter) async {
    try {
      final response = await _dio.get(
        '/templates',
        queryParameters: filter.toQueryParameters(),
      );
      return _parsePaginatedResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<TemplateModel> getTemplateById(String id) async {
    try {
      final response = await _dio.get('/templates/$id');
      return TemplateModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<({List<TemplateModel> templates, String? nextCursor, bool hasMore, int total})>
      getTemplatesByCategory(String categoryId, TemplateFilter filter) async {
    try {
      final response = await _dio.get(
        '/categories/$categoryId/templates',
        queryParameters: filter.toQueryParameters(),
      );
      return _parsePaginatedResponse(response);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      final list = response.data['data'] as List<dynamic>;
      return list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    try {
      final response = await _dio.get('/categories/$id');
      return CategoryModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<TemplateAccessModel> requestAccess(String templateId) async {
    try {
      final response = await _dio.post('/templates/$templateId/access');
      return TemplateAccessModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<TemplateModel> createFromEditor({
    required String name,
    String description = '',
    required String type,
    String? categoryId,
    List<String> tags = const [],
    required int width,
    required int height,
    required int layerCount,
    List<Map<String, dynamic>>? editableFields,
    required String contentBase64,
  }) async {
    try {
      final response = await _dio.post(
        '/admin/templates/create-from-editor',
        data: {
          'name': name,
          if (description.isNotEmpty) 'description': description,
          'type': type,
          if (categoryId != null) 'category_id': categoryId,
          if (tags.isNotEmpty) 'tags': tags,
          'width': width,
          'height': height,
          'layer_count': layerCount,
          if (editableFields != null && editableFields.isNotEmpty)
            'editable_fields': editableFields,
          'content_base64': contentBase64,
        },
      );
      return TemplateModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Uint8List> downloadToBytes({
    required String url,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final response = await Dio().get<dynamic>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onProgress,
      );
      final data = response.data;
      if (data == null) throw const ServerException(message: 'Empty response');
      if (data is Uint8List) return data;
      return Uint8List.fromList(List<int>.from(data as List<dynamic>));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  ({List<TemplateModel> templates, String? nextCursor, bool hasMore, int total})
      _parsePaginatedResponse(Response<dynamic> response) {
    final data = response.data;
    final list = (data['data'] as List<dynamic>?) ?? [];
    final pagination = data['pagination'] as Map<String, dynamic>?;

    return (
      templates: list
          .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: pagination?['next_cursor'] as String?,
      hasMore: (pagination?['has_more'] as bool?) ?? false,
      total: (pagination?['total'] as num?)?.toInt() ?? list.length,
    );
  }

  ServerException _mapDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Server error';
    String? code;

    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        message = (error['message'] as String?) ?? 'Server error';
        code = error['code'] as String?;
      }
    }

    if (code == null) {
      code = switch (statusCode) {
        401 => 'AUTH_REQUIRED',
        403 => 'SUBSCRIPTION_REQUIRED',
        429 => 'RATE_LIMITED',
        _ => null,
      };
      message = switch (statusCode) {
        401 => message == 'Server error' ? 'Authentication required' : message,
        403 => message == 'Server error' ? 'Subscription required to access this template' : message,
        429 => message == 'Server error' ? 'Too many requests. Please try again later' : message,
        _ => message,
      };
    }

    return ServerException(
      message: message,
      statusCode: statusCode,
      code: code,
    );
  }
}
