import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../services/app_translations.dart';
import '../../constants/api.dart';
import 'admin_products_screen.dart';
import 'admin_sales_screen.dart';
import 'admin_orders_screen.dart';
import '../kitchen_screen.dart';
import '../../widgets/admin/admin_scaffold.dart';

import '../../utils/responsive.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {
    "total_revenue": 0.0,
    "total_orders": 0,
    "delivery_count": 0,
    "kitchen_count": 0
  };
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Super Admin Context
  bool _isSuperAdmin = false;
  String? _establishmentName;
  // String? _establishmentId; // Unused

  @override
  void initState() {
    super.initState();
    _checkSuperAdminContext();
    _fetchStats();
    // Refresh stats every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchStats(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/stats/today'),
        headers: {
          "Authorization": "Bearer ${session.accessToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _stats = data;
            _isLoading = false;
          });
        }
      } else {
        debugPrint("Error fetching stats: ${response.body}");
        if (mounted && !silent) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  /// Check if current user is Super Admin with establishment context
  Future<void> _checkSuperAdminContext() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch user profile to check role and establishment_id
      final response = await supabase
          .from('profiles')
          .select('role, establishment_id, establishments(name)')
          .eq('id', userId)
          .single();

      final role = response['role'];
      final establishmentId = response['establishment_id'];

      // If super_admin with establishment_id set, they're impersonating
      if (role == 'super_admin' && establishmentId != null) {
        if (mounted) {
          setState(() {
            _isSuperAdmin = true;
            // _establishmentId = establishmentId; // Unused

            // Get establishment name
            if (response['establishments'] != null) {
              _establishmentName = response['establishments']['name'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking super admin context: $e');
    }
  }

  /// Exit admin mode and return to Super Admin Dashboard
  Future<void> _exitAdminMode() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Clear establishment_id from profile
      await supabase
          .from('profiles')
          .update({'establishment_id': null}).eq('id', userId);

      if (mounted) {
        // Navigate back to Super Admin Dashboard
        Navigator.of(context).pushReplacementNamed('/super-admin-dashboard');
      }
    } catch (e) {
      debugPrint('Error exiting admin mode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return AdminScaffold(
      title: AppTranslations.of(context, 'adminDashboard'),
      activeRoute: '/admin-dashboard',
      // Show Super Admin badge and exit button when in impersonation mode
      actions: _isSuperAdmin
          ? [
              // Establishment Badge
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.building2,
                        size: 16, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Text(
                      _establishmentName ?? 'Establishment',
                      style: GoogleFonts.inter(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Exit Button
              Tooltip(
                message: 'Exit Admin Mode',
                child: InkWell(
                  onTap: _exitAdminMode,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.logOut,
                            size: 18, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Exit',
                          style: GoogleFonts.inter(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ]
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards - Responsive Layout
            if (Responsive.isDesktop(context) ||
                Responsive.width(context) > 900)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      "Vendas Hoje",
                      _isLoading
                          ? "..."
                          : currencyFormat.format(_stats['total_revenue']),
                      LucideIcons.dollarSign,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      "Pedidos",
                      _isLoading ? "..." : "${_stats['total_orders']}",
                      LucideIcons.shoppingBag,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      "Entregas",
                      _isLoading ? "..." : "${_stats['delivery_count'] ?? 0}",
                      LucideIcons.bike,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      "Cozinha (Ativos)",
                      _isLoading ? "..." : "${_stats['kitchen_count'] ?? 0}",
                      LucideIcons.chefHat,
                      Colors.red,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Vendas Hoje",
                          _isLoading
                              ? "..."
                              : currencyFormat.format(_stats['total_revenue']),
                          LucideIcons.dollarSign,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Pedidos",
                          _isLoading ? "..." : "${_stats['total_orders']}",
                          LucideIcons.shoppingBag,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Entregas",
                          _isLoading
                              ? "..."
                              : "${_stats['delivery_count'] ?? 0}",
                          LucideIcons.bike,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Cozinha (Ativos)",
                          _isLoading
                              ? "..."
                              : "${_stats['kitchen_count'] ?? 0}",
                          LucideIcons.chefHat,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Quick Actions Title
            Text(
              AppTranslations.of(context, 'quickActions'),
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Actions Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: Responsive.isDesktop(context)
                  ? 4
                  : 2, // Use Responsive helper
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // Taller cards on mobile (1.3) vs desktop (1.5) to avoid overflow
              childAspectRatio: Responsive.isMobile(context)
                  ? 1.3
                  : 1.5, // Use Responsive helper
              children: [
                _buildActionCard(
                  context,
                  AppTranslations.of(context, 'products'),
                  LucideIcons.utensils,
                  Colors.orange,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminProductsScreen())),
                ),
                _buildActionCard(
                  context,
                  AppTranslations.of(context, 'sales'),
                  LucideIcons.barChart2,
                  Colors.purple,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminSalesScreen())),
                ),
                _buildActionCard(
                  context,
                  AppTranslations.of(context, 'orders'),
                  LucideIcons.listOrdered,
                  Colors.blue,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminOrdersScreen())),
                ),
                _buildActionCard(
                  context,
                  AppTranslations.of(context, 'kitchenDisplayTitle'),
                  LucideIcons.monitor,
                  Colors.deepOrange,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const KitchenScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Prevent overflow of long values (e.g. large currency amounts)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon,
      Color accentColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
