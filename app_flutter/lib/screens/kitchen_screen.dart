import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  // Helper for Backend URL
  String get _baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  void _setupRealtimeSubscription() {
    print("Kitchen: Subscribing to Realtime...");
    // Listen for ANY change (INSERT, UPDATE) on the 'orders' table
    _subscription = _supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            print("Kitchen: Change detected! Refreshing...");
            // When a change happens, refresh the list via Backend
            if (mounted) {
              setState(() {});

              if (payload.eventType == PostgresChangeEvent.insert) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔔 New Order Received!')),
                );
              }
            }
          },
        )
        .subscribe();
  }

  // Fetch active orders (pending, prep) via BACKEND API (Bypasses RLS)
  Future<List<Map<String, dynamic>>> _fetchActiveOrders() async {
    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('Kitchen: No Active Session!');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/kds/orders'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        debugPrint(
            'Error fetching orders: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Not Authenticated!')),
          );
        }
        return;
      }

      // Use Backend API for updates too
      final response = await http.patch(
        Uri.parse('$_baseUrl/kds/orders/$orderId'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({"status": newStatus}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order updated to $newStatus!')),
          );
          // Subscription will trigger refresh, but we can optimistically fetch too
          setState(() {});
        }
      } else {
        throw Exception('Failed: ${response.body}');
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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        setState(() {}); // Rebuild to show orders
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Login Failed: ${e.message}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = _supabase.auth.currentSession;

    // Show Login Screen if no session
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Kitchen Login'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white),
        backgroundColor: const Color(0xFF1a1a1a),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white)),
                        prefixIcon: Icon(Icons.email, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white)),
                        prefixIcon: Icon(Icons.lock, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16)),
                        onPressed: _isLoading ? null : _signIn,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('LOGIN TO KITCHEN'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display (Hybrid 🔌)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          )
        ],
      ),
      backgroundColor: const Color(0xFF1a1a1a),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchActiveOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white)));
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All good! No active orders.',
                      style: TextStyle(color: Colors.white70, fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderCard(
                order: order,
                onAdvance: () {
                  final currentStatus = order['status'];
                  final nextStatus =
                      currentStatus == 'pending' ? 'prep' : 'ready';
                  _updateStatus(order['id'], nextStatus);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAdvance;

  const _OrderCard({required this.order, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final DateTime createdAt = DateTime.parse(order['created_at']).toLocal();
    final timeStr = DateFormat('HH:mm').format(createdAt);

    final status = order['status'].toString().toUpperCase();
    final isPending = status == 'PENDING';
    final cardColor = isPending ? Colors.orange.shade900 : Colors.blue.shade900;

    final items = List<Map<String, dynamic>>.from(order['order_items'] ?? []);

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cardColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['id'].toString().substring(0, 6)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final product = item['products'];
                final prodName = product != null ? product['name'] : 'Unknown';
                final quantity = item['quantity'];
                final notes = item['notes'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${quantity}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prodName,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16)),
                            if (notes != null && notes.toString().isNotEmpty)
                              Text('Note: $notes',
                                  style: TextStyle(
                                      color: Colors.red[200],
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAdvance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(isPending ? Icons.restaurant : Icons.check),
                label: Text(
                  isPending ? 'START PREPARING' : 'MARK AS READY',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
