import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import 'package:intl/intl.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';
import 'kitchen_screen.dart';

import '../services/theme_service.dart';
import '../services/app_translations.dart';
import '../services/locale_service.dart';
import 'admin/admin_login_screen.dart';
import '../constants/categories.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _supabase = Supabase.instance.client;
  final _cartService = CartService();
  String _selectedCategory = 'all';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // No explicit background color, uses Theme.scaffoldBackgroundColor
      drawer: Drawer(
        // Drawer color uses Theme default or override if needed
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFFE63946)])),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manda.AI',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  Text('Restaurant OS',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(LucideIcons.utensils,
                  color: isDark ? Colors.white : Colors.black),
              title: Text('Customer Menu',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: Icon(LucideIcons.chefHat,
                  color: isDark ? Colors.white : Colors.black),
              title: Text('Kitchen Display (KDS)',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              subtitle: const Text('Realtime Orders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const KitchenScreen()));
              },
            ),
            const Divider(), // Another divider for separation
            ListTile(
              leading: Icon(LucideIcons.shield,
                  color: isDark ? Colors.white : Colors.black),
              title: Text(AppTranslations.of(context, 'managerArea'),
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminLoginScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTranslations.of(context, 'menu'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "Manda Burger Pub",
              style: Theme.of(context).textTheme.bodySmall,
            )
          ],
        ),
        // AppBar colors handled by Theme
        actions: [
          // Language Toggle
          IconButton(
            icon: Text(
              Localizations.localeOf(context).languageCode == 'en'
                  ? '🇺🇸'
                  : '🇧🇷',
              style: const TextStyle(fontSize: 24),
            ),
            onPressed: () {
              LocaleService().toggleLocale();
            },
          ),
          // Theme Toggle
          IconButton(
            icon: Icon(
              ThemeService().themeMode == ThemeMode.dark
                  ? LucideIcons.sun
                  : LucideIcons.moon,
            ),
            onPressed: () {
              ThemeService().toggleTheme();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.utensils, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Menu is loading...',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final allProducts = snapshot.data!;

          // Create lookup map: UUID -> CategoryData
          final categoryIdsMap = {
            'all': APP_CATEGORIES['all']!,
            for (var entry in APP_CATEGORIES.values)
              if (entry['id'] != 'all') entry['id'] as String: entry
          };

          // Get available categories from products
          final availableCategoryIds = {
            'all',
            ...allProducts
                .map((p) => p.categoryId)
                .where((id) => id != null && categoryIdsMap.containsKey(id))
                .cast<String>()
          };

          final filteredProducts = _selectedCategory == 'all'
              ? allProducts
              : allProducts
                  .where((p) => p.categoryId == _selectedCategory)
                  .toList();

          return Column(
            children: [
              // Categories List
              Container(
                height: 100,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCategoryIds.length,
                  itemBuilder: (context, index) {
                    final catId = availableCategoryIds.elementAt(index);
                    final catData = categoryIdsMap[catId]!;
                    final isSelected = _selectedCategory == catId;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = catId),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE63946)
                                    : (isDark
                                        ? Colors.grey[800]
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                ],
                              ),
                              child: Icon(
                                catData['icon'],
                                size: 28,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              catData['label'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? (isDark
                                        ? Colors.white
                                        : const Color(0xFFE63946))
                                    : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Products Grid
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          AppTranslations.of(context, 'noData'),
                          style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount =
                              width > 600 ? 3 : (width > 400 ? 2 : 1);
                          final aspectRatio = width > 600 ? 0.68 : 0.65;

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: aspectRatio,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _buildProductCard(context, product);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<List<CartItem>>(
        valueListenable: CartService().itemsNotifier,
        builder: (context, items, _) {
          final count = items.fold(0, (sum, item) => sum + item.quantity);
          if (count == 0) return const SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.none,
            children: [
              FloatingActionButton(
                backgroundColor: const Color(0xFFE63946),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
                child: const Icon(LucideIcons.shoppingBag, color: Colors.white),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFE63946), width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFFE63946),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, // Use Theme Card Color
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(LucideIcons.alertCircle,
                        color: isDark ? Colors.white : Colors.black)),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                              content: Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle,
                                      color: Colors.green),
                                  const SizedBox(width: 8),
                                  // Text must be black on light yellow background
                                  Text('${product.name} added to cart!',
                                      style: const TextStyle(
                                          color: Colors.black87)),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor:
                                  Colors.yellow[100], // Amarelo Fraquinho
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE63946),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.plus,
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
