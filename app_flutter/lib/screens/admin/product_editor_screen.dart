import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../services/app_translations.dart';
import '../../constants/categories.dart';
import '../../constants/api.dart';

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
      _selectedCategory = widget.product!.categoryId;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last.toLowerCase();
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

      final response = widget.product != null
          ? await http.put(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
          : await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? AppTranslations.of(context, 'editProduct')
            : AppTranslations.of(context, 'addProduct')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF1a1a1a),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                  context, _nameController, 'productName', Icons.fastfood,
                  required: true),
              const SizedBox(height: 16),
              _buildTextField(context, _descController, 'productDescription',
                  Icons.description,
                  maxLines: 3),
              const SizedBox(height: 16),
              _buildTextField(
                  context, _priceController, 'productPrice', Icons.attach_money,
                  keyboardType: TextInputType.number, required: true),
              const SizedBox(height: 16),

              // Image Picker Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.of(context, 'productImage'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    if (_imageController.text.isNotEmpty)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageController.text,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 150,
                                child: Center(
                                    child: Icon(Icons.broken_image,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(blurRadius: 2, color: Colors.black)
                                  ]),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54),
                              onPressed: () =>
                                  setState(() => _imageController.clear()),
                            ),
                          )
                        ],
                      ),

                    const SizedBox(height: 12),

                    _isUploading
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Upload Image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _pickAndUploadImage,
                            ),
                          ),

                    // Fallback manual entry
                    if (_imageController.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextFormField(
                          controller: _imageController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Or paste image URL...',
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildCategoryDropdown(context),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _isLoading ? null : _saveProduct,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(AppTranslations.of(context, 'save')),
                ),
              ),
            ],
          ),
        ),
      ),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (value) => value == null || value.isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: AppTranslations.of(context, labelKey),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white54),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white30)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      dropdownColor: const Color(0xFF2d2d2d),
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Category',
        labelStyle: TextStyle(color: Colors.white70),
        prefixIcon: Icon(Icons.category, color: Colors.white54),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        contentPadding: EdgeInsets.all(16),
      ),
      items: APP_CATEGORIES.entries.where((e) => e.key != 'all').map((entry) {
        final data = entry.value;
        return DropdownMenuItem<String>(
          value: data['id'] as String,
          child: Row(
            children: [
              Icon(data['icon'],
                  size: 16, color: data['color'] ?? Colors.white),
              const SizedBox(width: 8),
              Text(data['label']),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
      validator: (value) => value == null ? 'Required' : null,
    );
  }
}
