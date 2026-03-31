import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../services/app_translations.dart';
import '../../constants/api.dart';
import '../../constants/admin_theme.dart';
import '../../widgets/admin/admin_scaffold.dart';
import '../../utils/responsive.dart';
import 'admin_tables_screen.dart';

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
  List<dynamic> _recentOrders = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  bool _isSuperAdmin = false;
  String? _establishmentName;
  String? _establishmentId;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminContext();
    _fetchStats();
    _fetchRecentOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchStats(silent: true);
        _fetchRecentOrders();
      }
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
        if (mounted) {
          setState(() {
            _stats = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRecentOrders() async {
    try {
      final supabase = Supabase.instance.client;
      // Fetch the 5 most recent orders for the UI
      final response = await supabase
          .from('orders')
          .select('id, total_price, status, created_at, order_type')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() => _recentOrders = response);
      }
    } catch (e) {
      debugPrint("Error fetching recent orders: $e");
    }
  }

  Future<void> _checkSuperAdminContext() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('profiles')
          .select('role, establishment_id, establishments(name)')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _establishmentId = response['establishment_id'];
          if (response['establishments'] != null) {
            _establishmentName = response['establishments']['name'];
          }
          if (response['role'] == 'super_admin' && _establishmentId != null) {
            _isSuperAdmin = true;
          }
        });
      }
    } catch (e) {}
  }

  Future<void> _exitAdminMode() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('profiles').update({'establishment_id': null}).eq('id', userId);
      if (mounted) Navigator.of(context).pushReplacementNamed('/super-admin-dashboard');
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: AppTranslations.of(context, 'adminDashboard'),
      activeRoute: '/admin-dashboard',
      actions: _isSuperAdmin
          ? [
              // Badge & Exit logic skipped for brevity, keeping simple for this design
              IconButton(onPressed: _exitAdminMode, icon: const Icon(LucideIcons.logOut, color: Colors.redAccent))
            ]
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminTheme.defaultPadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildStatCardsRow(context),
                        const SizedBox(height: AdminTheme.defaultPadding),
                        _buildRecentOrders(),
                        if (Responsive.isMobile(context))
                          const SizedBox(height: AdminTheme.defaultPadding),
                        if (Responsive.isMobile(context))
                          const _OrderDetailsChart(),
                      ],
                    ),
                  ),
                  if (!Responsive.isMobile(context))
                    const SizedBox(width: AdminTheme.defaultPadding),
                  if (!Responsive.isMobile(context))
                    const Expanded(
                      flex: 2,
                      child: _OrderDetailsChart(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
      crossAxisSpacing: AdminTheme.defaultPadding,
      mainAxisSpacing: AdminTheme.defaultPadding,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard("Vendas (Hoje)", _isLoading ? "..." : currencyFormat.format(_stats['total_revenue']), LucideIcons.dollarSign, Colors.green),
        _buildStatCard("Pedidos", _isLoading ? "..." : "${_stats['total_orders']}", LucideIcons.shoppingBag, Colors.blue),
        _buildStatCard("Entregas", _isLoading ? "..." : "${_stats['delivery_count'] ?? 0}", LucideIcons.bike, Colors.orange),
        _buildStatCard("Cozinha", _isLoading ? "..." : "${_stats['kitchen_count'] ?? 0}", LucideIcons.chefHat, Colors.redAccent),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AdminTheme.defaultPadding),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AdminTheme.defaultPadding * 0.75),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Icon(LucideIcons.moreVertical, color: Colors.white54, size: 16)
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.inter(fontSize: Responsive.isMobile(context)? 20 : 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Text(title, style: GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(AdminTheme.defaultPadding),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Pedidos Recentes", style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: AdminTheme.defaultPadding),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              columnSpacing: AdminTheme.defaultPadding,
              horizontalMargin: 0,
              headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.transparent),
              columns: const [
                DataColumn(label: Text("ID", style: TextStyle(color: Colors.white54))),
                DataColumn(label: Text("Data", style: TextStyle(color: Colors.white54))),
                DataColumn(label: Text("Tipo", style: TextStyle(color: Colors.white54))),
                DataColumn(label: Text("Status", style: TextStyle(color: Colors.white54))),
                DataColumn(label: Text("Valor", style: TextStyle(color: Colors.white54))),
              ],
              rows: _recentOrders.map((order) {
                final date = DateTime.parse(order['created_at']).toLocal();
                final formattedDate = DateFormat('HH:mm').format(date);
                final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

                return DataRow(
                  cells: [
                    DataCell(Text(order['id'].toString().substring(0, 6) + '...', style: const TextStyle(color: Colors.white))),
                    DataCell(Text(formattedDate, style: const TextStyle(color: Colors.white))),
                    DataCell(Text(order['order_type'] ?? 'Delivery', style: const TextStyle(color: Colors.white))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order['status'] ?? 'unknown',
                          style: TextStyle(color: _getStatusColor(order['status']), fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(Text(currencyFormat.format(order['total_price']), style: const TextStyle(color: Colors.white))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'delivered') return Colors.green;
    if (status == 'preparing') return Colors.blue;
    if (status == 'out_for_delivery') return Colors.orange;
    return Colors.redAccent;
  }
}

class _OrderDetailsChart extends StatelessWidget {
  const _OrderDetailsChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AdminTheme.defaultPadding),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Visão Geral", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: AdminTheme.defaultPadding),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 70,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(color: AdminTheme.primaryColor, value: 25, showTitle: false, radius: 25),
                      PieChartSectionData(color: const Color(0xFF26E5FF), value: 20, showTitle: false, radius: 22),
                      PieChartSectionData(color: const Color(0xFFFFCF26), value: 10, showTitle: false, radius: 19),
                      PieChartSectionData(color: const Color(0xFFEE2727), value: 15, showTitle: false, radius: 16),
                      PieChartSectionData(color: AdminTheme.primaryColor.withOpacity(0.1), value: 25, showTitle: false, radius: 13),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: AdminTheme.defaultPadding),
                      Text("29.1", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600, height: 0.5)),
                      const Text("Pedidos de Hoje", style: TextStyle(color: Colors.white54))
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AdminTheme.defaultPadding),
          _buildLegend(" Delivery", const Color(0xFF26E5FF), "12 Pedidos"),
          _buildLegend(" Restaurante", AdminTheme.primaryColor, "8 Pedidos"),
          _buildLegend(" Retirada", const Color(0xFFFFCF26), "5 Pedidos"),
          _buildLegend(" Cancelados", const Color(0xFFEE2727), "3 Pedidos"),
        ],
      ),
    );
  }

  Widget _buildLegend(String title, Color color, String amount) {
    return Container(
      margin: const EdgeInsets.only(top: AdminTheme.defaultPadding),
      padding: const EdgeInsets.all(AdminTheme.defaultPadding / 2),
      decoration: BoxDecoration(
        border: Border.all(width: 2, color: AdminTheme.primaryColor.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: AdminTheme.defaultPadding),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
          Text(amount, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
