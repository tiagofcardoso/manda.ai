import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'package:intl/intl.dart';

import '../services/app_translations.dart';
import '../utils/image_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart'; // Added for GPS
import 'dart:async';

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
  StreamSubscription<Position>?
      _positionStreamSubscription; // For broadcasting location

  // Map Variables
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  LatLng?
      _destinationLocation; // Mock for now, or fetch from order if address exists
  // Mock Shop Location (e.g., Lisbon Center)
  LatLng _shopLocation =
      const LatLng(38.7223, -9.1393); // Default Lisbon Center
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _activeOrderId = widget.orderId ?? OrderService().currentOrderId;

    // If we have an order ID, start tracking
    // STRICT CHECK: Only load if user is authenticated AND a client (or explicitly passed)
    // Actually, just checking if user is NOT guest is a good start, but user specifically asked for "only client".
    // However, AuthService().getUserRole() is async.
    // Let's just check if user is null first. Guest should definitely see nothing.

    // Better logic:
    // If widget.orderId is provided (e.g. deep link), maybe allow? But safer to restrict.
    // If OrderService().currentOrderId is used, definitely restrict.

    // We will check role asynchronously in _checkAccess()
    _checkAccessAndLoad();

    // Listen to global order changes (if a new order is placed from Cart)
    OrderService().currentOrderIdNotifier.addListener(_onOrderServiceChange);
  }

  Future<void> _checkAccessAndLoad() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _activeOrderId = null);
      return;
    }

    // If no ID passed, try to restore active session from DB
    if (_activeOrderId == null) {
      await _restoreActiveSession(user.id);
    }

    if (_activeOrderId == null) {
      return; // Still no order
    }

    // Check Role
    final role = await AuthService().getUserRole();
    if (role != 'client' && role != 'driver') {
      // Admin - Do not load cached order (Drivers allowed if orderId is passed)
      // Note: We might want to verify the driver is assigned to THIS order, but for now we trust `driver_orders_screen` passed a valid ID.
      if (mounted) setState(() => _activeOrderId = null);
      return;
    }

    // If Client or Driver, proceed
    final orderId = widget.orderId ?? OrderService().currentOrderId;
    if (orderId != null) {
      if (mounted) setState(() => _activeOrderId = orderId);
      _fetchInitialStatus();
      _subscribeToOrderUpdates();

      // Fetch Locations for Map
      _fetchShopLocation(); // [NEW] Fetch dynamic shop loc
      _fetchDropoffLocation();

      // If Driver, START BROADCASTING LOCATION
      if (role == 'driver') {
        _startLocationBroadcasting();
      }
    }
  }

  Future<void> _restoreActiveSession(String userId) async {
    try {
      // Find latest order that is NOT completed/cancelled
      final response = await _supabase
          .from('orders')
          .select('id')
          .eq('user_id', userId)
          .neq('status', 'delivered')
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _activeOrderId = response['id'];
        });

        // Load Details for this restored order
        _fetchInitialStatus();
        _subscribeToOrderUpdates();
        _fetchShopLocation();
        _fetchDropoffLocation();
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
  }

  Future<void> _fetchDropoffLocation() async {
    if (_activeOrderId == null) return;
    try {
      final order = await _supabase
          .from('orders')
          .select('user_id, delivery_address')
          .eq('id', _activeOrderId!)
          .single();

      String? addressQuery;

      // 1. Try explicit address
      if (order['delivery_address'] != null &&
          order['delivery_address'].toString().isNotEmpty &&
          order['delivery_address'] != 'Table Service') {
        addressQuery = order['delivery_address'];
      }
      // 2. Fallback to Profile
      else if (order['user_id'] != null) {
        final profile = await _supabase
            .from('profiles')
            .select('street, city, country')
            .eq('id', order['user_id'])
            .single();

        final street = profile['street'];
        final city = profile['city'];
        if (street != null && city != null) {
          addressQuery = '$street, $city';
        }
      }

      if (addressQuery != null) {
        // Geocode via Nominatim (OpenStreetMap)
        // Rate Limit: 1 request per second. User-Agent required.
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$addressQuery&format=json&limit=1');
        final response = await http
            .get(url, headers: {'User-Agent': 'Manda.AI_DriverApp/1.0'});

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            final lat = double.parse(data[0]['lat']);
            final lon = double.parse(data[0]['lon']);
            if (mounted) {
              setState(() {
                _destinationLocation = LatLng(lat, lon);
              });
              // Auto-fit Map after getting dropoff
              _fitMapBounds();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching dropoff location: $e');
    }
  }

  Future<void> _fetchShopLocation() async {
    if (_activeOrderId == null) return;
    try {
      // 1. Get Establishment ID from Order
      final order = await _supabase
          .from('orders')
          .select('establishment_id')
          .eq('id', _activeOrderId!)
          .single();

      final estId = order['establishment_id'];
      if (estId == null) return;

      // 2. Fetch Establishment Address
      final est = await _supabase
          .from('establishments')
          .select('street, city, country') // Removed postcode
          .eq('id', estId)
          .single();

      final street = est['street'];
      final city = est['city'];

      if (street != null && city != null) {
        // 3. Geocode
        final addressQuery =
            '$street, $city, Portugal'; // Assume Portugal for now
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$addressQuery&format=json&limit=1');
        final response = await http
            .get(url, headers: {'User-Agent': 'Manda.AI_DriverApp/1.0'});

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            final lat = double.parse(data[0]['lat']);
            final lon = double.parse(data[0]['lon']);
            if (mounted) {
              setState(() {
                _shopLocation = LatLng(lat, lon);
              });
              // Auto-fit will be called by other location updates or map ready
              _fitMapBounds();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching shop location: $e');
    }
  }

  // === DRIVER: GPS BROADCASTING ===
  Future<void> _startLocationBroadcasting() async {
    // 1. Check Permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
          'Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    // 2. Start Stream
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _updateDriverLocationInDB(position.latitude, position.longitude);
    });
  }

  Future<void> _updateDriverLocationInDB(double lat, double lng) async {
    if (_activeOrderId == null) return;
    try {
      await _supabase.from('deliveries').update({
        'current_lat': lat,
        'current_lng': lng,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('order_id', _activeOrderId!);

      // Optimistic update locally? No, we listen to the stream anyway.
    } catch (e) {
      debugPrint('Error broadcasting location: $e');
    }
  }

  void _fitMapBounds() {
    if (!_isMapReady) return;

    final points = <LatLng>[_shopLocation]; // Always include shop
    if (_driverLocation != null) points.add(_driverLocation!);
    if (_destinationLocation != null) points.add(_destinationLocation!);

    // SAFETY CHECK: Remove invalid/NaN points just in case
    points.removeWhere((p) => p.latitude.isNaN || p.longitude.isNaN);
    if (points.isEmpty) return;

    // Check if we effectively have only 1 unique location
    // (FlutterMap can crash if trying to fit bounds of size 0 with padding)
    final first = points.first;
    bool allSame = points.every((p) =>
        (p.latitude - first.latitude).abs() < 0.0001 &&
        (p.longitude - first.longitude).abs() < 0.0001);

    if (points.length > 1 && !allSame) {
      try {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(40), // Reduced slightly
            maxZoom: 18, // Prevent extreme zooming
          ),
        );
      } catch (e) {
        debugPrint('Error fitting map bounds: $e');
        // Fallback
        _mapController.move(first, 15);
      }
    } else {
      // Just center on the single/common point
      _mapController.move(first, 15);
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
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

  // Subscribe to DELIVERY updates for this order
  void _subscribeToOrderUpdates() {
    if (_activeOrderId == null) return;

    // 1. Order Status Updates
    _supabase
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
            final newStatus = payload.newRecord['status'];
            if (mounted) setState(() => _currentStatus = newStatus);
          },
        )
        .subscribe();

    // 2. Delivery Location Updates (listen to DB changes)
    _supabase
        .channel('public:deliveries:$_activeOrderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'deliveries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: _activeOrderId,
          ),
          callback: (payload) {
            final newLat = payload.newRecord['current_lat'];
            final newLng = payload.newRecord['current_lng'];
            if (newLat != null && newLng != null) {
              final lat = (newLat as num).toDouble();
              final lng = (newLng as num).toDouble();
              if (!lat.isNaN && !lng.isNaN) {
                if (mounted) {
                  setState(() {
                    _driverLocation = LatLng(lat, lng);
                  });
                  // Auto-Pan to keep driver in view (optional, or just fit bounds)
                  // For now, let's fit bounds only if users haven't interacted much,
                  // but simpler to just fit bounds on major updates.
                  // actually, continuous fitting might be annoying if user is panning.
                  // Let's just fit ONCE initially or when significant change happens?
                  // Re-fitting on every move is great for "Tracking Mode".
                  _fitMapBounds();
                }
              }
            }
          },
        )
        .subscribe();

    // Also fetch initial delivery location from DB if exists
    _fetchInitialDeliveryLoc();
  }

  Future<void> _fetchInitialDeliveryLoc() async {
    try {
      final data = await _supabase
          .from('deliveries')
          .select()
          .eq('order_id', _activeOrderId!)
          .maybeSingle();

      if (data != null && data['current_lat'] != null) {
        if (mounted) {
          setState(() {
            _driverLocation = LatLng(data['current_lat'], data['current_lng']);
          });
          // Fit bounds after initial load
          _fitMapBounds();
        }
      }
    } catch (e) {
      debugPrint('Error fetching delivery loc: $e');
    }
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
                      // === MAP SECTION (Only for Delivery) ===
                      if (orderData['table_id'] == null)
                        SizedBox(
                          height: 250,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter:
                                        _shopLocation, // Start at shop
                                    initialZoom: 14.5,
                                    onMapReady: () {
                                      _isMapReady = true;
                                      _fitMapBounds();
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.manda.client',
                                      tileProvider:
                                          CancellableNetworkTileProvider(),
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        // Shop Marker
                                        Marker(
                                          point: _shopLocation,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(LucideIcons.store,
                                              color: Colors.blue, size: 30),
                                        ),
                                        // Driver Marker (Dynamic)
                                        if (_driverLocation != null)
                                          Marker(
                                            point: _driverLocation!,
                                            width: 50,
                                            height: 50,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        blurRadius: 5,
                                                        color: Colors.black26)
                                                  ]),
                                              child: const Icon(
                                                  LucideIcons.bike,
                                                  color: Colors.red,
                                                  size: 30),
                                            ),
                                          ),
                                        // Dropoff Marker
                                        if (_destinationLocation != null)
                                          Marker(
                                            point: _destinationLocation!,
                                            width: 40,
                                            height: 40,
                                            child: const Icon(
                                                LucideIcons.mapPin,
                                                color: Colors.orange,
                                                size: 40),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Overlay Status
                                Positioned(
                                  bottom: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        if (_driverLocation == null)
                                          const Text('Waiting for driver...',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12))
                                        else
                                          const Text('Driver on the way! 🛵',
                                              style: TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold))
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        )
                      else
                        // === TABLE HEADER (No Map) ===
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12))),
                          child: Column(children: [
                            const Icon(LucideIcons.armchair,
                                size: 48, color: Colors.white54),
                            const SizedBox(height: 8),
                            Text('Dine-In • Table ${orderData['table_id']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold))
                          ]),
                        ),
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: const BorderRadius.only(
                              // topLeft: Radius.circular(11), // Removed as map is top now
                              // topRight: Radius.circular(11),
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
