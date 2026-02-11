import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SuperAdminEstablishmentScreen extends StatefulWidget {
  final Map<String, dynamic> establishment;

  const SuperAdminEstablishmentScreen({
    super.key,
    required this.establishment,
  });

  @override
  State<SuperAdminEstablishmentScreen> createState() =>
      _SuperAdminEstablishmentScreenState();
}

class _SuperAdminEstablishmentScreenState
    extends State<SuperAdminEstablishmentScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final establishmentId = widget.establishment['id'];

      // Fetch products
      final productsResponse = await _supabase
          .from('products')
          .select('*, categories(name)')
          .eq('establishment_id', establishmentId)
          .order('name');

      // Fetch categories
      final categoriesResponse = await _supabase
          .from('categories')
          .select()
          .eq('establishment_id', establishmentId)
          .order('name');

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsResponse);
        _categories = List<Map<String, dynamic>>.from(categoriesResponse);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createProduct() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    String? selectedCategoryId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  hint: const Text('Select Category'),
                  items: _categories.map<DropdownMenuItem<String>>((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id'],
                      child: Text(cat['name']),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() {
                    selectedCategoryId = val;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitProduct(
                  nameController.text.trim(),
                  descController.text.trim(),
                  priceController.text.trim(),
                  selectedCategoryId,
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitProduct(
      String name, String desc, String price, String? categoryId) async {
    if (name.isEmpty || price.isEmpty) return;

    try {
      await _supabase.from('products').insert({
        'name': name,
        'description': desc,
        'price': double.parse(price),
        'establishment_id': widget.establishment['id'],
        'category_id': categoryId,
        'is_available': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created!')),
      );
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('products').delete().eq('id', id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
        _fetchData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estName = widget.establishment['name'];
    final isActive = widget.establishment['is_active'] ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(estName),
            Text(
              'Super Admin Mode',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          if (!isActive)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: const Text('SUSPENDED'),
                backgroundColor: Colors.red[100],
                labelStyle: TextStyle(
                  color: Colors.red[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.packageOpen,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No products yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _createProduct,
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('Add First Product'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final categoryName = product['categories']?['name'];

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image placeholder
                          Container(
                            height: 120,
                            color: Colors.grey[300],
                            child: product['image_url'] != null
                                ? Image.network(product['image_url'],
                                    fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(LucideIcons.image, size: 48),
                                  ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (categoryName != null)
                                    Text(
                                      categoryName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '€${product['price'].toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.green,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2,
                                            color: Colors.red, size: 20),
                                        onPressed: () => _deleteProduct(
                                            product['id'], product['name']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProduct,
        label: const Text('Add Product'),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: Colors.black87,
      ),
    );
  }
}
