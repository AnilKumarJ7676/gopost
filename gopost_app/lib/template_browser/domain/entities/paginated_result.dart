import 'package:equatable/equatable.dart';

class PaginatedResult<T> extends Equatable {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final int totalCount;

  const PaginatedResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [items, nextCursor, hasMore, totalCount];
}
