import 'package:gopost_app/auth/domain/repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository _repository;

  const LogoutUseCase(this._repository);

  Future<void> call(String refreshToken) {
    return _repository.logout(refreshToken);
  }
}
