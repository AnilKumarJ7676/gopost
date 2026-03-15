import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String role;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.role = 'user',
  });

  @override
  List<Object?> get props => [id, email, name, avatarUrl, role];
}
