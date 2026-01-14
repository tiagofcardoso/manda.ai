import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign Up with Email, Password, and basic metadata (Name, Role)
  /// Role should be 'client' or 'driver'.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'client',
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );
  }

  /// Sign In
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Get Current User Role from Public Profile
  Future<String?> getUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      return data['role'] as String?;
    } catch (e) {
      debugPrint('Error fetching role: $e');
      return null;
    }
  }
}
