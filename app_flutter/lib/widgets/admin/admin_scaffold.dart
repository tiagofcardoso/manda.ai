import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/admin_theme.dart';
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
    final bool isDesktop = Responsive.isDesktop(context);

    // Force Dark Theme for Admin Components
    return Theme(
      data: AdminTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AdminTheme.bgColor,
        appBar: !isDesktop
            ? AppBar(
                title: Text(title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: AdminTheme.bgColor,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: actions,
              )
            : null,
        drawer: !isDesktop
            ? _AdminSidebar(isMobile: true, activeRoute: activeRoute)
            : null,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop && showSidebar)
                Expanded(
                  flex: 2, // 2/12 = ~16% width
                  child: _AdminSidebar(isMobile: false, activeRoute: activeRoute),
                ),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    if (isDesktop)
                      _Header(title: title, actions: actions),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const _Header({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: AdminTheme.defaultPadding),
      color: AdminTheme.bgColor,
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(flex: 2),
          // Search Field Placeholder
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Pesquisar...",
                hintStyle: TextStyle(color: Colors.white54),
                fillColor: AdminTheme.secondaryColor,
                filled: true,
                border: const OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                suffixIcon: InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(AdminTheme.defaultPadding * 0.75),
                    margin: const EdgeInsets.symmetric(horizontal: AdminTheme.defaultPadding / 2),
                    decoration: const BoxDecoration(
                      color: AdminTheme.primaryColor,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(LucideIcons.search, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AdminTheme.defaultPadding),
          if (actions != null) ...actions!,
          const _ProfileCard(),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AdminTheme.defaultPadding),
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTheme.defaultPadding,
        vertical: AdminTheme.defaultPadding / 2,
      ),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AdminTheme.primaryColor,
            radius: 16,
            child: Icon(LucideIcons.user, size: 16, color: Colors.white),
          ),
          if (!Responsive.isMobile(context))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AdminTheme.defaultPadding / 2),
              child: Text("Admin", style: GoogleFonts.inter(color: Colors.white)),
            ),
          const Icon(LucideIcons.chevronDown, size: 16, color: Colors.white54),
        ],
      ),
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
    const kitchenTypes = {'restaurant', 'food', 'drinks', 'bar', 'cafe', 'bakery'};
    return _establishmentType == null || kitchenTypes.contains(_establishmentType);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AdminTheme.bgColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Flat edge
      child: SafeArea(
        child: Column(
          children: [
            // Logo Area
            Container(
              height: 80,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AdminTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.zap, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Manda.AI",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuItem(context, 'Dashboard', LucideIcons.layoutDashboard, '/admin-dashboard', widget.activeRoute == '/admin-dashboard'),
                  _buildMenuItem(context, 'Pedidos', LucideIcons.shoppingBag, '/admin-orders', widget.activeRoute == '/admin-orders'),
                  _buildMenuItem(context, 'Produtos', LucideIcons.box, '/admin-products', widget.activeRoute == '/admin-products'),
                  _buildMenuItem(context, 'Vendas', LucideIcons.barChart2, '/admin-sales', widget.activeRoute == '/admin-sales'),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Divider(color: Colors.white10),
                  ),
                  
                  if (_showKDS)
                    _buildMenuItem(context, 'Cozinha (KDS)', LucideIcons.monitor, '/kitchen', widget.activeRoute == '/kitchen'),
                  _buildMenuItem(context, 'Configurações', LucideIcons.settings, '/settings', widget.activeRoute == '/settings'),
                ],
              ),
            ),
            // Logout
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildMenuItem(context, 'Sair', LucideIcons.logOut, '/logout', false, isLogout: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, String route, bool isActive, {bool isLogout = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AdminTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isLogout 
            ? Colors.redAccent 
            : isActive ? AdminTheme.primaryColor : Colors.white54,
          size: 20,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isLogout 
              ? Colors.redAccent 
              : isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: () async {
          if (isActive) {
            if (widget.isMobile) Navigator.pop(context);
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
              page = const AdminOrdersScreen();
              break;
            case '/admin-products':
              page = const AdminProductsScreen();
              break;
            case '/admin-sales':
              page = const AdminSalesScreen();
              break;
            case '/kitchen':
              page = const KitchenScreen();
              break;
            case '/settings':
              page = const AdminSettingsScreen();
              break;
          }

          if (page != null) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page!));
          }
        },
      ),
    );
  }
}
