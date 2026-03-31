import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../services/settings_service.dart';
import '../../services/app_translations.dart';
import '../../constants/api.dart';
import '../../constants/admin_theme.dart';
import '../../widgets/admin/admin_scaffold.dart';
import '../../utils/responsive.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Stats map initialized with defaults
  Map<String, dynamic> _stats = {
    "total_revenue": 0.0,
    "total_orders": 0,
    "delivery_count": 0,
    "kitchen_count": 0,
  };

  // Advanced counters for the pie chart
  int _dineInCount = 0;
  int _takeawayCount = 0;
  int _cancelledCount = 0;
  int _dailyDeliveryCount = 0;

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
    SettingsService().loadCurrency(); // Ensure currency is always fresh for admin
    _fetchStats();
    _fetchOrderDistribution(); // Load real data for the PieChart
    _fetchRecentOrders();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchStats(silent: true);
        _fetchOrderDistribution();
        _fetchRecentOrders();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrderDistribution() async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

      // Ensure we query for the current establishment
      final profile = await supabase.from('profiles').select('establishment_id').eq('id', supabase.auth.currentUser!.id).single();
      final estId = profile['establishment_id'];
      if (estId == null) return;

      final response = await supabase
          .from('orders')
          .select('order_type, status, table_id')
          .eq('establishment_id', estId)
          .gte('created_at', startOfDay);

      int dineIn = 0;
      int delivery = 0;
      int takeaway = 0;
      int cancelled = 0;

      for (var order in response) {
        if (order['status'] == 'cancelled') {
          cancelled++;
          continue;
        }

        if (order['table_id'] != null || order['order_type'] == 'dine_in') {
          dineIn++;
        } else if (order['order_type'] == 'delivery') {
          delivery++;
        } else {
          takeaway++; // Assume default fallback is takeaway if no table
        }
      }

      if (mounted) {
        setState(() {
          _dineInCount = dineIn;
          _dailyDeliveryCount = delivery;
          _takeawayCount = takeaway;
          _cancelledCount = cancelled;
        });
      }
    } catch (e) {
      debugPrint("Error fetching order distribution: $e");
    }
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
      final profile = await supabase.from('profiles').select('establishment_id').eq('id', supabase.auth.currentUser!.id).single();
      final estId = profile['establishment_id'];

      if(estId == null) return;

      final response = await supabase
          .from('orders')
          .select('id, total_price, status, created_at, order_type, table_id')
          .eq('establishment_id', estId)
          .order('created_at', ascending: false)
          .limit(8); // Grab up to 8 for the new beautiful list

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
                        const SizedBox(height: AdminTheme.defaultPadding * 1.5),
                        _buildRecentOrdersCards(),
                        if (Responsive.isMobile(context))
                          const SizedBox(height: AdminTheme.defaultPadding * 1.5),
                        if (Responsive.isMobile(context))
                          _buildOrderDetailsChart(),
                      ],
                    ),
                  ),
                  if (!Responsive.isMobile(context))
                    const SizedBox(width: AdminTheme.defaultPadding * 1.5),
                  if (!Responsive.isMobile(context))
                    Expanded(
                      flex: 2,
                      child: _buildOrderDetailsChart(),
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
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService().currencyNotifier,
      builder: (context, currency, _) {
        final currencySymbol = SettingsService().getCurrencySymbol(currency);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
          crossAxisSpacing: AdminTheme.defaultPadding,
          mainAxisSpacing: AdminTheme.defaultPadding,
          childAspectRatio: 1.2,
          children: [
            _buildAnimatedStatCard(
               "Vendas (Hoje)", 
               _stats['total_revenue']?.toDouble() ?? 0.0, 
               isCurrency: true, 
               currencySymbol: currencySymbol,
               icon: LucideIcons.dollarSign, 
               cardGlowColor: const Color(0xFF11998e)
            ),
            _buildAnimatedStatCard(
               "Pedidos", 
               (_stats['total_orders'] ?? 0).toDouble(), 
               icon: LucideIcons.layers, 
               cardGlowColor: const Color(0xFF3b82f6)
            ),
            _buildAnimatedStatCard(
               "Entregas", 
               (_stats['delivery_count'] ?? 0).toDouble(), 
               icon: LucideIcons.bike, 
               cardGlowColor: const Color(0xFFf59e0b)
            ),
            _buildAnimatedStatCard(
               "Cozinha Ativa", 
               (_stats['kitchen_count'] ?? 0).toDouble(), 
               icon: LucideIcons.flame, 
               cardGlowColor: const Color(0xFFef4444)
            ),
          ],
        );
      },
    );
  }


  Widget _buildAnimatedStatCard(String title, double targetValue, {bool isCurrency = false, String currencySymbol = "", required IconData icon, required Color cardGlowColor}) {
    return Container(
      padding: const EdgeInsets.all(AdminTheme.defaultPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D), // Dark premium card
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardGlowColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardGlowColor.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                     colors: [cardGlowColor.withOpacity(0.3), cardGlowColor.withOpacity(0.1)],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Icon(icon, color: cardGlowColor, size: 22),
              ),
              Icon(LucideIcons.moreHorizontal, color: Colors.white.withOpacity(0.3), size: 18)
            ],
          ),
          
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: targetValue),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              String displayValue = isCurrency 
                  ? NumberFormat.currency(symbol: currencySymbol).format(value)
                  : value.toInt().toString();

              if (_isLoading) displayValue = "...";

              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayValue, 
                  style: GoogleFonts.outfit(
                     fontSize: Responsive.isMobile(context)? 24 : 28, 
                     fontWeight: FontWeight.bold, 
                     color: Colors.white,
                     letterSpacing: 1.0,
                  )
                ),
              );
            },
          ),
          Text(title, style: GoogleFonts.inter(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersCards() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // Background transparent because cards contain the bulk
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Atividade Recente", style: GoogleFonts.outfit(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/admin-orders'),
                  child: Text("Ver Tudo", style: GoogleFonts.inter(color: Colors.blueAccent)))
            ],
          ),
          const SizedBox(height: AdminTheme.defaultPadding),
          if (_isLoading) 
             const Center(child: CircularProgressIndicator())
          else if (_recentOrders.isEmpty)
             const Text("Nenhum pedido recente.", style: TextStyle(color: Colors.white54))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentOrders.length,
              itemBuilder: (context, index) {
                final order = _recentOrders[index];
                final date = DateTime.parse(order['created_at']).toLocal();
                final formattedDate = DateFormat('dd/MMM HH:mm').format(date);
                final curFormat = NumberFormat.currency(symbol: SettingsService().getCurrencySymbol(SettingsService().currency));
                
                final isTable = order['table_id'] != null;
                final typeText = isTable ? "Salão" : (order['order_type'] == 'delivery' ? "Delivery" : "Retirada");
                final typeIcon = isTable ? LucideIcons.armchair : (order['order_type'] == 'delivery' ? LucideIcons.bike : LucideIcons.shoppingBag);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03), // Glassmorphism base
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      // Status Indicator Line
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getStatusColor(order['status']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Icon Badge
                      Container(
                         padding: const EdgeInsets.all(10),
                         decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                         ),
                         child: Icon(typeIcon, color: Colors.white70, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('Pedido #${order['id'].toString().substring(0, 6)}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                             const SizedBox(height: 4),
                             Text("$typeText • $formattedDate", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                           ],
                        ),
                      ),
                      
                      // Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                           color: _getStatusColor(order['status']).withOpacity(0.15),
                           borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatStatus(order['status']),
                          style: GoogleFonts.inter(color: _getStatusColor(order['status']), fontSize: 11, fontWeight: FontWeight.bold)
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Price
                      Text(curFormat.format(order['total_price']), style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatStatus(String? status) {
     if (status == 'pending') return 'Pendente';
     if (status == 'prep') return 'Preparando';
     if (status == 'ready') return 'Pronto';
     if (status == 'out_for_delivery') return 'A Caminho';
     if (status == 'delivered') return 'Entregue';
     if (status == 'completed') return 'Finalizado';
     if (status == 'cancelled') return 'Cancelado';
     return status ?? 'Desconhecido';
  }

  Color _getStatusColor(String? status) {
    if (status == 'completed' || status == 'delivered') return const Color(0xFF10b981); // Emerald
    if (status == 'ready') return const Color(0xFF34d399); // Light Green
    if (status == 'prep' || status == 'preparing') return const Color(0xFF3b82f6); // Blue
    if (status == 'out_for_delivery' || status == 'on_way') return const Color(0xFFf59e0b); // Orange
    if (status == 'cancelled') return const Color(0xFFef4444); // Red
    return const Color(0xFF8b5cf6); // Purple for pending or unknown
  }

  Widget _buildOrderDetailsChart() {
    final int totalDynamicOrders = _dineInCount + _dailyDeliveryCount + _takeawayCount + _cancelledCount;

    return Container(
      padding: const EdgeInsets.all(AdminTheme.defaultPadding * 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Distribuição Hoje", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: AdminTheme.defaultPadding * 2),
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                if (totalDynamicOrders > 0)
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 65,
                      startDegreeOffset: -90,
                      sections: [
                        if (_dailyDeliveryCount > 0) PieChartSectionData(color: const Color(0xFF26E5FF), value: _dailyDeliveryCount.toDouble(), showTitle: false, radius: 25),
                        if (_dineInCount > 0) PieChartSectionData(color: const Color(0xFF3b82f6), value: _dineInCount.toDouble(), showTitle: false, radius: 22),
                        if (_takeawayCount > 0) PieChartSectionData(color: const Color(0xFFFFCF26), value: _takeawayCount.toDouble(), showTitle: false, radius: 19),
                        if (_cancelledCount > 0) PieChartSectionData(color: const Color(0xFFEE2727), value: _cancelledCount.toDouble(), showTitle: false, radius: 16),
                      ],
                    ),
                  )
                else
                  Center(child: Text("Sem Dados Hoje", style: GoogleFonts.inter(color: Colors.white54))),
                
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                         tween: Tween<double>(begin: 0, end: totalDynamicOrders.toDouble()),
                         duration: const Duration(milliseconds: 1500),
                         builder: (context, val, child) {
                            return Text(
                               val.toInt().toString(), 
                               style: GoogleFonts.outfit(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold, height: 1.0)
                            );
                         }
                      ),
                      Text("Pedidos", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13))
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AdminTheme.defaultPadding * 2),
          _buildGraphLegend(" Delivery", const Color(0xFF26E5FF), "$_dailyDeliveryCount"),
          _buildGraphLegend(" Salão / Mesa", const Color(0xFF3b82f6), "$_dineInCount"),
          _buildGraphLegend(" Retirada", const Color(0xFFFFCF26), "$_takeawayCount"),
          _buildGraphLegend(" Cancelados", const Color(0xFFEE2727), "$_cancelledCount"),
        ],
      ),
    );
  }

  Widget _buildGraphLegend(String title, Color color, String amount) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)])),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500))),
          Text(amount, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
