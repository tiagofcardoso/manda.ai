import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'order_service.dart';

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
    String? phone,
    Map<String, dynamic>? address,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
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
    // Clear any active order session to prevent data leakage to other users (e.g. Guest/Admin)
    OrderService().clearOrder();
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
