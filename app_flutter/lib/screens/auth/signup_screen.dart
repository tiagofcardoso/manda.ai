import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_translations.dart';
import '../../services/auth_service.dart';
import '../../constants/admin_theme.dart';
import '../../utils/validators.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // NEW

  // Driver Info
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'Brasil'); // Default

  bool _isDriver = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // NEW
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
    return Theme(
      data: AdminTheme.darkTheme,
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.dividerColor),
              ),
              color: theme.cardTheme.color,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Icon(
                        _isDriver ? LucideIcons.truck : LucideIcons.user,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppTranslations.of(context, 'signUp'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isDriver
                            ? AppTranslations.of(context, 'joinFleetMessage')
                            : AppTranslations.of(
                                context, 'createAccountMessage'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // Basic Info Fields
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.of(context, 'fullName'),
                          prefixIcon: const Icon(LucideIcons.user),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.of(context, 'email'),
                          prefixIcon: const Icon(LucideIcons.mail),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v?.contains('@') == true ? null : 'Invalid email',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.of(context, 'password'),
                          prefixIcon: const Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) => Validators.validatePassword(v, context),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText:
                              AppTranslations.of(context, 'confirmPassword'),
                          prefixIcon: const Icon(LucideIcons.checkCircle),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return AppTranslations.of(
                                context, 'passwordsDoNotMatch');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Role Switch
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            AppTranslations.of(context, 'iWantToDeliver'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            AppTranslations.of(
                                context, 'registerDeliveryPartner'),
                            style: theme.textTheme.bodySmall,
                          ),
                          secondary: Icon(
                            LucideIcons.bike,
                            color: _isDriver
                                ? theme.colorScheme.primary
                                : theme.disabledColor,
                          ),
                          value: _isDriver,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) => setState(() => _isDriver = val),
                        ),
                      ),

                      // Delivery Details
                      if (_isDriver) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          AppTranslations.of(context, 'deliveryDetails'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText:
                                AppTranslations.of(context, 'phoneNumber'),
                            prefixIcon: const Icon(LucideIcons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _streetController,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.of(
                                      context, 'streetAddress'),
                                  prefixIcon: const Icon(LucideIcons.home),
                                ),
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _zipController,
                                decoration: InputDecoration(
                                  labelText:
                                      AppTranslations.of(context, 'zipCode'),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: InputDecoration(
                                  labelText:
                                      AppTranslations.of(context, 'city'),
                                ),
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _stateController,
                                decoration: InputDecoration(
                                  labelText:
                                      AppTranslations.of(context, 'state'),
                                ),
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _countryController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.of(context, 'country'),
                            prefixIcon: const Icon(LucideIcons.flag),
                          ),
                          validator: (v) =>
                              v?.isEmpty == true ? 'Required' : null,
                        ),
                      ],

                      const SizedBox(height: 40),

                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(AppTranslations.of(context, 'signUp')
                                  .toUpperCase()),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Back to Login
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppTranslations.of(context, 'haveAccount')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
      }),
    );
  }
}
