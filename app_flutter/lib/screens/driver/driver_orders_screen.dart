import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../order_tracking_screen.dart';
import '../../constants/api.dart';
import 'package:http/http.dart' as http;
import '../../services/app_translations.dart';

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

  Future<void> _advanceDeliveryStatus(
      String deliveryId, String currentStatus, String orderId) async {
    String newStatus;
    // Cycle: assigned -> in_progress -> delivered
    if (currentStatus == 'assigned') {
      newStatus = 'in_progress';
    } else if (currentStatus == 'in_progress') {
      newStatus = 'delivered';
    } else {
      return; // Already delivered or unknown
    }

    try {
      // 1. Update Delivery Status
      await _supabase
          .from('deliveries')
          .update({'status': newStatus}).eq('id', deliveryId);

      // 2. If Delivered, Update Order Status (to remove from Active list)
      if (newStatus == 'delivered') {
        await _supabase
            .from('orders')
            .update({'status': 'delivered'}).eq('id', orderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Delivery Completed! 🎉'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Status updated: $newStatus 🚀'),
                backgroundColor: Colors.blue),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating status: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchOrderDetails(String orderId) async {
    try {
      // 1. Fetch Order
      final order =
          await _supabase.from('orders').select().eq('id', orderId).single();

      Map<String, dynamic>? profile;
      Map<String, dynamic>? establishment;

      // 2. Fetch Profile (Client)
      if (order['user_id'] != null) {
        try {
          profile = await _supabase
              .from('profiles')
              .select()
              .eq('id', order['user_id'])
              .single();
        } catch (e) {
          debugPrint('Profile fetch error: $e');
        }
      }

      // 3. Fetch Establishment
      if (order['establishment_id'] != null) {
        try {
          establishment = await _supabase
              .from('establishments')
              .select()
              .eq('id', order['establishment_id'])
              .single();
        } catch (e) {
          debugPrint('Establishment fetch error: $e');
        }
      }

      // Merge and return
      return {
        ...order,
        'profiles': profile,
        'establishments': establishment,
        'debug_error': null,
      };
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      return {'debug_error': e.toString()};
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
            const SizedBox(height: 8),

            // Real Address & Status Info
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchOrderDetails(orderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Loading details...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }

                final data = snapshot.data ?? {};
                final est = data['establishments'];
                final profile = data['profiles'];
                final orderStatus = data['status'] ?? 'pending'; // Order Status

                // Block 'Accept' until Kitchen marks as READY (user request)
                final canAccept =
                    orderStatus.toString().toLowerCase() == 'ready';

                // Debug Dropoff Reason
                String dropoffAddr = 'Unknown Dropoff';
                // ... (existing address logic) ...
                final snapshotAddr = data['delivery_address'];
                if (snapshotAddr != null &&
                    snapshotAddr.toString().isNotEmpty &&
                    snapshotAddr != 'Table Service' &&
                    snapshotAddr != 'Rua Exemplo 123') {
                  dropoffAddr = snapshotAddr;
                }
                // ... (rest of address logic maintained internally if not replaced, but here I am replacing the block) ...
                else if (data['user_id'] == null) {
                  dropoffAddr = 'Unknown Client (Guest)';
                } else if (profile != null) {
                  final street = profile['street'];
                  final city = profile['city'];
                  if (street != null) dropoffAddr = '$street, $city';
                }

                final pickupAddr = est != null
                    ? '${est['name']} - ${est['city'] ?? ''}'
                    : 'Unknown Pickup';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(LucideIcons.store,
                                size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text('Pickup: $pickupAddr',
                                    style: const TextStyle(fontSize: 12)))
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(LucideIcons.mapPin,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text('Drop-off: $dropoffAddr',
                                    style: const TextStyle(fontSize: 12)))
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: isMyDelivery
                          ? Row(
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
                                                  OrderTrackingScreen(
                                                      orderId: orderId)));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          delivery['status'] == 'in_progress'
                                              ? Colors.green
                                              : Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: Icon(
                                        delivery['status'] == 'in_progress'
                                            ? LucideIcons.checkCheck
                                            : LucideIcons.play),
                                    label: Text(
                                      delivery['status'] == 'in_progress'
                                          ? AppTranslations.of(
                                              context, 'finishDelivery')
                                          : AppTranslations.of(
                                              context, 'startDelivery'),
                                    ),
                                    onPressed: () => _advanceDeliveryStatus(
                                        delivery['id'],
                                        delivery['status'],
                                        orderId),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: canAccept
                                  ? ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12)),
                                      icon: const Icon(LucideIcons.check),
                                      label: const Text('ACCEPT DELIVERY'),
                                      onPressed: () =>
                                          _acceptDelivery(delivery['id']),
                                    )
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12)),
                                      icon: const Icon(LucideIcons.clock),
                                      label: const Text('WAITING FOR READY'),
                                      onPressed: null, // Disabled
                                    ),
                            ),
                    )
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
