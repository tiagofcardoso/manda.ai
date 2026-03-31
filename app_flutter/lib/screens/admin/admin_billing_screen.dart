import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../widgets/admin/admin_scaffold.dart';
import '../../services/settings_service.dart';
import '../../services/printer_service.dart';

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, Map<String, dynamic>> _activeTables = {};
  String? _establishmentName;

  @override
  void initState() {
    super.initState();
    _fetchEstablishment();
    _loadActiveSessions();
  }

  Future<void> _fetchEstablishment() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile = await _supabase.from('profiles').select('establishments(name)').eq('id', user.id).single();
        _establishmentName = profile['establishments']?['name'] ?? 'Manda.AI';
      } catch (e) {
        debugPrint('Error fetching establishment: $e');
      }
    }
  }

  Future<void> _loadActiveSessions() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('orders')
          .select('*, tables(table_number), order_items(*, products(*))')
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .not('table_id', 'is', 'null');
      
      final Map<String, Map<String, dynamic>> grouped = {};
      
      for (var order in res) {
        final String tableId = order['table_id'].toString();
        final String tableNumber = order['tables'] != null 
            ? order['tables']['table_number'].toString() 
            : 'Desconhecida';
            
        final double orderTotal = double.tryParse((order['total_amount'] ?? order['total_price'] ?? 0).toString()) ?? 0.0;
        
        if (!grouped.containsKey(tableId)) {
          grouped[tableId] = {
            'table_id': tableId,
            'table_number': tableNumber,
            'orders': <Map<String, dynamic>>[],
            'subtotal': 0.0,
          };
        }
        
        grouped[tableId]!['orders'].add(order);
        grouped[tableId]!['subtotal'] += orderTotal;
      }

      if (mounted) {
        setState(() {
          _activeTables = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading active billing sessions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printBill(Map<String, dynamic> tableSession) async {
    try {
      await PrinterService().printTableBill(
        tableSession['orders'], 
        tableSession['table_number'].toString(), 
        _establishmentName ?? 'Manda.AI', 
        tableSession['subtotal']
      );
    } catch (e) {
      debugPrint('Error printing bill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pop-up bloqueado pelo navegador? Tente de novo!')),
        );
      }
    }
  }

  Future<void> _closeTable(Map<String, dynamic> tableSession) async {
    setState(() => _isLoading = true);
    try {
      final orders = tableSession['orders'] as List<dynamic>;
      for (var order in orders) {
        await _supabase.from('orders').update({'status': 'completed'}).eq('id', order['id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesa fechada e faturada com sucesso!'), backgroundColor: Colors.green),
        );
        _loadActiveSessions(); // Reload grid after closing
      }
    } catch (e) {
      debugPrint('Error closing table: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fechar mesa: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Fechamento (Mesas)',
      activeRoute: '/admin-billing',
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.refreshCw),
          tooltip: 'Atualizar Mesas',
          onPressed: _loadActiveSessions,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeTables.isEmpty
              ? _buildEmptyState()
              : _buildTablesGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.wallet, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Nenhuma mesa consumindo agora',
            style: GoogleFonts.outfit(fontSize: 20, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Todos os clientes atrelados a mesas já finalizaram seus pedidos.',
            style: GoogleFonts.outfit(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTablesGrid() {
    final currSymbol = SettingsService().getCurrencySymbol(SettingsService().currency);
    final currencyFormat = NumberFormat.currency(symbol: currSymbol);
    final tables = _activeTables.values.toList();

    return RefreshIndicator(
      onRefresh: _loadActiveSessions,
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 350,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        itemCount: tables.length,
        itemBuilder: (context, index) {
          final table = tables[index];
          final ordersCount = (table['orders'] as List).length;
          final subtotal = table['subtotal'] as double;

          return Card(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).cardColor,
                    Theme.of(context).scaffoldBackgroundColor,
                  ]
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Header
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               color: const Color(0xFFE63946).withOpacity(0.15),
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: const Icon(LucideIcons.utensilsCrossed, color: Color(0xFFE63946), size: 24),
                           ),
                           const SizedBox(width: 12),
                           Text(
                             'Mesa ${table['table_number']}',
                             style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     ],
                   ),
                   const Spacer(),
                   
                   // Stats summary
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.04),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('$ordersCount ${ordersCount == 1 ? 'pedido em aberto' : 'pedidos em aberto'}', style: TextStyle(color: Colors.white70)),
                         const SizedBox(height: 8),
                         Text(
                           currencyFormat.format(subtotal), 
                           style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFFE63946))
                         ),
                         const SizedBox(height: 4),
                         Text('+ 10% Serviço: ${currencyFormat.format(subtotal * 0.10)}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                       ],
                     ),
                   ),
                   const Spacer(),
                   
                   // Action Buttons
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       OutlinedButton.icon(
                         icon: const Icon(LucideIcons.printer, size: 18),
                         label: const Text('Imprimir Conta'),
                         style: OutlinedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 14),
                           foregroundColor: Colors.white,
                           side: const BorderSide(color: Colors.white24),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                         ),
                         onPressed: () => _printBill(table),
                       ),
                       const SizedBox(height: 12),
                       ElevatedButton.icon(
                         icon: const Icon(LucideIcons.checkCircle, size: 18),
                         label: const Text('Receber e Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
                         style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 14),
                           backgroundColor: const Color(0xFFE63946),
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                         ),
                         onPressed: () {
                           showDialog(
                             context: context,
                             builder: (ctx) => AlertDialog(
                               title: const Text('Confirmar Recebimento?'),
                               content: Text('A mesa ${table['table_number']} já efetuou o pagamento do ticket? Isso encerrará todos os $ordersCount pedidos.'),
                               actions: [
                                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                 ElevatedButton(
                                   style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
                                   onPressed: () {
                                     Navigator.pop(ctx);
                                     _closeTable(table);
                                   }, 
                                   child: const Text('Sim, fechar mesa', style: TextStyle(color: Colors.white))
                                 ),
                               ]
                             )
                           );
                         },
                       ),
                     ],
                   ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
