import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_translations.dart';
import '../../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Driver Info
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'Brasil'); // Default

  bool _isDriver = false;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final role = _isDriver ? 'driver' : 'client';

      // Always collect address/phone for "Complete Registration"
      final String phone = _phoneController.text.trim();
      final Map<String, dynamic> addressData = {
        'street': _streetController.text.trim(),
        'zip_code': _zipController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
      };

      await AuthService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
        role: role,
        phone: phone,
        address: addressData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.of(context, 'signUpSuccess')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.of(context, 'signUpError')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Icon(
                                  _isDriver
                                      ? Icons.local_shipping_outlined
                                      : Icons.person_outline,
                                  size: 60,
                                  color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                AppTranslations.of(context, 'signUp'),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isDriver
                                    ? AppTranslations.of(
                                        context, 'joinFleetMessage')
                                    : AppTranslations.of(
                                        context, 'createAccountMessage'),
                                style: const TextStyle(color: Colors.white60),
                              ),
                              const SizedBox(height: 32),

                              // Basic Info Fields
                              _buildGlassTextField(
                                controller: _nameController,
                                label: AppTranslations.of(context, 'fullName'),
                                icon: Icons.person_rounded,
                              ),
                              const SizedBox(height: 16),
                              _buildGlassTextField(
                                controller: _emailController,
                                label: AppTranslations.of(context, 'email'),
                                icon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _buildGlassTextField(
                                controller: _passwordController,
                                label: AppTranslations.of(context, 'password'),
                                icon: Icons.lock_rounded,
                                isPassword: true,
                              ),
                              const SizedBox(height: 24),

                              // Role Switch (Driver vs Client)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: SwitchListTile(
                                  title: Text(
                                    AppTranslations.of(
                                        context, 'iWantToDeliver'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    AppTranslations.of(
                                        context, 'registerDeliveryPartner'),
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                  secondary: Icon(
                                      Icons.sports_motorsports_rounded,
                                      color: _isDriver
                                          ? Colors.amber
                                          : Colors.white54),
                                  value: _isDriver,
                                  activeColor: Colors.amber,
                                  activeTrackColor:
                                      Colors.amber.withOpacity(0.3),
                                  onChanged: (val) {
                                    setState(() => _isDriver = val);
                                  },
                                ),
                              ),

                              // Delivery Details (Always Visible)
                              Column(
                                children: [
                                  const SizedBox(height: 24),
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppTranslations.of(
                                        context, 'deliveryDetails'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGlassTextField(
                                    controller: _phoneController,
                                    label: AppTranslations.of(
                                        context, 'phoneNumber'),
                                    icon: Icons.phone_rounded,
                                    keyboardType: TextInputType.phone,
                                    required: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildGlassTextField(
                                          controller: _streetController,
                                          label: AppTranslations.of(
                                              context, 'streetAddress'),
                                          icon: Icons.home_rounded,
                                          required: true,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildGlassTextField(
                                          controller: _zipController,
                                          label: AppTranslations.of(
                                              context, 'zipCode'),
                                          icon: Icons.map_rounded,
                                          keyboardType: TextInputType.number,
                                          required: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildGlassTextField(
                                          controller: _cityController,
                                          label: AppTranslations.of(
                                              context, 'city'),
                                          icon: Icons.location_city_rounded,
                                          required: true,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildGlassTextField(
                                          controller: _stateController,
                                          label: AppTranslations.of(
                                              context, 'state'),
                                          icon: Icons.map,
                                          required: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGlassTextField(
                                    controller: _countryController,
                                    label:
                                        AppTranslations.of(context, 'country'),
                                    icon: Icons.flag_rounded,
                                    required: true,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 40),

                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _isDriver ? Colors.amber : Colors.blue,
                                    foregroundColor: Colors.black,
                                    elevation: 5,
                                    shadowColor:
                                        (_isDriver ? Colors.amber : Colors.blue)
                                            .withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  onPressed: _isLoading ? null : _signUp,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black),
                                        )
                                      : Text(
                                          AppTranslations.of(context, 'signUp')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Back to Login
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70),
                                child: RichText(
                                  text: TextSpan(
                                    text: AppTranslations.of(
                                            context, 'alreadyHaveAccount') +
                                        ' ',
                                    style:
                                        const TextStyle(color: Colors.white60),
                                    children: [
                                      TextSpan(
                                        text: AppTranslations.of(
                                            context, 'signInAction'),
                                        style: TextStyle(
                                          color: _isDriver
                                              ? Colors.amber
                                              : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        cursorColor: _isDriver ? Colors.amber : Colors.blue,
        validator: required
            ? (value) {
                if (value == null || value.isEmpty)
                  return AppTranslations.of(context, 'requiredField');
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _isDriver ? Colors.amber : Colors.blue,
              width: 1.5,
            ),
          ),
          errorStyle: const TextStyle(color: Colors.redAccent, height: 0.8),
        ),
      ),
    );
  }
}
