import 'package:gopost_app/auth/domain/entities/auth_tokens.dart';
import 'package:gopost_app/auth/domain/entities/user_entity.dart';
import 'package:gopost_app/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  Future<(AuthTokens, UserEntity)?> call({
    required String name,
    required String email,
    required String password,
  }) {
    return _repository.register(name: name, email: email, password: password);
  }
}
