import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/order_service.dart';
import '../services/app_translations.dart';

class GuestTableOrderScreen extends StatefulWidget {
  const GuestTableOrderScreen({super.key});

  @override
  State<GuestTableOrderScreen> createState() => _GuestTableOrderScreenState();
}

class _GuestTableOrderScreenState extends State<GuestTableOrderScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _activeOrder;
  bool _isLoading = true;
  Stream<Map<String, dynamic>>? _orderStream;

  @override
  void initState() {
    super.initState();
    _fetchActiveTableOrder();
  }

  Future<void> _fetchActiveTableOrder() async {
    final orderId = OrderService().currentOrderId;

    if (orderId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Initial fetch
      final response = await _supabase
          .from('orders')
          .select(
              '*, tables(table_number), order_items(quantity, products(name, price))')
          .eq('id', orderId)
          .single();

      if (mounted) {
        setState(() {
          _activeOrder = response;
          _isLoading = false;
        });
      }

      // Set up real-time stream for status updates
      _orderStream = _supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('id', orderId)
          .map((event) => event.isNotEmpty ? event.first : {});

      _orderStream?.listen((data) {
        if (mounted && data.containsKey('status')) {
          final newStatus = data['status'];
          setState(() {
            _activeOrder = {...?_activeOrder, ...data};
          });

          // Auto-clear if order is ready/served (table orders don't have "delivered")
          if (newStatus == 'ready' || newStatus == 'served') {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                OrderService().clearOrder();
                setState(() => _activeOrder = null);
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
      case 'prep':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'delivered':
      case 'served':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.of(context, 'tableOrder')),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor),
          onPressed: () {
            // Since Drawer uses pushReplacement, we must explicitly go back to MainScreen
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeOrder == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.utensilsCrossed,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        AppTranslations.of(context, 'noActiveOrders'),
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(LucideIcons.utensilsCrossed,
                                size: 48, color: const Color(0xFFE63946)),
                            const SizedBox(height: 16),
                            Text(
                              _activeOrder!['tables'] != null
                                  ? "${AppTranslations.of(context, 'table')} ${_activeOrder!['tables']['table_number']}"
                                  : AppTranslations.of(context, 'tableOrder'),
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "#${_activeOrder!['id'].toString().substring(0, 8)}",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                        _activeOrder!['status'] ?? 'pending')
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (_activeOrder!['status'] ?? 'PENDING')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(
                                      _activeOrder!['status'] ?? 'pending'),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Items
                      Expanded(
                        child: ListView.builder(
                          itemCount:
                              (_activeOrder!['order_items'] as List).length,
                          itemBuilder: (context, index) {
                            final item = _activeOrder!['order_items'][index];
                            final qty = item['quantity'];
                            final pName =
                                item['products']?['name'] ?? 'Unknown Item';

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${qty}x",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      pName,
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
