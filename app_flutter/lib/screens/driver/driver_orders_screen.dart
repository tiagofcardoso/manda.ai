import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../order_tracking_screen.dart';
import '../../constants/api.dart';
import 'package:http/http.dart' as http;

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _myDeliveriesStream;
  late Stream<List<Map<String, dynamic>>> _poolStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final userId = _supabase.auth.currentUser?.id;

    // 1. Stream My Deliveries
    if (userId != null) {
      _myDeliveriesStream = _supabase
          .from('deliveries')
          .stream(primaryKey: ['id'])
          .eq('driver_id', userId)
          .order('updated_at', ascending: false);
    } else {
      _myDeliveriesStream = const Stream.empty();
    }

    // 2. Stream Open Deliveries (Pool)
    _poolStream = _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('status', 'open')
        .order('updated_at', ascending: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Methods restored for Actions

  Future<void> _acceptDelivery(String deliveryId) async {
    try {
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/driver/deliveries/$deliveryId/accept');
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(url, headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Order Accepted! 🚴'),
                backgroundColor: Colors.green),
          );
          // Stream will auto-update!
          _tabController.animateTo(0); // Switch to My Deliveries
        }
      } else {
        throw Exception('Failed to accept: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error accepting order: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startSimulation(String orderId) async {
    try {
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/admin/deliveries/simulate/$orderId');
      final response = await http.post(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Simulation Started! 🚀'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to start');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error starting simulation: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'My Deliveries', icon: Icon(LucideIcons.bike)),
            Tab(text: 'New Requests (Pool)', icon: Icon(LucideIcons.list)),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyDeliveriesList(),
          _buildPoolList(),
        ],
      ),
    );
  }

  Widget _buildMyDeliveriesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myDeliveriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final deliveries = snapshot.data ?? [];

        if (deliveries.isEmpty) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(LucideIcons.packageCheck, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No active deliveries.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final delivery = deliveries[index];
            return _buildDeliveryCard(delivery, isMyDelivery: true);
          },
        );
      },
    );
  }

  Widget _buildPoolList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _poolStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final deliveries = snapshot.data ?? [];

        if (deliveries.isEmpty) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(LucideIcons.checkCircle, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No new requests available.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final delivery = deliveries[index];
            return _buildDeliveryCard(delivery, isMyDelivery: false);
          },
        );
      },
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery,
      {required bool isMyDelivery}) {
    final orderId = delivery['order_id'];
    final status = delivery['status'];
    // final orderTotal = delivery['order']?['total_amount'] ?? 0.0; // If joined

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${orderId.toString().substring(0, 8)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                          isMyDelivery ? Colors.blue[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: isMyDelivery
                              ? Colors.blue[800]
                              : Colors.green[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 8),
            // Mock Address Info
            const Row(
              children: [
                Icon(LucideIcons.mapPin, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('Delivery to: Rua Principal, 123',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            if (isMyDelivery)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.map),
                      label: const Text('Map'),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    OrderTrackingScreen(orderId: orderId)));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white),
                      icon: const Icon(LucideIcons.play),
                      label: const Text('Simulate'),
                      onPressed: () => _startSimulation(orderId),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(LucideIcons.check),
                  label: const Text('ACCEPT DELIVERY'),
                  onPressed: () => _acceptDelivery(delivery['id']),
                ),
              )
          ],
        ),
      ),
    );
  }
}
