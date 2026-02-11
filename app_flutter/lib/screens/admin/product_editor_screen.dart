import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/product.dart';
import '../../services/app_translations.dart';
import '../../services/settings_service.dart';
import '../../constants/categories.dart';
import '../../constants/api.dart';
import '../../utils/responsive.dart';

class ProductEditorScreen extends StatefulWidget {
  final Product? product; // Null = Add, Not Null = Edit

  const ProductEditorScreen({super.key, this.product});

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  String? _selectedCategory;
  final _settingsService = SettingsService();

  bool _isLoading = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.price.toString();
      _imageController.text = widget.product!.imageUrl ?? '';
      _imageController.text = widget.product!.imageUrl ?? '';
      _selectedCategory = widget.product!.categoryId;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      // Use image.name instead of image.path for web compatibility
      final fileExt = image.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'products/$fileName';

      // Simple Mime Lookup
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
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final body = jsonEncode({
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

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      };

      final response = widget.product != null
          ? await http.put(
              url,
              headers: headers,
              body: body,
            )
          : await http.post(
              url,
              headers: headers,
              body: body,
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context); // Go back to list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product saved successfully!')),
          );
        }
      } else {
        throw Exception('Failed to save product: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    final isDesktop = !Responsive.isMobile(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? AppTranslations.of(context, 'editProduct')
            : AppTranslations.of(context, 'addProduct')),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          if (isDesktop)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA1D2C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _isLoading ? null : _saveProduct,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.save),
                label: Text(AppTranslations.of(context, 'save')),
              ),
            ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Image Upload (40%)
                    Expanded(
                      flex: 4,
                      child: _buildImageUploadSection(context),
                    ),
                    const SizedBox(width: 32),
                    // Right Column: Form Fields (60%)
                    Expanded(
                      flex: 6,
                      child: _buildFormSection(context),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildImageUploadSection(context),
                    const SizedBox(height: 24),
                    _buildFormSection(context),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: !isDesktop
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA1D2C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _isLoading ? null : _saveProduct,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(AppTranslations.of(context, 'save')),
              ),
            )
          : null,
    );
  }

  Widget _buildImageUploadSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTranslations.of(context, 'productImage'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262626) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _imageController.text.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              _imageController.text,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(LucideIcons.imageOff)),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: IconButton(
                                icon: const Icon(LucideIcons.x,
                                    color: Colors.white),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54),
                                onPressed: () {
                                  setState(() => _imageController.clear());
                                },
                              ),
                            )
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isUploading)
                            const CircularProgressIndicator()
                          else ...[
                            Icon(LucideIcons.uploadCloud,
                                size: 48, color: theme.hintColor),
                            const SizedBox(height: 12),
                            Text(
                              'Click to upload image',
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 16),
                            ),
                            Text(
                              'JPG, PNG or WEBP',
                              style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color,
                                  fontSize: 12),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_imageController.text.isEmpty)
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.cardColor,
                      title: Text('Enter Image URL',
                          style: TextStyle(
                              color: theme.textTheme.titleLarge?.color)),
                      content: TextField(
                        controller: _imageController,
                        style:
                            TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: 'https://...',
                          hintStyle: TextStyle(color: theme.hintColor),
                          enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: theme.dividerColor)),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                },
                icon: const Icon(LucideIcons.link, size: 16),
                label: const Text('Paste URL'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
            context, _nameController, 'productName', LucideIcons.utensils,
            required: true),
        const SizedBox(height: 24),

        // Category Chips
        Text('Category',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              APP_CATEGORIES.entries.where((e) => e.key != 'all').map((entry) {
            final data = entry.value;
            final isSelected = _selectedCategory == data['id'];
            final color = data['color'] as Color? ?? Colors.grey;

            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(data['icon'],
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(width: 8),
                  Text(data['label']),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? (data['id'] as String) : null;
                });
              },
              backgroundColor: theme.cardColor,
              selectedColor: color.withOpacity(0.8),
              labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                    color: isSelected ? color : theme.dividerColor,
                    width: isSelected ? 2 : 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
        if (_selectedCategory == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text('Required',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),

        const SizedBox(height: 24),

        // Price field with currency from SettingsService
        ValueListenableBuilder<String>(
          valueListenable: _settingsService.currencyNotifier,
          builder: (context, currency, _) {
            final symbol = _settingsService.getCurrencySymbol(currency);
            return _buildTextField(
                context, _priceController, 'productPrice', LucideIcons.euro,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                required: true,
                prefixText: '$symbol ');
          },
        ),

        const SizedBox(height: 24),
        _buildTextField(context, _descController, 'productDescription',
            LucideIcons.fileText,
            maxLines: 5),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String labelKey,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? prefixText,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: theme.textTheme.bodyLarge,
      validator: required
          ? (value) => value == null || value.isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: AppTranslations.of(context, labelKey),
        prefixIcon:
            prefixText == null ? Icon(icon, color: theme.hintColor) : null,
        prefix: prefixText != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(prefixText,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16)),
              )
            : null,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
