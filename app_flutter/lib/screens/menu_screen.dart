import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'package:intl/intl.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';
import 'kitchen_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _supabase = Supabase.instance.client;
  final _cartService = CartService();

  Future<List<Product>> _fetchProducts() async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('is_available', true)
        .order('name', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => Product.fromJson(json)).toList();
  }

  // Helper to choose image
  ImageProvider _getImageForProduct(Product product) {
    final name = product.name.toLowerCase();

    // Override with local assets for demo
    if (name.contains('classic smash')) {
      return const AssetImage('assets/images/classic_smash.png');
    }
    if (name.contains('truffle') || name.contains('mushroom')) {
      return const AssetImage('assets/images/truffle_mushroom.png');
    }
    if (name.contains('craft') ||
        name.contains('ipa') ||
        name.contains('beer')) {
      return const AssetImage('assets/images/craft_ipa.png');
    }

    // Fallback to network
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return NetworkImage(product.imageUrl!);
    }

    // Fallback placeholder
    return const NetworkImage('https://via.placeholder.com/300?text=Manda.AI');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFE63946), Color(0xFFD62828)])),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manda.AI',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  Text('Restaurant OS',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Customer Menu'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.soup_kitchen),
              title: const Text('Kitchen Display (KDS)'),
              subtitle: const Text('Realtime Orders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const KitchenScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Manda.AI Menu',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CartScreen()));
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Menu is loading...',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final products = snapshot.data!;

          // Responsive Grid
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 600 ? 3 : (width > 400 ? 2 : 1);
              // Decreased ratio = Taller cards. 0.75 -> 0.68 to fix overflow
              final aspectRatio = width > 600 ? 0.68 : 0.65;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _buildProductCard(context, product);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Header
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image(
                image: _getImageForProduct(product),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200], child: const Icon(Icons.error)),
              ),
            ),
          ),

          // Content
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D3557),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NumberFormat.currency(symbol: '€')
                            .format(product.price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE63946),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _cartService.addToCart(product);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${product.name} to cart'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1D3557),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE63946),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
