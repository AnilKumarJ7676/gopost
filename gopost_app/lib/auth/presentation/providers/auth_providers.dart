import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gopost_app/auth/data/repositories/auth_repository_impl.dart';
import 'package:gopost_app/auth/domain/repositories/auth_repository.dart';
import 'package:gopost_app/auth/domain/usecases/login_usecase.dart';
import 'package:gopost_app/auth/domain/usecases/logout_usecase.dart';
import 'package:gopost_app/auth/domain/usecases/register_usecase.dart';
import 'package:gopost_app/auth/presentation/providers/auth_notifier.dart';
import 'package:gopost_app/auth/presentation/providers/auth_state.dart';
import 'package:gopost_app/core/di/providers.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return AuthRemoteDataSourceImpl(httpClient.dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    registerUseCase: ref.watch(registerUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    secureStorage: ref.watch(secureStorageProvider),
    authInterceptor: ref.watch(authInterceptorProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});
