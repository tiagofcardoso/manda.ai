import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../services/settings_service.dart';
import '../../constants/categories.dart';
import '../../constants/api.dart';
import '../../services/app_translations.dart';
import '../../widgets/admin/admin_centered_layout.dart';
import '../../widgets/admin/admin_form_fields.dart';

class ProductEditorScreenModern extends StatefulWidget {
  final Product? product;

  const ProductEditorScreenModern({super.key, this.product});

  @override
  State<ProductEditorScreenModern> createState() =>
      _ProductEditorScreenModernState();
}

class _ProductEditorScreenModernState extends State<ProductEditorScreenModern> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  String? _selectedCategory;
  final _settingsService = SettingsService();

  bool _isLoading = false;
  bool _isUploading = false;
  bool _stockControl = false;
  bool _isPromotion = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.price.toString();
      _imageController.text = widget.product!.imageUrl ?? '';
      _selectedCategory = widget.product!.categoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // Translation helper method
  String _t(String key) => AppTranslations.of(context, key);

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'products/$fileName';

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

      await Supabase.instance.client.storage.from('products').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: contentType,
            ),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('products')
          .getPublicUrl(filePath);

      setState(() {
        _imageController.text = imageUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma categoria'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Não autenticado');

      final payload = jsonEncode({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'image_url': _imageController.text.trim(),
        'category_id': _selectedCategory,
        'is_available': true,
      });

      final url = widget.product != null
          ? Uri.parse(
              '${ApiConstants.baseUrl}/admin/products/${widget.product!.id}')
          : Uri.parse('${ApiConstants.baseUrl}/admin/products');

      final response = widget.product != null
          ? await http.put(url,
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
                'Content-Type': 'application/json',
              },
              body: payload)
          : await http.post(url,
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
                'Content-Type': 'application/json',
              },
              body: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Erro: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descController.clear();
    _priceController.clear();
    _imageController.clear();
    setState(() {
      _selectedCategory = null;
      _stockControl = false;
      _isPromotion = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: AdminCenteredLayout(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Sticky Header
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
                    widget.product != null
                        ? _t('editProduct')
                        : _t('addProduct'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: _clearForm,
                      child: Text(
                        _t('clear'),
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Upload Section
                          _buildImageUploadSection(primaryColor),
                          const SizedBox(height: 32),

                          // Product Name
                          AdminSectionLabel(_t('productNameLabel')),
                          AdminBottomLineTextField(
                            controller: _nameController,
                            icon: Icons.restaurant_rounded,
                            placeholder: _t('productNamePlaceholder'),
                            validator: (v) =>
                                v?.isEmpty ?? true ? _t('fieldRequired') : null,
                          ),
                          const SizedBox(height: 32),

                          // Category
                          _buildCategorySection(primaryColor),
                          const SizedBox(height: 32),

                          // Price
                          _buildPriceSection(primaryColor),
                          const SizedBox(height: 32),

                          // Description
                          AdminSectionLabel(_t('productDescLabel')),
                          AdminBottomLineTextField(
                            controller: _descController,
                            icon: Icons.notes_rounded,
                            placeholder: _t('descriptionPlaceholder'),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 32),

                          // Feature Toggles
                          AdminFeatureToggle(
                            icon: Icons.inventory_2_rounded,
                            iconColor: Colors.blue,
                            title: _t('inventoryControl'),
                            subtitle: _t('manageQuantity'),
                            value: _stockControl,
                            onChanged: (v) => setState(() => _stockControl = v),
                          ),
                          const SizedBox(height: 12),
                          AdminFeatureToggle(
                            icon: Icons.local_offer_rounded,
                            iconColor: Colors.orange,
                            title: _t('onSale'),
                            subtitle: _t('activateDiscount'),
                            value: _isPromotion,
                            onChanged: (v) => setState(() => _isPromotion = v),
                          ),

                          const SizedBox(height: 100), // Space for FAB
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Floating Action Button
            Positioned(
              bottom: 32,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: _isLoading ? null : _saveProduct,
                backgroundColor: primaryColor,
                elevation: 8,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 24),
                label: Text(
                  _isLoading ? _t('saving') : _t('saveProduct'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickAndUploadImage,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
              image: _imageController.text.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_imageController.text),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _imageController.text.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploading)
                        const CircularProgressIndicator()
                      else ...[
                        Icon(
                          Icons.cloud_upload_rounded,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Clique para enviar imagem',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPG, PNG ou WEBP',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            // Show dialog to paste URL
            showDialog(
              context: context,
              builder: (context) {
                final urlController = TextEditingController();
                return AlertDialog(
                  title: const Text('Colar URL da Imagem'),
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
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _imageController.text = urlController.text;
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
          icon: Icon(Icons.link_rounded, size: 18, color: primaryColor),
          label: Text(
            'Colar URL da imagem',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AdminSectionLabel(_t('productCategory')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _t('productRequired'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              APP_CATEGORIES.entries.where((e) => e.key != 'all').map((entry) {
            final categoryData = entry.value;
            final isSelected = _selectedCategory == categoryData['id'];

            return GestureDetector(
              onTap: () => setState(
                  () => _selectedCategory = categoryData['id'] as String?),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey[300]!,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryData['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      categoryData['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionLabel('PREÇO'),
        ValueListenableBuilder<String>(
          valueListenable: _settingsService.currencyNotifier,
          builder: (context, currency, _) {
            final symbol = _settingsService.getCurrencySymbol(currency);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v?.isEmpty ?? true ? 'Obrigatório' : null,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '0,00',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more_rounded,
                          size: 14, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          color: Colors.grey[200],
        ),
      ],
    );
  }
}
