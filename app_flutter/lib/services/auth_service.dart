import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'order_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalAuthentication _localAuth = LocalAuthentication();

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign Up with Email, Password, and basic metadata (Name, Role)
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

  /// Sign In with Google
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      // 1. Web Flow
      if (kIsWeb) {
        await _supabase.auth.signInWithOAuth(OAuthProvider.google);
        return null;
      }

      // 2. Mobile Flow (Android/iOS)
      // Requires setup in Google Cloud Console & Firebase (SHA-1 fingerprint)
      final GoogleSignIn googleSignIn = GoogleSignIn(
          // serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', // Optional for ID Token
          );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign In aborted by user');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw Exception('No Access Token found.');
      }
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  /// Biometric Authentication
  /// Returns true if authenticated successfully
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        debugPrint('Biometrics not available on this device.');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access Manda.AI',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly:
              true, // Force biometrics (no PIN fallback if preferred)
        ),
      );
    } catch (e) {
      debugPrint('Biometric Error: $e');
      return false;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    OrderService().clearOrder();
    await _supabase.auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignore if google sign in wasn't used
    }
  }

  /// Get Current User Role from Public Profile
  Future<String?> getUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      // Call SECURITY DEFINER function (bypasses RLS)
      final result = await _supabase.rpc('get_my_role');
      return result as String?;
    } catch (e) {
      debugPrint('Error fetching role: $e');
      return null;
    }
  }
}
