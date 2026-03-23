import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/responsive.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_orders_screen.dart';
import '../../screens/admin/admin_products_screen.dart';
import '../../screens/admin/admin_sales_screen.dart';
import '../../screens/admin/admin_settings_screen.dart';
import '../../screens/kitchen_screen.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final bool showSidebar;
  final String activeRoute;
  final List<Widget>? actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.activeRoute,
    this.floatingActionButton,
    this.showSidebar = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // Use Responsive helper. Treat Tablet as Mobile (Drawer) for simplicity, or modify Responsive to include specific Sidebar breakpoint.
    // For now, let's align with the Desktop breakpoint (1200) for standard layout,
    // OR we can allow Tablets (>= 600) to have sidebar if we rotate?
    // The previous code used 900. Let's use Responsive.width(context) > 900 for now to minimize regression,
    // but using the helper class accessing width.
    final bool isDesktop =
        Responsive.isDesktop(context) || Responsive.width(context) > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7), // Soft background for admin
      appBar: !isDesktop
          ? AppBar(
              title: Text(title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black87),
              actions: actions,
            )
          : null, // No AppBar on desktop, we use the sidebar headers
      drawer: !isDesktop
          ? _AdminSidebar(isMobile: true, activeRoute: activeRoute)
          : null,
      body: Row(
        children: [
          // Desktop Sidebar
          if (isDesktop && showSidebar)
            SizedBox(
              width: 250,
              child: _AdminSidebar(isMobile: false, activeRoute: activeRoute),
            ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                if (isDesktop)
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    color: Colors.white,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title,
                            style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        Row(
                          children: [
                            if (actions != null) ...actions!,
                            const SizedBox(width: 16),
                            IconButton(
                                onPressed: () {},
                                icon: const Icon(LucideIcons.bell,
                                    color: Colors.grey)),
                            const SizedBox(width: 16),
                            const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Text("A",
                                  style: TextStyle(color: Colors.white)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _AdminSidebar extends StatefulWidget {
  final bool isMobile;
  final String activeRoute;

  const _AdminSidebar({required this.isMobile, required this.activeRoute});

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  String? _establishmentType;

  @override
  void initState() {
    super.initState();
    _fetchEstablishmentType();
  }

  Future<void> _fetchEstablishmentType() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('establishment_id')
          .eq('id', user.id)
          .single();

      final estId = profile['establishment_id'];
      if (estId == null) return;

      final est = await supabase
          .from('establishments')
          .select('type')
          .eq('id', estId)
          .single();

      if (mounted) {
        setState(() => _establishmentType = est['type']?.toString().toLowerCase());
      }
    } catch (e) {
      debugPrint('Could not fetch establishment type: $e');
    }
  }

  bool get _showKDS {
    // Show KDS only for restaurant/food/drinks types
    const kitchenTypes = {'restaurant', 'food', 'drinks', 'bar', 'cafe', 'bakery'};
    return _establishmentType == null || kitchenTypes.contains(_establishmentType);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // White sidebar
      child: SafeArea(
        child: Column(
          children: [
            // Logo Area
            Container(
              height: widget.isMobile ? 150 : 80,
              alignment: widget.isMobile ? Alignment.center : Alignment.centerLeft,
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: widget.isMobile
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEA1D2C),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(LucideIcons.zap,
                          color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Text("Manda.AI",
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800, fontSize: 22)),
                ],
              ),
            ),

            if (widget.isMobile) const Divider(),

            // Menu Items
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildMenuItem(
                      context,
                      'Dashboard',
                      LucideIcons.layoutDashboard,
                      '/admin-dashboard',
                      widget.activeRoute == '/admin-dashboard'),
                  _buildMenuItem(context, 'Pedidos', LucideIcons.shoppingBag,
                      '/admin-orders', widget.activeRoute == '/admin-orders'),
                  _buildMenuItem(context, 'Produtos', LucideIcons.utensils,
                      '/admin-products', widget.activeRoute == '/admin-products'),
                  _buildMenuItem(context, 'Vendas', LucideIcons.barChart2,
                      '/admin-sales', widget.activeRoute == '/admin-sales'),
                  const Divider(height: 32),
                  // KDS only for restaurant/drinks type establishments
                  if (_showKDS)
                    _buildMenuItem(context, 'Cozinha (KDS)', LucideIcons.monitor,
                        '/kitchen', widget.activeRoute == '/kitchen'),
                  _buildMenuItem(context, 'Configurações', LucideIcons.settings,
                      '/settings', widget.activeRoute == '/settings'),
                ],
              ),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMenuItem(
                  context, 'Sair', LucideIcons.logOut, '/logout', false,
                  isLogout: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon,
      String route, bool isActive,
      {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon,
          color: isLogout
              ? Colors.red
              : (isActive ? const Color(0xFFEA1D2C) : Colors.grey[600])),
      title: Text(title,
          style: GoogleFonts.inter(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isLogout
                  ? Colors.red
                  : (isActive ? const Color(0xFFEA1D2C) : Colors.black87))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isActive
          ? const Color(0xFFEA1D2C).withOpacity(0.08)
          : Colors.transparent,
      onTap: () async {
        if (isActive) {
          if (widget.isMobile) {
            Navigator.pop(context); // Close drawer if already on page
          }
          return;
        }

        if (isLogout) {
          await Supabase.instance.client.auth.signOut();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
          return;
        }

        Widget? page;
        switch (route) {
          case '/admin-dashboard':
            page = const AdminDashboardScreen();
            break;
          case '/admin-orders':
            page =
                const AdminOrdersScreen(); // Needs AdminScaffold wrapper update
            break;
          case '/admin-products':
            page =
                const AdminProductsScreen(); // Needs AdminScaffold wrapper update
            break;
          case '/admin-sales':
            page =
                const AdminSalesScreen(); // Needs AdminScaffold wrapper update check
            break;
          case '/kitchen':
            page = const KitchenScreen();
            break;
          case '/settings':
            page = const AdminSettingsScreen();
            break;
        }

        if (page != null) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => page!));
        }
      },
    );
  }
}
