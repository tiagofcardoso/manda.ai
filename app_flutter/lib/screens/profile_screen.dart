import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/app_translations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  // Personal Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); // Read-only

  // Address (Delivery)
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'Brasil');

  // Billing
  bool _sameAsDelivery = true;
  final _vatNumberController = TextEditingController(); // CPF/CNPJ/NIF
  final _vatNameController = TextEditingController();
  final _vatAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _vatNumberController.dispose();
    _vatNameController.dispose();
    _vatAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _emailController.text = user.email ?? '';

      final data =
          await _supabase.from('profiles').select().eq('id', user.id).single();

      if (mounted) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';

          // Address
          final address = data['address'] as Map<String, dynamic>? ?? {};
          _streetController.text = address['street'] ?? '';
          _numberController.text = address['number'] ?? '';
          _complementController.text = address['complement'] ?? '';
          _zipController.text = address['zip_code'] ?? '';
          _cityController.text = address['city'] ?? '';
          _stateController.text = address['state'] ?? '';
          _countryController.text = address['country'] ?? 'Brasil';

          // Billing (Stored inside address['billing'] or separate column if exists)
          // Using address['billing'] to avoid schema changes for now.
          final billing = address['billing'] as Map<String, dynamic>?;

          if (billing != null) {
            _sameAsDelivery = false;
            _vatNumberController.text = billing['vat_number'] ?? '';
            _vatNameController.text = billing['name'] ?? '';
            _vatAddressController.text = billing['address'] ?? '';
          } else {
            _sameAsDelivery = true;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> addressData = {
        'street': _streetController.text.trim(),
        'number': _numberController.text.trim(),
        'complement': _complementController.text.trim(),
        'zip_code': _zipController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
      };

      if (!_sameAsDelivery) {
        addressData['billing'] = {
          'vat_number': _vatNumberController.text.trim(),
          'name': _vatNameController.text.trim(),
          'address': _vatAddressController.text.trim(),
        };
      } else {
        // If same as delivery, we can either clear it or store a flag.
        // Clearing it implies "use delivery address".
        addressData.remove('billing');
      }

      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'address': addressData,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.of(context, 'profileSaved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE63946),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.of(context, 'myProfile')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Info
            _buildSectionTitle(AppTranslations.of(context, 'personalInfo')),
            _buildTextField(
              controller: _nameController,
              label: AppTranslations.of(context, 'fullName'),
              icon: LucideIcons.user,
            ),
            _buildTextField(
              controller: _emailController,
              label: AppTranslations.of(context, 'email'),
              icon: LucideIcons.mail,
              readOnly: true,
            ),
            _buildTextField(
              controller: _phoneController,
              label: AppTranslations.of(context, 'phoneNumber'),
              icon: LucideIcons.phone,
            ),

            const Divider(height: 32),

            // Delivery Address
            _buildSectionTitle(AppTranslations.of(context, 'deliveryDetails')),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _zipController,
                    label: AppTranslations.of(context, 'zipCode'),
                    icon: LucideIcons.mapPin,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _cityController,
                    label: AppTranslations.of(context, 'city'),
                  ),
                ),
              ],
            ),
            _buildTextField(
              controller: _streetController,
              label: AppTranslations.of(context, 'streetLabel'),
              icon: LucideIcons.home,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _numberController,
                    label: AppTranslations.of(context, 'numberLabel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _complementController,
                    label: AppTranslations.of(context, 'complementLabel'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: AppTranslations.of(context, 'stateLabel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _countryController,
                    label: AppTranslations.of(context, 'country'),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // Billing Info
            _buildSectionTitle(AppTranslations.of(context, 'billingAddress')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppTranslations.of(context, 'sameAsDelivery')),
              value: _sameAsDelivery,
              onChanged: (val) {
                setState(() => _sameAsDelivery = val);
              },
              activeColor: const Color(0xFFE63946),
            ),

            if (!_sameAsDelivery) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _vatNumberController,
                label: AppTranslations.of(context, 'vatNumber'), // 'NIF / CPF'
                icon: LucideIcons.fileText,
              ),
              _buildTextField(
                controller: _vatNameController,
                label:
                    AppTranslations.of(context, 'vatName'), // 'Nome na Fatura'
                icon: LucideIcons.userCheck,
              ),
              _buildTextField(
                controller: _vatAddressController,
                label: AppTranslations.of(
                    context, 'vatAddress'), // 'Endereço Fiscal'
                icon: LucideIcons.map,
              ),
            ],

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppTranslations.of(context, 'saveProfile'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
