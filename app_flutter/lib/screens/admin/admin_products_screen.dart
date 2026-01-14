import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../services/app_translations.dart';
import '../../utils/image_helper.dart';
import 'product_editor_screen.dart';
import '../../constants/api.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _supabase = Supabase.instance.client;

  Future<List<Product>> _fetchProducts() async {
    final response = await _supabase
        .from('products')
        .select()
        .order('name', ascending: true); // Show ALL, not just available

    final data = response as List<dynamic>;
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      final url =
          Uri.parse('${ApiConstants.baseUrl}/admin/products/${product.id}');
      final response = await http.delete(url);

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          setState(() {}); // Refresh list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted')),
          );
        }
      } else {
        throw Exception('Failed to delete product: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(AppTranslations.of(context, 'confirmDelete'),
            style: const TextStyle(color: Colors.white)),
        content: Text(AppTranslations.of(context, 'deleteProductMessage'),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.of(context, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteProduct(product);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(LucideIcons.plus, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ProductEditorScreen()),
          );
          setState(() {}); // Refresh on return
        },
      ),
      body: Container(
        // Remove hardcoded background
        color: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: textColor,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  AppTranslations.of(context, 'products'),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: FutureBuilder<List<Product>>(
                future: _fetchProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                          child: Text('Error: ${snapshot.error}',
                              style: TextStyle(color: textColor))),
                    );
                  }

                  final products = snapshot.data ?? [];

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05)),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ImageHelper.buildProductImage(
                                  product.name, product.imageUrl,
                                  width: 64, height: 64),
                            ),
                            title: Text(
                              product.name,
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                NumberFormat.currency(symbol: '€')
                                    .format(product.price),
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.edit3,
                                      color: Colors.blueAccent, size: 20),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              ProductEditorScreen(
                                                  product: product)),
                                    );
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.trash2,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () => _confirmDelete(product),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
