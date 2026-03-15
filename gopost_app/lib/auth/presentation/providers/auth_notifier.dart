import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/auth/domain/repositories/auth_repository.dart';
import 'package:gopost_app/auth/domain/usecases/login_usecase.dart';
import 'package:gopost_app/auth/domain/usecases/logout_usecase.dart';
import 'package:gopost_app/auth/domain/usecases/register_usecase.dart';
import 'package:gopost_app/auth/presentation/providers/auth_state.dart';
import 'package:gopost_app/core/constants/api_constants.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/core/logging/app_logger.dart';
import 'package:gopost_app/core/network/interceptors/auth_interceptor.dart';
import 'package:gopost_app/core/security/secure_storage_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final SecureStorageService _secureStorage;
  final AuthInterceptor _authInterceptor;
  final AuthRepository _authRepository;

  AuthNotifier({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required SecureStorageService secureStorage,
    required AuthInterceptor authInterceptor,
    required AuthRepository authRepository,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _secureStorage = secureStorage,
        _authInterceptor = authInterceptor,
        _authRepository = authRepository,
        super(const AuthState()) {
    _authInterceptor.onSessionExpired = _handleSessionExpired;
    _init();
  }

  Future<void> _init() async {
    await tryAutoLogin();
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _loginUseCase(email: email, password: password);
      if (result != null) {
        final (tokens, user) = result;
        _authInterceptor.setToken(tokens.accessToken);
        await _secureStorage.write(
          key: ApiConstants.refreshTokenKey,
          value: tokens.refreshToken,
        );
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
      }
    } on Failure catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _registerUseCase(
        name: name,
        email: email,
        password: password,
      );
      if (result != null) {
        final (tokens, user) = result;
        _authInterceptor.setToken(tokens.accessToken);
        await _secureStorage.write(
          key: ApiConstants.refreshTokenKey,
          value: tokens.refreshToken,
        );
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
      }
    } on Failure catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<void> logout() async {
    if (state.refreshToken != null) {
      try {
        await _logoutUseCase(state.refreshToken!);
      } catch (_) {}
    }
    _authInterceptor.clearToken();
    await _secureStorage.delete(key: ApiConstants.refreshTokenKey);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void skipAuth() {
    state = const AuthState(status: AuthStatus.guest);
  }

  /// Attempts to restore the previous session by exchanging the stored
  /// refresh token for a new access token. Called automatically on startup.
  Future<void> tryAutoLogin() async {
    final refreshToken =
        await _secureStorage.read(key: ApiConstants.refreshTokenKey);
    if (refreshToken == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    state = state.copyWith(status: AuthStatus.loading);
    try {
      final tokens = await _authRepository.refreshToken(refreshToken);
      if (tokens != null) {
        _authInterceptor.setToken(tokens.accessToken);
        await _secureStorage.write(
          key: ApiConstants.refreshTokenKey,
          value: tokens.refreshToken,
        );
        state = AuthState(
          status: AuthStatus.authenticated,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        AppLogger.info('Auto-login successful');
      } else {
        await _clearSession();
      }
    } catch (e) {
      AppLogger.warning('Auto-login failed: $e');
      await _clearSession();
    }
  }

  void _handleSessionExpired() {
    AppLogger.info('Session expired – forcing logout');
    _authInterceptor.clearToken();
    _secureStorage.delete(key: ApiConstants.refreshTokenKey);
    if (mounted) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _clearSession() async {
    _authInterceptor.clearToken();
    await _secureStorage.delete(key: ApiConstants.refreshTokenKey);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
