import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';
import 'kitchen_screen.dart';

import '../services/theme_service.dart';
import '../services/app_translations.dart';
import '../utils/responsive.dart';
import 'dart:async'; // For StreamSubscription
import '../services/auth_service.dart';
import 'admin/admin_login_screen.dart';
import 'driver/driver_home_screen.dart';
import 'client_orders_screen.dart'; // Import Client Orders
import 'scan_screen.dart';
import '../constants/categories.dart';
import '../services/settings_service.dart';
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
  Map<String, dynamic>? _establishment;
  List<Map<String, dynamic>> _dbCategories = [];
  late final StreamSubscription<AuthState> _authSubscription;
  Offset _cartPosition = const Offset(20, 100);

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchEstablishment();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _fetchUserRole();
    });
  }

  Future<void> _fetchEstablishment() async {
    final estId = _cartService.establishmentId;
    if (estId != null) {
      try {
        await SettingsService().loadCurrencyForEstablishment(estId);

        final res = await _supabase
            .from('establishments')
            .select('name, type')
            .eq('id', estId)
            .maybeSingle();
            
        final catRes = await _supabase
            .from('categories')
            .select('id, name')
            .eq('establishment_id', estId)
            .order('sort_order', ascending: true);

        if (mounted && res != null) {
          setState(() {
            _establishment = res;
            _dbCategories = List<Map<String, dynamic>>.from(catRes);
          });
        }
      } catch (e) {
        debugPrint('Error fetching establishment: $e');
      }
    }
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
    final estId = _cartService.establishmentId;

    // If no establishment selected (e.g. fresh install, no scan), what to do?
    // For now, if no ID, return empty or default?
    // Let's assume user MUST scan or select store.
    if (estId == null) {
      print('DEBUG: No Establishment ID set. Returning empty menu.');
      // return []; // Strict Mode
      // FALLBACK for demo: Fetch all (Legacy) - remove this for production
      // return [];
    }

    // Start building query
    // Cast to PostgrestFilterBuilder to allow filtering
    var query = _supabase.from('products').select();

    // Apply Filters
    if (estId != null) {
      query = query.eq('establishment_id', estId);
    }

    // Always apply available filter
    query = query.eq('is_available', true);

    // Apply Order & Execute
    final response = await query.order('name', ascending: true);

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
            if (!isTableMode)
              ListTile(
                leading: Icon(LucideIcons.store,
                    color: isDark ? Colors.white : Colors.black),
                title: Text("Change Store", // TODO: Translate
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  // Go back to landing or marketplace
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ListTile(
              leading: Icon(LucideIcons.utensils,
                  color: isDark ? Colors.white : Colors.black),
              title: Text(AppTranslations.of(context, 'customerMenu'),
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () => Navigator.pop(context),
            ),

            // Only show Scan QR for restaurant/bar/cafe types
            if (!isTableMode &&
                (_establishment?['type'] == 'restaurant' ||
                    _establishment?['type'] == 'bars' ||
                    _establishment?['type'] == 'cafe'))
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
        title: Row(
          children: [
            Icon(LucideIcons.mapPin, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              _establishment != null ? _establishment!['name'] ?? '' : '...',
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              ThemeService().themeMode == ThemeMode.dark ? LucideIcons.sun : LucideIcons.moon,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ),
            onPressed: () => ThemeService().toggleTheme(),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: CartService().itemsNotifier,
        builder: (context, items, _) {
          final count = items.fold(0, (sum, item) => sum + item.quantity);
          return Stack(
            children: [
              FutureBuilder<List<Product>>(
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

          // Get available product category IDs
          final availableProductCatIds = {
            ...allProducts
                .map((p) => p.categoryId ?? p.customCategory)
                .where((id) => id != null)
                .cast<String>()
          };

          // Filter DB categories to only those with active products
          final dbCatsWithProducts = _dbCategories
              .where((c) => availableProductCatIds.contains(c['id']))
              .toList();

          // Build final list of tabs to render
          final isEnglish = Localizations.localeOf(context).languageCode == 'en';
          final List<Map<String, dynamic>> allCategoryTabs = [
            {
              'id': 'all',
              'name': isEnglish ? 'All' : 'Todos',
              'icon': LucideIcons.layoutGrid
            },
            ...dbCatsWithProducts.map((c) {
              // Try to find matching icon from APP_CATEGORIES
              IconData? matchedIcon;
              for (var entry in APP_CATEGORIES.values) {
                if (entry['id'] == c['id']) {
                  matchedIcon = entry['icon'] as IconData?;
                  break;
                }
              }
              return {
                'id': c['id'],
                'name': c['name'],
                'icon': matchedIcon ?? LucideIcons.tag,
              };
            })
          ];

          final filteredProducts = _selectedCategory == 'all'
              ? allProducts
              : allProducts
                  .where((p) => (p.categoryId ?? p.customCategory) == _selectedCategory)
                  .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom Header / Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Olá, Oque manda?",
                          style: TextStyle(
                            fontSize: Responsive.isMobile(context) ? 28 : 36,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Categories List
                  SizedBox(
                    height: 50, // Reduced height for Pill style
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: allCategoryTabs.length,
                      itemBuilder: (context, index) {
                        final catData = allCategoryTabs[index];
                        final catId = catData['id'] as String;
                        final isSelected = _selectedCategory == catId;
                        final label = catData['name'] as String;
                        final icon = catData['icon'] as IconData;

                        return FadeInRight(
                          delay: Duration(milliseconds: index * 50),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = catId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE63946)
                                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                borderRadius: BorderRadius.circular(25), // Pill Shape
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: const Color(0xFFE63946).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  else if (!isDark)
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
                                    icon,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
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
                  const SizedBox(height: 16),

                  // Products Grid 
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? Center(
                            child: Text(
                              AppTranslations.of(context, 'noData'),
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              // Dynamically calculate columns based on width
                              final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);
                              
                              // Calculate dynamic aspect ratio to keep cards around 240px tall 
                              // (Total Width - padding - crossAxisSpacing) / crossAxisCount
                              final itemWidth = (width - 40 - ((crossAxisCount - 1) * 20)) / crossAxisCount;
                              final itemHeight = 240.0;
                              final aspectRatio = itemWidth / itemHeight;

                              return GridView.builder(
                                padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 100),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: aspectRatio,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 40, // More spacing for overlapping top image
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return FadeInUp(
                                    delay: Duration(milliseconds: index * 50),
                                    child: _buildProductCard(context, product),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
              if (count > 0)
                Positioned(
                  right: _cartPosition.dx,
                  bottom: _cartPosition.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        // Positioned depends on right/bottom, so we subtract delta
                        _cartPosition = Offset(
                          (_cartPosition.dx - details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - 60.0),
                          (_cartPosition.dy - details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - 100.0),
                        );
                      });
                    },
                    child: Stack(
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
                              border: Border.all(color: const Color(0xFFE63946), width: 2),
                            ),
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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

    return GestureDetector(
      onTap: () => _showExpandedCard(context, product),
      child: Stack(
        clipBehavior: Clip.none,
      children: [
        // Background Card
        Positioned.fill(
          top: 50, // Push the card down to let the image overflow
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            padding: const EdgeInsets.only(left: 12, right: 12, top: 75, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.isMobile(context) ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.description ?? 'Delicioso e fresquinho',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Footer (Price & Add to cart button)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: SettingsService().currencyNotifier,
                        builder: (context, currency, _) {
                          final symbol = SettingsService().getCurrencySymbol(currency);
                          return Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${symbol} ${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Add to Cart Button (Mini)
                      GestureDetector(
                        onTap: () {
                          if (_isLoadingRole) return;
                          
                          // Quick check logic identical to previous
                          final currentUser = AuthService().currentUser;
                          final isTableMode = CartService().tableId != null;

                          if (currentUser == null && !isTableMode) {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminLoginScreen()));
                            return;
                          }
                          if (currentUser != null && _userRole != 'client') {
                            return; // Admin restriction
                          }

                          _cartService.addToCart(product);
                          // Provide simple quick feedback without interrupting flow
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.plus, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating Image overlapping the card
        Positioned(
          top: -5, // Stick out from the grid cell a little bit
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.center,
            child: Hero(
              tag: 'product_image_${product.id}',
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                  border: Border.all(color: Colors.white, width: 4),
                  image: DecorationImage(
                    image: _getImageForProduct(product),
                    fit: BoxFit.cover, 
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  void _showExpandedCard(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Container(
                width: Responsive.isMobile(context) ? MediaQuery.of(context).size.width * 0.85 : 400,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'product_image_${product.id}', 
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                          border: Border.all(color: Colors.white, width: 4),
                          image: DecorationImage(
                            image: _getImageForProduct(product),
                            fit: BoxFit.cover, 
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product.description ?? 'Delicioso e fresquinho',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: SettingsService().currencyNotifier,
                          builder: (context, currency, _) {
                            final symbol = SettingsService().getCurrencySymbol(currency);
                            return Flexible(
                              child: Text(
                                '$symbol ${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            );
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_isLoadingRole) return;
                            final currentUser = AuthService().currentUser;
                            final isTableMode = CartService().tableId != null;

                            if (currentUser == null && !isTableMode) {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminLoginScreen()));
                              return;
                            }
                            if (currentUser != null && _userRole != 'client') return;

                            _cartService.addToCart(product);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Adicionado ao carrinho!'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(LucideIcons.plus, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
