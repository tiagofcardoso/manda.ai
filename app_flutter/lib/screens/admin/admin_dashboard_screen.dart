import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_translations.dart';
import 'admin_products_screen.dart';
import 'admin_sales_screen.dart';
import 'admin_orders_screen.dart';
import '../kitchen_screen.dart';

import '../../widgets/admin/admin_scaffold.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: AppTranslations.of(context, 'adminDashboard'),
      activeRoute: '/admin-dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    "Vendas Hoje",
                    "R\$ 1.250,00",
                    LucideIcons.dollarSign,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    "Pedidos",
                    "12",
                    LucideIcons.shoppingBag,
                    Colors.blue,
                  ),
                ),
                if (MediaQuery.of(context).size.width > 1200) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      "Entregas",
                      "4",
                      LucideIcons.bike,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      "Cozinha",
                      "3",
                      LucideIcons.chefHat,
                      Colors.red,
                    ),
                  ),
                ]
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
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // Taller cards on mobile (1.3) vs desktop (1.5) to avoid overflow
              childAspectRatio:
                  MediaQuery.of(context).size.width > 600 ? 1.5 : 1.3,
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
