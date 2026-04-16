import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import 'models/user_profile_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user ?? currentUser;
    if (user != null) {
      await ensureProfileExists(user);
    }

    return response;
  }

  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user ?? currentUser;
    if (user != null) {
      await ensureProfileExists(user);
    }

    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> ensureCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    await ensureProfileExists(user);
  }

  Future<void> ensureProfileExists(User user) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('Authenticated user must have an email address.');
    }

    await _supabase.from('profiles').upsert({
      'id': user.id,
      'email': email,
    }, onConflict: 'id');
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) {
      return null;
    }

    await ensureProfileExists(user);

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromJson(response);
  }

  Future<UserProfile?> getProfileById(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromJson(response);
  }

  Future<UserProfile> updateCurrentUserProfile({
    required String fullName,
    String? matricNumber,
    String? faculty,
    String? phone,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User not authenticated.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('Authenticated user must have an email address.');
    }

    final response = await _supabase
        .from('profiles')
        .upsert({
          'id': user.id,
          'email': email,
          'full_name': fullName,
          'matric_number': matricNumber != null && matricNumber.isNotEmpty
              ? matricNumber
              : null,
          'faculty': faculty != null && faculty.isNotEmpty ? faculty : null,
          'phone': phone != null && phone.isNotEmpty ? phone : null,
        }, onConflict: 'id')
        .select()
        .single();

    return UserProfile.fromJson(response);
  }
}
