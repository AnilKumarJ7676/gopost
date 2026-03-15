import 'package:gopost_app/auth/domain/entities/auth_tokens.dart';
import 'package:gopost_app/auth/domain/entities/user_entity.dart';

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  AuthTokens toTokens() => AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
      );

  UserEntity toUserEntity() => user.toEntity();
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        email: email,
        name: name,
        avatarUrl: avatarUrl,
      );
}
