import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/product.dart';
import '../../services/app_translations.dart';
import '../../services/settings_service.dart';
import '../../utils/image_helper.dart';
import 'product_editor_screen_modern.dart';
import '../../constants/api.dart';
import '../../widgets/admin/admin_scaffold.dart';
import '../../widgets/admin/admin_centered_layout.dart';

import '../../utils/responsive.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _supabase = Supabase.instance.client;
  final _settingsService = SettingsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Product> _allProducts = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _fetchProducts() async {
    // Get current user's establishment_id
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Fetch user profile to get establishment_id
    final profileResponse = await _supabase
        .from('profiles')
        .select('establishment_id')
        .eq('id', userId)
        .single();

    final establishmentId = profileResponse['establishment_id'] as String?;

    if (establishmentId == null) {
      throw Exception(
          'No establishment context. Please select an establishment.');
    }

    // Fetch products filtered by establishment
    final response = await _supabase
        .from('products')
        .select()
        .eq('establishment_id', establishmentId) // FILTER BY ESTABLISHMENT
        .order('name', ascending: true);

    final data = response as List<dynamic>;
    _allProducts = data.map((json) => Product.fromJson(json)).toList();
    return _allProducts;
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _allProducts;

    return _allProducts.where((p) {
      final nameMatches = p.name.toLowerCase().contains(query);
      final descMatches = p.description?.toLowerCase().contains(query) ?? false;
      return nameMatches || descMatches;
    }).toList();
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      final url =
          Uri.parse('${ApiConstants.baseUrl}/admin/products/${product.id}');
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          setState(() {
            _allProducts.removeWhere((p) => p.id == product.id);
          }); // Refresh list
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
        backgroundColor: Colors.white,
        title: Text(AppTranslations.of(context, 'confirmDelete'),
            style: const TextStyle(color: Colors.black)),
        content: Text(AppTranslations.of(context, 'deleteProductMessage'),
            style: const TextStyle(color: Colors.black87)),
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
    final useGridView =
        !Responsive.isMobile(context); // Grid for Tablet/Desktop
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return AdminScaffold(
      title: AppTranslations.of(context, 'products'),
      activeRoute: '/admin-products',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEA1D2C),
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: Text(useGridView ? 'Adicionar Produto' : 'Novo'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ProductEditorScreenModern()),
          );
          setState(() {}); // Refresh on return
        },
      ),
      body: AdminCenteredLayout(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar produtos...',
                  prefixIcon:
                      const Icon(LucideIcons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _fetchProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _allProducts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: TextStyle(color: textColor)));
                  }

                  final products = _filteredProducts;

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.package,
                              size: 64, color: textColor?.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum produto encontrado',
                            style: TextStyle(
                                color: textColor?.withOpacity(0.5),
                                fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  if (useGridView) {
                    // Desktop Grid View
                    return GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio:
                            0.75, // Taller cards for product images
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) =>
                          _buildProductCard(products[index], isDesktop: true),
                    );
                  } else {
                    // Mobile List View
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: products.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildProductCard(products[index], isDesktop: false),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product, {required bool isDesktop}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // Image Area
          // Image Area
          if (isDesktop)
            Expanded(
              flex: 3,
              child: _buildImageStack(product, isDesktop),
            )
          else
            SizedBox(
              height: 200,
              width: double.infinity,
              child: _buildImageStack(product, isDesktop),
            ),

          if (!isDesktop) ...[
            // In list view (mobile), we might not want the Expanded flex behavior same way,
            // but let's keep it simple. If flexible, we adapt.
            // Actually, for mobile list view, we might prefer a Row layout instead of Column.
            // But to keep code unified, we are using Column for both grid items?
            // Wait, ListView builder creates a list of these cards.
            // If isDesktop is false, we are in ListView. separate items.
            // The Card design above is vertical. For mobile list it might be better horizontally?
            // Let's adapt this method to return a Row-based card for mobile if needed,
            // or just keep vertical stack but fixed height.
            // Let's stick to the Vertical Card for Grid, but for List (Mobile) let's adjust.
          ],

          // Info Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                if (product.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      product.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13, height: 1.2),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: _settingsService.currencyNotifier,
                      builder: (context, currency, _) {
                        final symbol =
                            _settingsService.getCurrencySymbol(currency);
                        return Text(
                          NumberFormat.currency(symbol: symbol)
                              .format(product.price),
                          style: GoogleFonts.inter(
                              color: const Color(0xFFEA1D2C),
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ativo', // Placeholder for status if we had it
                        style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Overriding buildProductCard to handle Mobile List View vs Desktop Grid
  // Actually, let's split the logic inside the builder to return different widgets.
  // The above method handles the Card style (Grid).

  Widget _buildImageStack(Product product, bool isDesktop) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ImageHelper.buildProductImage(
            product.name,
            product.imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        // Action Buttons Overlay
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _buildActionButton(LucideIcons.edit3, Colors.blue, () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ProductEditorScreenModern(product: product)),
                );
                setState(() {});
              }),
              const SizedBox(width: 8),
              _buildActionButton(LucideIcons.trash2, Colors.red,
                  () => _confirmDelete(product)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
