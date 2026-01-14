import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/order_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String? orderId;

  const OrderTrackingScreen({super.key, this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _subscription;
  String _currentStatus = 'pending';
  String? _activeOrderId;

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
        _subscribeToOrderUpdates();
      }
    }
  }

  Future<void> _fetchInitialStatus() async {
    if (_activeOrderId == null) return;
    try {
      final data = await _supabase
          .from('orders')
          .select('status')
          .eq('id', _activeOrderId!)
          .single();
      if (mounted) {
        setState(() {
          _currentStatus = data['status'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching status: $e');
    }
  }

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
        appBar: AppBar(title: const Text('Track Order')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('No active orders',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        // No back button needed if in bottom nav, but optional close logic kept
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Order #${_activeOrderId!.substring(0, 8)}',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            _buildStatusStep('pending', 'Order Received', Icons.receipt_long),
            _buildConnector('pending'),
            _buildStatusStep('prep', 'Preparing', Icons.outdoor_grill),
            _buildConnector('prep'),
            _buildStatusStep(
                'ready', 'Ready to Pickup', Icons.check_circle_outline),
            const Spacer(),
            if (_currentStatus == 'ready')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.thumb_up, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Your food is ready! Please collect it at the counter.',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
          ],
        ),
      ),
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
