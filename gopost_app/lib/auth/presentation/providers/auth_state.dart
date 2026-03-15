import 'package:equatable/equatable.dart';
import 'package:gopost_app/auth/domain/entities/user_entity.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, guest, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserEntity? user;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Guest users can browse but cannot export or use templates.
  bool get isGuest => status == AuthStatus.guest;

  /// True when the user has access to the main app (authenticated or guest).
  bool get canAccessApp => isAuthenticated || isGuest;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? accessToken,
    String? refreshToken,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, accessToken, refreshToken, errorMessage];
}
