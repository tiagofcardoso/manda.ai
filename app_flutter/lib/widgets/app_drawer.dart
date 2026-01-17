import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/app_translations.dart';
import '../screens/main_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/driver/driver_home_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/client_orders_screen.dart';
import '../screens/guest_table_order_screen.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _role;
  String? _email;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final role = await AuthService().getUserRole();
      if (mounted) {
        setState(() {
          _role = role;
          _email = user.email;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context); // Close drawer
    // Use pushReplacement to avoid building a huge stack
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE63946),
            ),
            accountName: Text(
              _isLoading ? 'Loading...' : (_role?.toUpperCase() ?? 'GUEST'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_email ?? 'No active session'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                LucideIcons.user,
                size: 32,
                color: isDark ? Colors.black : const Color(0xFFE63946),
              ),
            ),
          ),

          // Menu Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Everyone sees Home/Menu
                      ListTile(
                        leading: const Icon(LucideIcons.utensilsCrossed),
                        title: Text(AppTranslations.of(context, 'menu')),
                        onTap: () => _navigateTo(const MainScreen()),
                      ),

                      // Driver
                      if (_role == 'driver' ||
                          _role == 'admin' ||
                          _role == 'manager')
                        ListTile(
                          leading: const Icon(LucideIcons.bike),
                          title: Text(
                              AppTranslations.of(context, 'driverDashboard')),
                          onTap: () => _navigateTo(const DriverHomeScreen()),
                        ),

                      // Kitchen
                      if (_role == 'kitchen' ||
                          _role == 'admin' ||
                          _role == 'manager')
                        ListTile(
                          leading: const Icon(LucideIcons.chefHat),
                          title: Text(AppTranslations.of(
                              context, 'kitchenDisplayTitle')),
                          onTap: () => _navigateTo(const KitchenScreen()),
                        ),

                      // Admin
                      if (_role == 'admin' || _role == 'manager')
                        ListTile(
                          leading: const Icon(LucideIcons.layoutDashboard),
                          title: Text(
                              AppTranslations.of(context, 'adminDashboard')),
                          onTap: () =>
                              _navigateTo(const AdminDashboardScreen()),
                        ),

                      const Divider(),

                      // Table Order (Visible if Table Mode is active)
                      if (CartService().tableId != null ||
                          (_role == null &&
                              OrderService().currentOrderId != null))
                        ListTile(
                          leading: const Icon(LucideIcons.utensilsCrossed,
                              color: Color(0xFFE63946)),
                          title:
                              Text(AppTranslations.of(context, 'tableOrder')),
                          onTap: () =>
                              _navigateTo(const GuestTableOrderScreen()),
                        ),

                      // My Orders (Client History)
                      if (_role == 'client')
                        ListTile(
                          leading: const Icon(LucideIcons.shoppingBag),
                          title: Text(AppTranslations.of(context, 'myOrders')),
                          onTap: () => _navigateTo(const ClientOrdersScreen()),
                        ),

                      // Scan QR (Clients Only)
                      if (_role == 'client' || _role == null)
                        ListTile(
                          leading: const Icon(LucideIcons.qrCode),
                          title: Text(AppTranslations.of(context, 'scanTable')),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const ScanScreen()),
                            );
                          },
                        ),
                    ],
                  ),
          ),

          // Footer / Logout
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.grey),
            title: Text(AppTranslations.of(context, 'logout'),
                style: const TextStyle(color: Colors.grey)),
            onTap: () async {
              await AuthService().signOut();
              if (mounted) {
                // Return to Landing Screen (which is essentially a "fresh start")
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
