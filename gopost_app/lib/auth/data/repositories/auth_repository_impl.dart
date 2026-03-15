import 'package:gopost_app/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gopost_app/auth/domain/entities/auth_tokens.dart';
import 'package:gopost_app/auth/domain/entities/user_entity.dart';
import 'package:gopost_app/auth/domain/repositories/auth_repository.dart';
import 'package:gopost_app/core/error/exceptions.dart';
import 'package:gopost_app/core/error/failures.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  const AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<(AuthTokens, UserEntity)?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remoteDataSource.register(
        name: name,
        email: email,
        password: password,
      );
      return (result.toTokens(), result.toUserEntity());
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
        statusCode: e.statusCode,
      );
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<(AuthTokens, UserEntity)?> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      return (result.toTokens(), result.toUserEntity());
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
        statusCode: e.statusCode,
      );
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<AuthTokens?> refreshToken(String refreshToken) async {
    try {
      final result = await _remoteDataSource.refreshToken(refreshToken);
      return result.toTokens();
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
        statusCode: e.statusCode,
      );
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _remoteDataSource.logout(refreshToken);
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
        statusCode: e.statusCode,
      );
    } on NetworkException {
      throw const NetworkFailure();
    }
  }

  @override
  Future<(AuthTokens, UserEntity)?> oauthLogin({
    required String provider,
    required String idToken,
  }) async {
    try {
      final result = await _remoteDataSource.oauthLogin(
        provider: provider,
        idToken: idToken,
      );
      return (result.toTokens(), result.toUserEntity());
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
        statusCode: e.statusCode,
      );
    } on NetworkException {
      throw const NetworkFailure();
    }
  }
}
