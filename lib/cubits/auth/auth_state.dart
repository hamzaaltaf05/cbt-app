import 'package:cbt_app/models/user_profile.dart';

sealed class AppAuthState {
  const AppAuthState();
}

class AuthInitial extends AppAuthState {
  const AuthInitial();
}

class AuthLoading extends AppAuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AppAuthState {
  final UserProfile profile;
  const AuthAuthenticated(this.profile);
}

class AuthUnauthenticated extends AppAuthState {
  const AuthUnauthenticated();
}

class AuthError extends AppAuthState {
  final String message;
  const AuthError(this.message);
}
