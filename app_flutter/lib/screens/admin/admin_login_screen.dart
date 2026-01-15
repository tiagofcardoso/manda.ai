import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_translations.dart';
import 'admin_dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../auth/signup_screen.dart';
import '../driver/driver_home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() => _isCheckingSession = false);
      return;
    }

    // Has session, check role to see if we should auto-redirect
    final role = await AuthService().getUserRole();
    if (!mounted) return;

    if (role == 'driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
      );
    } else if (role != 'client') {
      // Admin, Manager, etc.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else {
      // Client - stay here and show "Logout" UI
      setState(() => _isCheckingSession = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Auth state change will trigger re-build logic if we listened to it,
      // but here we manually check role again or let the user decide.
      // Better to check role and move.
      if (mounted) {
        await _checkSession();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppTranslations.of(context, 'loginFailed')} ${e.message}'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppTranslations.of(context, 'generalError')} $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
    // We don't finally false here because _checkSession might take over
  }

  @override
  Widget build(BuildContext context) {
    // Logic moved to initState or handled via UI based on state
    // We avoid auto-popping for clients to prevent "flash" effect

    return Scaffold(
      appBar: AppBar(
          title: Text(AppTranslations.of(context, 'adminLogin')),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white),
      backgroundColor: const Color(0xFF1a1a1a),
      body: _isCheckingSession
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _supabase.auth.currentSession != null
              ? Center(
                  child: Card(
                    color: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.userCheck,
                              size: 64, color: Colors.green),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.of(context, 'alreadyLoggedIn'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _supabase.auth.currentUser?.email ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white),
                              onPressed: () async {
                                await _supabase.auth.signOut();
                                setState(() {}); // Refresh to show Login form
                              },
                              child:
                                  Text(AppTranslations.of(context, 'logout')),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                                AppTranslations.of(context, 'backToMenu'),
                                style: const TextStyle(color: Colors.white54)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Card(
                      color: Colors.grey[900],
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                LucideIcons
                                    .userCircle, // Changed from shieldAlert
                                size: 64,
                                color: Colors.white),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: AppTranslations.of(context, 'email'),
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                enabledBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white30)),
                                focusedBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                prefixIcon: const Icon(LucideIcons.mail,
                                    color: Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText:
                                    AppTranslations.of(context, 'password'),
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                enabledBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white30)),
                                focusedBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                prefixIcon: const Icon(LucideIcons.lock,
                                    color: Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(16)),
                                onPressed: _isLoading ? null : _signIn,
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : Text(AppTranslations.of(
                                        context, 'loginToAdmin')),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SignUpScreen()),
                                );
                              },
                              child: Text(
                                AppTranslations.of(context, 'signUp'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
