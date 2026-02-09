import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb
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
import 'dart:async'; // For StreamSubscription
import '../services/auth_service.dart';
import 'admin/admin_login_screen.dart';
import 'driver/driver_home_screen.dart';
import 'client_orders_screen.dart'; // Import Client Orders
import 'scan_screen.dart';
import '../constants/categories.dart';
import 'package:animate_do/animate_do.dart';
// For barcode scanner usually, but using mock for now or simple dialog logic

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _supabase = Supabase.instance.client;
  final _cartService = CartService();
  String _selectedCategory = 'all';
  String? _userRole;
  bool _isLoadingRole = true;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _fetchUserRole();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final role = await AuthService().getUserRole();
    print('DEBUG: Fetched Role: $role');
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoadingRole = false;
      });

      // CRITICAL: If user is a client (logged in), ensure they're NOT in stale table mode
      // BUT: If they explicitly scanned a QR code, KEEP the tableId (allow Client + Table)
      if (role == 'client' &&
          _cartService.tableId != null &&
          !_cartService.isExplicitTableMode) {
        print(
            'DEBUG: Clearing STALE tableId for logged-in client (not from QR scan)');
        _cartService.setDeliveryAddress(
            ''); // This will clear tableId via mutual exclusivity
      }
    }
  }

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
    final isTableMode = _cartService.tableId != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Allow body to extend behind app bar and potential floating transparency
      extendBody: true,
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
                  Builder(
                    builder: (context) {
                      final user = _supabase.auth.currentUser;
                      if (user == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manda.AI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                                isTableMode
                                    ? '${AppTranslations.of(context, 'tableService')}: ${_cartService.tableId}'
                                    : AppTranslations.of(
                                        context, 'restaurantOS'),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14)),
                          ],
                        );
                      }
                      // Logged In User
                      final name = user.userMetadata?['full_name'] ??
                          user.email ??
                          'User';
                      final roleDisplay = _userRole?.toUpperCase() ?? 'USER';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            roleDisplay,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Common Menu (Always Visible)
            ListTile(
              leading: Icon(LucideIcons.utensils,
                  color: isDark ? Colors.white : Colors.black),
              title: Text(AppTranslations.of(context, 'customerMenu'),
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () => Navigator.pop(context),
            ),

            if (!isTableMode && !kIsWeb)
              ListTile(
                leading: Icon(LucideIcons.qrCode,
                    color: isDark ? Colors.white : Colors.black),
                title: Text(AppTranslations.of(context, 'scanTableQR'),
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ScanScreen()));
                },
              ),

            // Client Section (Only if role is client)
            if (_userRole == 'client') ...[
              const Divider(),
              ListTile(
                leading: Icon(LucideIcons.shoppingBag,
                    color: isDark ? Colors.white : Colors.black),
                title: Text(AppTranslations.of(context, 'myOrders'),
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ClientOrdersScreen()),
                  );
                },
              ),
            ],

            // Driver Section
            if (_userRole == 'driver') ...[
              const Divider(),
              ListTile(
                leading: Icon(LucideIcons.bike,
                    color: isDark ? Colors.white : Colors.black),
                title: Text(AppTranslations.of(context, 'driverDashboard'),
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DriverHomeScreen()),
                  );
                },
              ),
            ],

            // Admin Section
            if (_userRole == 'admin') ...[
              const Divider(),
              ListTile(
                leading: Icon(LucideIcons.chefHat,
                    color: isDark ? Colors.white : Colors.black),
                title: Text(AppTranslations.of(context, 'kitchenDisplay'),
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

            const Divider(),

            // Auth Actions
            if (_supabase.auth.currentUser != null)
              ListTile(
                leading: const Icon(LucideIcons.logOut, color: Colors.red),
                title: Text(AppTranslations.of(context, 'logout'),
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await AuthService().signOut();
                  Navigator.pop(context); // Close Drawer
                  setState(() => _userRole = null);
                },
              )
            else
              ListTile(
                leading: Icon(LucideIcons.logIn,
                    color: isDark ? Colors.white : Colors.black),
                title: Text(AppTranslations.of(context, 'login'),
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
                height: 70, // Reduced height for Pill style
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCategoryIds.length,
                  itemBuilder: (context, index) {
                    final catId = availableCategoryIds.elementAt(index);
                    final catData = categoryIdsMap[catId]!;
                    final isSelected = _selectedCategory == catId;

                    // Dynamic Translation Logic
                    final isEnglish =
                        Localizations.localeOf(context).languageCode == 'en';
                    final label = isEnglish
                        ? (catData['en_label'] ?? catData['label'])
                        : catData['label'];

                    return FadeInRight(
                      delay: Duration(milliseconds: index * 50),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = catId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? Colors.white
                                    : const Color(
                                        0xFF1E1E1E)) // Dark/White contrast
                                : (isDark ? Colors.grey[900] : Colors.white),
                            borderRadius:
                                BorderRadius.circular(30), // Pill Shape
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12),
                            boxShadow: [
                              if (!isSelected && !isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                catData['icon'],
                                size: 20,
                                color: isSelected
                                    ? (isDark
                                        ? Colors.black
                                        : Colors.white) // Icon Color contrast
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black87),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.black
                                          : Colors.white) // Text Color contrast
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Products Grid (Wrapped in padding for bottom nav)
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
                          final aspectRatio =
                              width > 600 ? 0.85 : 0.8; // Shorter cards

                          return GridView.builder(
                            padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 16,
                                bottom:
                                    100 // Extra padding for Floating Nav Bar
                                ),
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

          return Padding(
            padding: const EdgeInsets.only(bottom: 80.0), // Raise above nav bar
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  backgroundColor: const Color(0xFFE63946),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartScreen()),
                    );
                  },
                  child:
                      const Icon(LucideIcons.shoppingBag, color: Colors.white),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Softer corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Header with Hero tag for potential detail view transition
          Expanded(
            flex: 4, // More space for image
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    width: double.infinity,
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
                // Gradient Overlay for better contrast if we had text over image,
                // but here it adds depth
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            flex: 3,
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
                          letterSpacing: 0.5,
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
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat.currency(symbol: product.currency)
                            .format(product.price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE63946),
                        ),
                      ),
                      // Add Button
                      GestureDetector(
                        onTap: () {
                          // 0. Loading Check
                          if (_isLoadingRole) return;

                          final currentUser = AuthService().currentUser;
                          final isTableMode = CartService().tableId != null;

                          // 1. Guest Check
                          if (currentUser == null && !isTableMode) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppTranslations.of(
                                    context, 'loginToOrder')),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminLoginScreen()));
                            return;
                          }

                          // 2. Staff/Restriction Check
                          if (currentUser != null && _userRole != 'client') {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppTranslations.of(
                                    context, 'adminRestriction')),
                                backgroundColor: Colors.grey[800],
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          // 3. Client -> Add to Cart
                          _cartService.addToCart(product);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle,
                                      color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(
                                      '${product.name} ${AppTranslations.of(context, 'itemAdded')}',
                                      style: const TextStyle(
                                          color: Colors.black87)),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.yellow[100],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_userRole != null && _userRole != 'client')
                                ? Colors.grey
                                : const Color(0xFFE63946),
                            borderRadius:
                                BorderRadius.circular(12), // Rounded Square
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE63946).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: _isLoadingRole
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(
                                  (_userRole != null && _userRole != 'client')
                                      ? LucideIcons.lock
                                      : LucideIcons.plus,
                                  color: Colors.white,
                                  size: 20),
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

  // Temporary Mock Scanner until permission/camera logic is perfect
  void _showScanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Scan Table QR'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Enter Table ID (1-20)',
                    hintText: 'e.g., 5',
                    border: OutlineInputBorder()),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      CartService().setTableId(controller.text,
                          explicit: true); // Manual entry = explicit
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Table ${controller.text} Set! Ordering for Dine-in.'),
                          backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('Set Table'),
                )
              ],
            ));
  }
}
