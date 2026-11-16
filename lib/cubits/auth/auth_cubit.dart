import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:cbt_app/models/user_profile.dart';
import 'package:cbt_app/cubits/auth/auth_state.dart';

class AuthCubit extends Cubit<AppAuthState> {
  final supabase.SupabaseClient _client;
  StreamSubscription<supabase.AuthState>? _sub;

  AuthCubit(this._client) : super(const AuthInitial()) {
    _init();
  }

  void _init() {
    _sub = _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        loadProfile(session.user);
      } else {
        emit(const AuthUnauthenticated());
      }
    });

    final currentUser = _client.auth.currentUser;
    if (currentUser != null) {
      loadProfile(currentUser);
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> loadProfile(supabase.User user) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final profile = UserProfile.fromSession(
        user: user,
        profile: row ?? {},
      );

      emit(AuthAuthenticated(profile));
    } catch (e) {
      // Fallback profile if network drops
      final fallback = UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.email?.split('@').first ?? 'User',
        role: UserRole.simpleUser,
      );
      emit(AuthAuthenticated(fallback));
    }
  }

  Future<void> refreshProfile() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      await loadProfile(user);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    emit(const AuthUnauthenticated());
  }

  UserProfile? get profile =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).profile : null;

  UserRole get role => profile?.role ?? UserRole.simpleUser;

  bool get isAdmin => role == UserRole.admin;
  bool get isShopManager => role == UserRole.shopManager;
  bool get isOfficeAdmin => role == UserRole.officeAdmin;

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
