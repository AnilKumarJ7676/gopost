import 'package:equatable/equatable.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';

enum TemplateSortBy { popular, newest, trending }

class TemplateFilter extends Equatable {
  final String? query;
  final TemplateType? type;
  final String? categoryId;
  final bool? isPremium;
  final TemplateSortBy sortBy;
  final int limit;
  final String? cursor;

  const TemplateFilter({
    this.query,
    this.type,
    this.categoryId,
    this.isPremium,
    this.sortBy = TemplateSortBy.popular,
    this.limit = 20,
    this.cursor,
  });

  TemplateFilter copyWith({
    String? query,
    TemplateType? type,
    String? categoryId,
    bool? isPremium,
    TemplateSortBy? sortBy,
    int? limit,
    String? cursor,
    bool clearQuery = false,
    bool clearType = false,
    bool clearCategory = false,
    bool clearPremium = false,
    bool clearCursor = false,
  }) {
    return TemplateFilter(
      query: clearQuery ? null : (query ?? this.query),
      type: clearType ? null : (type ?? this.type),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isPremium: clearPremium ? null : (isPremium ?? this.isPremium),
      sortBy: sortBy ?? this.sortBy,
      limit: limit ?? this.limit,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
    );
  }

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'limit': limit.toString(),
      'sort': sortBy.name,
    };
    if (query != null && query!.isNotEmpty) params['q'] = query;
    if (type != null) params['type'] = type!.name;
    if (categoryId != null) params['category_id'] = categoryId;
    if (isPremium != null) params['is_premium'] = isPremium.toString();
    if (cursor != null) params['cursor'] = cursor;
    return params;
  }

  @override
  List<Object?> get props =>
      [query, type, categoryId, isPremium, sortBy, limit, cursor];
}
