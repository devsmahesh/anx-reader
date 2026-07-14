import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/auth/auth_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._api) : super(const AsyncValue.data(null));

  final AuthApi _api;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final tokens = await _api.login(email: email, password: password);
      final userId = AuthApi.userIdFromAccessToken(tokens.accessToken);
      Prefs().saveAuthTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        email: email.trim(),
        userId: userId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _api.logout();
    } finally {
      Prefs().clearAuth();
      state = const AsyncValue.data(null);
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authApiProvider));
});
