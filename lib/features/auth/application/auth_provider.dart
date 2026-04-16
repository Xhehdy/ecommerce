import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../data/models/user_profile_model.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.currentUser;
});

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  ref.watch(authStateProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.getCurrentUserProfile();
});

final publicProfileProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.getProfileById(userId);
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController {
  final AuthRepository _authRepository;

  AuthController(this._authRepository);

  Future<AuthResponse> signIn(String email, String password) {
    return _authRepository.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) {
    return _authRepository.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }

  Future<void> ensureCurrentUserProfile() {
    return _authRepository.ensureCurrentUserProfile();
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    String? matricNumber,
    String? faculty,
    String? phone,
  }) {
    return _authRepository.updateCurrentUserProfile(
      fullName: fullName,
      matricNumber: matricNumber,
      faculty: faculty,
      phone: phone,
    );
  }
}
