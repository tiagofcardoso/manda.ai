import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/app_translations.dart';
import '../../widgets/admin/admin_centered_layout.dart';
import '../../widgets/admin/admin_form_fields.dart';

class EstablishmentEditorScreenModern extends StatefulWidget {
  final Map<String, dynamic>? establishment;

  const EstablishmentEditorScreenModern({super.key, this.establishment});

  @override
  State<EstablishmentEditorScreenModern> createState() =>
      _EstablishmentEditorScreenModernState();
}

class _EstablishmentEditorScreenModernState
    extends State<EstablishmentEditorScreenModern> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _imageController = TextEditingController();

  // Contact & Address Controllers
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();

  final _zipCodeController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();

  String _selectedType = 'restaurant';
  String _selectedCurrency = 'EUR';
  bool _isActive = true;
  bool _isLoading = false;
  bool _isUploading = false;

  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // Business type definitions (labels come from translations)
  final List<Map<String, dynamic>> _types = [
    {'id': 'restaurant', 'key': 'typeRestaurant', 'icon': LucideIcons.utensils},
    {'id': 'pharmacy', 'key': 'typePharmacy', 'icon': LucideIcons.pill},
    {'id': 'grocery', 'key': 'typeGrocery', 'icon': LucideIcons.shoppingBag},
    {'id': 'bakery', 'key': 'typeBakery', 'icon': LucideIcons.croissant},
    {'id': 'butchery', 'key': 'typeButchery', 'icon': LucideIcons.beef},
    {'id': 'pet_shop', 'key': 'typePetShop', 'icon': LucideIcons.dog},
    {
      'id': 'electronics',
      'key': 'typeElectronics',
      'icon': LucideIcons.smartphone
    },
    {'id': 'fashion', 'key': 'typeFashion', 'icon': LucideIcons.shirt},
    {'id': 'beverages', 'key': 'typeBeverages', 'icon': LucideIcons.wine},
    {'id': 'home_decor', 'key': 'typeHomeDecor', 'icon': LucideIcons.armchair},
    {'id': 'stationery', 'key': 'typeStationery', 'icon': LucideIcons.pencil},
    {'id': 'beauty', 'key': 'typeBeauty', 'icon': LucideIcons.sparkles},
    {'id': 'florist', 'key': 'typeFlorist', 'icon': LucideIcons.flower},
    {'id': 'services', 'key': 'typeServices', 'icon': LucideIcons.briefcase},
    {'id': 'shop', 'key': 'typeOther', 'icon': LucideIcons.store},
  ];

  final List<Map<String, String>> _currencies = [
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'BRL', 'symbol': 'R\$'},
    {'code': 'AOA', 'symbol': 'Kz'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.establishment != null) {
      _nameController.text = widget.establishment!['name'];
      _slugController.text = widget.establishment!['slug'];
      _selectedType = widget.establishment!['type'] ?? 'restaurant';
      _isActive = widget.establishment!['is_active'] ?? true;
      _selectedCurrency = widget.establishment!['currency'] ?? 'EUR';
      _imageController.text = widget.establishment!['logo_url'] ?? '';

      _contactNameController.text = widget.establishment!['contact_name'] ?? '';
      _contactPhoneController.text =
          widget.establishment!['contact_phone'] ?? '';
      _zipCodeController.text = widget.establishment!['zip_code'] ?? '';
      _streetController.text = widget.establishment!['street'] ?? '';
      _numberController.text = widget.establishment!['number'] ?? '';
      _complementController.text = widget.establishment!['complement'] ?? '';
      _cityController.text = widget.establishment!['city'] ?? '';
      _stateController.text = widget.establishment!['state'] ?? '';
      _countryController.text = widget.establishment!['country'] ?? '';

      _loadAdminData(widget.establishment!['id']);
    }
  }

  Future<void> _loadAdminData(String establishmentId) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/admin/establishment-admin/$establishmentId'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['email'] != null && mounted) {
          setState(() {
            _adminEmailController.text = data['email'];
            // If contact info is missing, fill it from admin profile if available
            if (_contactNameController.text.isEmpty &&
                data['full_name'] != null) {
              _contactNameController.text = data['full_name'];
            }
            if (_contactPhoneController.text.isEmpty &&
                data['phone_number'] != null) {
              _contactPhoneController.text = data['phone_number'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _imageController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _adminEmailController.dispose();
    _zipCodeController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // Helper to shorten translation calls
  String _t(String key) => AppTranslations.of(context, key);

  void _onNameChanged(String value) {
    if (widget.establishment == null) {
      setState(() {
        _slugController.text = value
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'[^\w\-]'), '');
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'logos/$fileName';

      String contentType;
      switch (fileExt) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        default:
          contentType = 'application/octet-stream';
      }

      await _supabase.storage.from('establishments').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: contentType,
            ),
          );

      final imageUrl =
          _supabase.storage.from('establishments').getPublicUrl(filePath);

      setState(() {
        _imageController.text = imageUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('logoUploaded')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        String errorMsg = '${_t('uploadError')} $e';
        if (e.toString().contains('Bucket not found')) {
          errorMsg = _t('bucketNotFound');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignAdmin(String establishmentId) async {
    final email = _adminEmailController.text.trim();
    if (email.isEmpty) return;

    try {
      // Get current user token for authorization
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      // Call backend endpoint to create/assign admin
      final response = await http.post(
        Uri.parse('http://localhost:8000/admin/create-establishment-admin'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'establishment_id': establishmentId,
          'full_name': _contactNameController.text.trim(),
          'phone_number': _contactPhoneController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Admin Created/Assigned: ${data}');

        // Show credentials if new user was created
        if (data['temp_password'] != null && mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_t('adminCreated')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('adminCredentials')),
                  const SizedBox(height: 16),
                  SelectableText(
                    'Email: ${data['email']}\nSenha: ${data['temp_password']}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('adminPasswordChangeNote'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t('ok')),
                ),
              ],
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('adminAssignedSuccess')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error assigning admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('adminAssignError')} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveEstablishment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_slugController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('slugRequired'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'slug': _slugController.text.trim(),
        'type': _selectedType,
        'currency': _selectedCurrency,
        'is_active': _isActive,
        'logo_url': _imageController.text.trim(),
        'contact_name': _contactNameController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim(),
        'zip_code': _zipCodeController.text.trim(),
        'street': _streetController.text.trim(),
        'number': _numberController.text.trim(),
        'complement': _complementController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
      };

      String establishmentId;
      if (widget.establishment != null) {
        establishmentId = widget.establishment!['id'];
        await _supabase
            .from('establishments')
            .update(data)
            .eq('id', establishmentId);
      } else {
        final res =
            await _supabase.from('establishments').insert(data).select();
        establishmentId = res[0]['id'];
      }

      // Assign Admin if email provided
      if (_adminEmailController.text.isNotEmpty) {
        await _assignAdmin(establishmentId);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_t('storeSaved')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_t('saveError')} $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFEA1D2C);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: AdminCenteredLayout(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFFF9FAFB).withOpacity(0.8),
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.black87,
                  ),
                  title: Text(
                    widget.establishment != null
                        ? _t('editStore')
                        : _t('newStore'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminImageUpload(
                            controller: _imageController,
                            isUploading: _isUploading,
                            onTap: _pickAndUploadImage,
                            onPasteUrl: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final urlController = TextEditingController();
                                  return AlertDialog(
                                    title: Text(_t('pasteImageUrl')),
                                    content: TextField(
                                      controller: urlController,
                                      decoration: const InputDecoration(
                                        hintText: 'https://...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(_t('cancel')),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _imageController.text =
                                                urlController.text;
                                          });
                                          Navigator.pop(context);
                                        },
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          AdminSectionLabel(_t('basicInfo')),
                          AdminBottomLineTextField(
                            controller: _nameController,
                            icon: LucideIcons.store,
                            placeholder: _t('storeName'),
                            onChanged: _onNameChanged,
                            validator: (v) =>
                                v?.isEmpty ?? true ? _t('fieldRequired') : null,
                          ),
                          const SizedBox(height: 24),
                          AdminBottomLineTextField(
                            controller: _slugController,
                            icon: LucideIcons.link,
                            placeholder: _t('urlSlug'),
                            validator: (v) =>
                                v?.isEmpty ?? true ? _t('fieldRequired') : null,
                          ),
                          const SizedBox(height: 32),
                          AdminSectionLabel(_t('contactAdmin')),
                          AdminBottomLineTextField(
                            controller: _contactNameController,
                            icon: LucideIcons.user,
                            placeholder: _t('contactName'),
                          ),
                          const SizedBox(height: 16),
                          AdminBottomLineTextField(
                            controller: _contactPhoneController,
                            icon: LucideIcons.phone,
                            placeholder: _t('phoneWhatsApp'),
                          ),
                          const SizedBox(height: 16),
                          AdminBottomLineTextField(
                            controller: _adminEmailController,
                            icon: LucideIcons.mail,
                            placeholder: _t('adminEmail'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 36, top: 4),
                            child: Text(
                              _t('adminEmailHint'),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 32),
                          AdminSectionLabel(_t('address')),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: AdminBottomLineTextField(
                                  controller: _zipCodeController,
                                  icon: LucideIcons.mapPin,
                                  placeholder: _t('zipCodeLabel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: AdminBottomLineTextField(
                                  controller: _cityController,
                                  icon: LucideIcons.building,
                                  placeholder: _t('cityLabel'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AdminBottomLineTextField(
                            controller: _streetController,
                            icon: LucideIcons.map,
                            placeholder: _t('streetLabel'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: AdminBottomLineTextField(
                                  controller: _numberController,
                                  icon: LucideIcons.home,
                                  placeholder: _t('numberLabel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: AdminBottomLineTextField(
                                  controller: _complementController,
                                  icon: LucideIcons.info,
                                  placeholder: _t('complementLabel'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AdminBottomLineTextField(
                            controller: _stateController,
                            icon: LucideIcons.flag,
                            placeholder: _t('stateLabel'),
                          ),
                          const SizedBox(height: 16),
                          AdminBottomLineTextField(
                            controller: _countryController,
                            icon: LucideIcons.globe,
                            placeholder: _t('country'),
                          ),
                          const SizedBox(height: 32),
                          AdminSectionLabel(_t('businessType')),
                          _buildTypeSelector(primaryColor),
                          const SizedBox(height: 32),
                          AdminSectionLabel(_t('configSection')),
                          _buildCurrencySelector(primaryColor),
                          const SizedBox(height: 24),
                          AdminSectionLabel(_t('statusSection')),
                          AdminFeatureToggle(
                            icon: LucideIcons.power,
                            iconColor: _isActive ? Colors.green : Colors.grey,
                            title: _t('storeActive'),
                            subtitle: _t('storeActiveDesc'),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 32,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: _isLoading ? null : _saveEstablishment,
                backgroundColor: primaryColor,
                elevation: 8,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 24),
                label: Text(
                  _isLoading ? _t('saving') : _t('saveStore'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(Color primaryColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types.map((type) {
        final isSelected = _selectedType == type['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type['id']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type['icon'],
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _t(type['key']),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurrencySelector(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('mainCurrency'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _currencies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              final isSelected = _selectedCurrency == currency['code'];
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCurrency = currency['code']!),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black87 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.black87 : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        currency['symbol']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currency['code']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
