import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.currentUser;
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController {
  final AuthRepository _authRepository;

  AuthController(this._authRepository);

  Future<AuthResponse> signIn(String email, String password) {
    return _authRepository.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) {
    return _authRepository.signUpWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
