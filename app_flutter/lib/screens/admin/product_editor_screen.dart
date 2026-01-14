import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product.dart';
import '../../services/app_translations.dart';
import '../../constants/categories.dart';

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
              'http://localhost:8000/admin/products/${widget.product!.id}')
          : Uri.parse('http://localhost:8000/admin/products');

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
              _buildTextField(
                  context, _imageController, 'productImage', Icons.image),
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
