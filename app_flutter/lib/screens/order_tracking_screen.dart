import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/order_service.dart';
import 'package:intl/intl.dart';

import '../services/app_translations.dart';
import '../utils/image_helper.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String? orderId;

  const OrderTrackingScreen({super.key, this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  String? _activeOrderId;
  String _currentStatus = 'pending'; // pending, prep, ready, completed
  RealtimeChannel? _subscription;
  final SupabaseClient _supabase = Supabase.instance.client;
  Stream<Map<String, dynamic>>? _orderStream;

  @override
  void initState() {
    super.initState();
    _activeOrderId = widget.orderId ?? OrderService().currentOrderId;

    // If we have an order ID, start tracking
    if (_activeOrderId != null) {
      _fetchInitialStatus();
      _subscribeToOrderUpdates();
    }

    // Listen to global order changes (if a new order is placed from Cart)
    OrderService().currentOrderIdNotifier.addListener(_onOrderServiceChange);
  }

  @override
  void dispose() {
    OrderService().currentOrderIdNotifier.removeListener(_onOrderServiceChange);
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _onOrderServiceChange() {
    final newId = OrderService().currentOrderId;
    if (newId != _activeOrderId) {
      setState(() {
        _activeOrderId = newId;
        _currentStatus = 'pending'; // Reset status for new order
      });
      _subscription?.unsubscribe();
      if (newId != null) {
        _fetchInitialStatus();
        // _subscribeToOrderUpdates(); // This might be replaced by the stream
      }
    }
  }

  Future<void> _fetchInitialStatus() async {
    if (_activeOrderId == null) return;
    print('Tracking Order ID: ${_activeOrderId}');
    _orderStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', _activeOrderId!)
        .map((event) => event.isNotEmpty ? event.first : {});

    // Listen to the stream to update _currentStatus
    _orderStream?.listen((data) {
      if (mounted && data.containsKey('status')) {
        setState(() {
          _currentStatus = data['status'];
        });
      }
    }).onError((error) {
      debugPrint('Error listening to order stream: $error');
    });
  }

  // This method might become redundant if _orderStream handles real-time updates
  void _subscribeToOrderUpdates() {
    if (_activeOrderId == null) return;
    print('Tracking Order: $_activeOrderId');
    _subscription = _supabase
        .channel('public:orders:$_activeOrderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _activeOrderId,
          ),
          callback: (payload) {
            print('Order Update: ${payload.newRecord}');
            final newStatus = payload.newRecord['status'];
            if (mounted) {
              setState(() {
                _currentStatus = newStatus;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Order Update: It is now ${newStatus.toUpperCase()}!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeOrderId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppTranslations.of(context, 'trackOrder'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.receipt, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(AppTranslations.of(context, 'noActiveOrders'),
                  style: const TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Fetch full order details including items for the card
    return StreamBuilder<Map<String, dynamic>>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar:
                AppBar(title: Text(AppTranslations.of(context, 'trackOrder'))),
            body: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE63946))),
          );
        }

        final orderData = snapshot.data!;
        final items = orderData['items'] as List<dynamic>? ?? [];
        final createdAt = DateTime.parse(orderData['created_at']).toLocal();
        final timeString = DateFormat('HH:mm').format(createdAt);
        final tableNumber = orderData['table_id'] != null
            ? 'Table ${orderData['table_id'].toString().substring(0, 2)}' // Mock table logic if needed, or fetch table
            : 'Takeaway';

        // Determine Color based on status
        Color statusColor = Colors.orange;
        String statusText = AppTranslations.of(context, 'statusPrep');
        if (_currentStatus == 'pending') {
          statusColor = Colors.red;
          statusText = AppTranslations.of(context, 'statusPending');
        } else if (_currentStatus == 'ready') {
          statusColor = Colors.green;
          statusText = AppTranslations.of(context, 'statusReady');
        } else if (_currentStatus == 'completed') {
          statusColor = Colors.grey;
          statusText = 'Completed';
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(AppTranslations.of(context, 'trackOrder')),
            // No back button needed if in bottom nav, but optional close logic kept
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${_activeOrderId!.substring(0, 8)}',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),

                // KDS Style Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a1a),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                          border: Border(
                              bottom: BorderSide(
                                  color: statusColor.withOpacity(0.5))),
                        ),
                        child: Row(
                          children: [
                            Text(
                                '${AppTranslations.of(context, 'orders')} #${_activeOrderId!.substring(0, 5)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.utensilsCrossed,
                                      size: 12, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(tableNumber,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(timeString,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),

                      // Items List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final product = item['product'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: ImageHelper.buildProductImage(
                                    product['name'],
                                    product['image_url'],
                                    width: 48,
                                    height: 48,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product['name'],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      if (item['notes'] != null &&
                                          item['notes'].toString().isNotEmpty)
                                        Text(item['notes'],
                                            style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${item['quantity']}x',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Status Footer using the "Button" look but static
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _currentStatus == 'ready'
                                  ? LucideIcons.checkCircle
                                  : _currentStatus == 'prep'
                                      ? LucideIcons.chefHat
                                      : LucideIcons.receipt,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper Helper to determine active color
  Color _getColor(String stepStatus) {
    // Current status hierarchy: pending < prep < ready
    const levels = {'pending': 1, 'prep': 2, 'ready': 3};

    final currentLevel = levels[_currentStatus] ?? 1;
    final stepLevel = levels[stepStatus] ?? 1;

    return stepLevel <= currentLevel
        ? const Color(0xFFE63946)
        : Theme.of(context).dividerColor;
  }

  Widget _buildStatusStep(String stepStatus, String label, IconData icon) {
    final color = _getColor(stepStatus);
    final isActive = color == const Color(0xFFE63946);
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            // Automatically adapt text color using Theme
            color: isActive
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(String prevStep) {
    return Container(
      margin: const EdgeInsets.only(left: 24), // Center with CircleAvatar
      height: 40,
      width: 4,
      color: _getColor(prevStep),
    );
  }
}
