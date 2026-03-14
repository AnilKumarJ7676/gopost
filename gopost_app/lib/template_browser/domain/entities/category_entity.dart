import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, slug];
}
