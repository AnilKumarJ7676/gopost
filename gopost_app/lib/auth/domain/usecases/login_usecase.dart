import 'package:gopost_app/auth/domain/entities/auth_tokens.dart';
import 'package:gopost_app/auth/domain/entities/user_entity.dart';
import 'package:gopost_app/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<(AuthTokens, UserEntity)?> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }
}
