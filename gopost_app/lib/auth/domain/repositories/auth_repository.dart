import 'package:gopost_app/auth/domain/entities/auth_tokens.dart';
import 'package:gopost_app/auth/domain/entities/user_entity.dart';
import 'package:gopost_app/core/error/failures.dart';

abstract class AuthRepository {
  Future<(AuthTokens, UserEntity)?> register({
    required String name,
    required String email,
    required String password,
  });

  Future<(AuthTokens, UserEntity)?> login({
    required String email,
    required String password,
  });

  Future<AuthTokens?> refreshToken(String refreshToken);

  Future<void> logout(String refreshToken);

  Future<(AuthTokens, UserEntity)?> oauthLogin({
    required String provider,
    required String idToken,
  });
}

typedef AuthResult<T> = ({T? data, Failure? failure});
