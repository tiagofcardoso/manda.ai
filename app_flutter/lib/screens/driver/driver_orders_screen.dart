import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart'; // [NEW] Linker
import '../../constants/api.dart';
import 'package:http/http.dart' as http;
import '../../services/app_translations.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart'; // [NEW]

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

  String? _userRole;
  bool _roleLoading = true;
  List<Map<String, dynamic>> _drivers = [];

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

    _fetchRoleAndDrivers();
  }

  Future<void> _fetchRoleAndDrivers() async {
    final role = await AuthService().getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _roleLoading = false;
      });
    }

    if (role == 'admin' || role == 'manager') {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .order('full_name', ascending: true);
      if (mounted) {
        setState(() {
          _drivers = List<Map<String, dynamic>>.from(response);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _openMap(String address) async {
    // Encode the address for the query
    final query = Uri.encodeComponent(address);
    final googleMapsUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final wazeUrl = Uri.parse('https://waze.com/ul?q=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(wazeUrl)) {
        await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Try launching as a plain web URL (without checking specifically for app handler)
        // sometimes canLaunchUrl checks for specific app handler but launchUrl works for browser
        if (!await launchUrl(googleMapsUrl,
            mode: LaunchMode.externalApplication)) {
          throw 'Could not launch Maps';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening map: $e')),
        );
      }
    }
  }

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

  Future<void> _assignDriver(String deliveryId, String driverId) async {
    try {
      // Direct Admin Override: Assign driver and set status to 'assigned'
      await _supabase.from('deliveries').update({
        'driver_id': driverId,
        'status': 'assigned',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', deliveryId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Driver Assigned! 📋'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error assigning driver: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAssignmentDialog(String deliveryId) {
    if (_drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No drivers found!'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Driver'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _drivers.length,
            itemBuilder: (context, index) {
              final driver = _drivers[index];
              return ListTile(
                leading: const Icon(LucideIcons.user),
                title: Text(driver['full_name'] ?? 'Unknown'),
                subtitle: Text(driver['email'] ?? ''),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  _assignDriver(deliveryId, driver['id']);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
      } else if (newStatus == 'in_progress') {
        // [NEW] Update Order Status to 'on_way' so client sees status change
        await _supabase
            .from('orders')
            .update({'status': 'on_way'}).eq('id', orderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Status updated: $newStatus 🚀'),
                backgroundColor: Colors.blue),
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
      // [UPDATED] 1. Fetch Order + Items
      // We use Supabase efficient joining
      // Note: adjust syntax if "products" are not directly related to order_items in your Supabase setup
      // (but assuming they are based on main.py)
      final order = await _supabase
          .from('orders')
          .select('*, order_items(*, products(name))')
          .eq('id', orderId)
          .single();

      Map<String, dynamic>? profile;
      Map<String, dynamic>? establishment;

      // 2. Fetch Profile (Client) if needed
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
      drawer: const AppDrawer(), // [NEW] Side Menu
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        // automaticallyImplyLeading removed to allow Drawer icon
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
      elevation: 4,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchOrderDetails(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data ?? {};
          final est = data['establishments'];
          final profile = data['profiles'];
          final orderStatus = data['status'] ?? 'pending'; // Order Status
          final orderItems = data['order_items'] as List<dynamic>? ?? [];

          // Block 'Accept' until Kitchen marks as READY (user request)
          final canAccept = orderStatus.toString().toLowerCase() == 'ready';

          // Debug Dropoff Reason
          String dropoffAddr = 'Unknown Dropoff';
          // ... (existing address logic) ...
          final snapshotAddr = data['delivery_address'];
          if (snapshotAddr != null &&
              snapshotAddr.toString().isNotEmpty &&
              snapshotAddr != 'Table Service' &&
              snapshotAddr != 'Rua Exemplo 123') {
            dropoffAddr = snapshotAddr;
          } else if (data['user_id'] == null) {
            dropoffAddr = 'Unknown Client (Guest)';
          } else if (profile != null) {
            final street = profile['street'];
            final city = profile['city'];
            if (street != null) dropoffAddr = '$street, $city';
          }

          // Fallback if we still don't have address but delivery table has it
          if (dropoffAddr == 'Unknown Dropoff' && delivery['address'] != null) {
            dropoffAddr = delivery['address'];
          }

          final pickupAddr = est != null
              ? '${est['name']} - ${est['city'] ?? ''}'
              : 'Unknown Pickup';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${orderId.toString().substring(0, 8)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: isMyDelivery
                              ? Colors.blue[100]
                              : Colors.green[100],
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
                const Divider(),

                // [NEW] ITEMS LIST
                if (orderItems.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text('${orderItems.length} Items',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ),
                      ...orderItems.map((item) {
                        final productName =
                            item['products']?['name'] ?? 'Unknown Item';
                        final qty = item['quantity'] ?? 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Text('${qty}x ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              Expanded(child: Text(productName)),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(),
                    ],
                  ),

                // Addresses
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(LucideIcons.store,
                      size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Pickup",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(pickupAddr, style: const TextStyle(fontSize: 14)),
                    ],
                  ))
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(LucideIcons.mapPin,
                      size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Drop-off",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(dropoffAddr,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ))
                ]),

                const SizedBox(height: 16),

                // [NEW] External Map Button
                if (status == 'in_progress' || status == 'assigned')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.navigation, size: 18),
                      label: const Text('Open in Maps'),
                      onPressed: () => _openMap(dropoffAddr),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[800],
                          side: BorderSide(color: Colors.blue[200]!)),
                    ),
                  ),

                // Action Buttons
                isMyDelivery
                    ? (delivery['status'] == 'delivered'
                        ? const Center(
                            child: Text("Delivered",
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)))
                        : Row(
                            children: [
                              // Expanded(
                              //   child: OutlinedButton.icon(
                              //     icon: const Icon(LucideIcons.map),
                              //     label: const Text('Internal Map'),
                              //     onPressed: () {
                              //       Navigator.push(
                              //           context,
                              //           MaterialPageRoute(
                              //               builder: (_) =>
                              //                   OrderTrackingScreen(
                              //                       orderId: orderId)));
                              //     },
                              //   ),
                              // ),
                              // const SizedBox(width: 8),
                              // Removed Internal Map for now to declutter, using external
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          delivery['status'] == 'in_progress'
                                              ? Colors.green
                                              : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12)),
                                  icon: Icon(delivery['status'] == 'in_progress'
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
                          ))
                    : Column(
                        children: [
                          if (_roleLoading)
                            const SizedBox(
                                height: 48,
                                child:
                                    Center(child: CircularProgressIndicator()))
                          else if (_userRole == 'admin' ||
                              _userRole == 'manager')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  minimumSize: const Size(double.infinity, 48)),
                              icon: const Icon(LucideIcons.clipboardList),
                              label: const Text('ASSIGN DRIVER'),
                              onPressed: () =>
                                  _showAssignmentDialog(delivery['id']),
                            )
                          else
                            SizedBox(
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
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
