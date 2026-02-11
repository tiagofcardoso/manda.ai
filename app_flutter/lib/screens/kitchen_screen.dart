import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:async';
import '../services/app_translations.dart';
import '../utils/image_helper.dart';
import '../constants/api.dart';

import '../widgets/admin/admin_scaffold.dart';
import '../utils/responsive.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _subscription;
  final _audioPlayer = AudioPlayer();
  bool _isSoundEnabled = true;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
    _loadOrders(); // Initial Load

    // Polling fallback to ensure reliability (every 1s)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _loadOrders(silent: true);
    });

    // Listen for Auth Changes to re-subscribe if needed
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        print("Kitchen: Auth changed (Signed In), re-subscribing...");
        _subscription?.unsubscribe();
        _setupRealtimeSubscription();
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _refreshTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Helper for Backend URL
  String get _baseUrl {
    return ApiConstants.baseUrl;
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
              _loadOrders(silent: true); // Refresh data

              if (payload.eventType == PostgresChangeEvent.insert) {
                if (_isSoundEnabled) {
                  _playNotificationSound();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          AppTranslations.of(context, 'newOrderNotification'))),
                );
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _playNotificationSound() async {
    try {
      final langCode = Localizations.localeOf(context).languageCode;
      final soundFile = langCode == 'pt'
          ? 'sounds/notification_portugues.mp3'
          : 'sounds/notification_english.mp3';

      // Plays localized sound
      await _audioPlayer.play(AssetSource(soundFile), volume: 1.0);
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  // Fetch active orders (pending, prep) via BACKEND API (Bypasses RLS)
  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoadingOrders = true);

    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('Kitchen: No Active Session!');
        if (mounted) setState(() => _isLoadingOrders = false);
        return;
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
        final newOrders = List<Map<String, dynamic>>.from(data);

        // Play sound if new orders detected during silent refresh
        if (silent && mounted && _isSoundEnabled) {
          final oldIds = _orders.map((e) => e['id']).toSet();
          final hasNew = newOrders.any((o) => !oldIds.contains(o['id']));
          if (hasNew) {
            _playNotificationSound();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      AppTranslations.of(context, 'newOrderNotification'))),
            );
          }
        }

        if (mounted) {
          setState(() {
            _orders = newOrders;
            _isLoadingOrders = false;
          });
        }
      } else {
        debugPrint(
            'Error fetching orders: ${response.statusCode} ${response.body}');
        if (mounted) setState(() => _isLoadingOrders = false);
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppTranslations.of(context, 'errorNotAuthenticated'))),
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
            SnackBar(
                content: Text(
                    '${AppTranslations.of(context, 'orderUpdated')} $newStatus!')),
          );
          // Refresh list immediately
          _loadOrders(silent: true);
        }
      } else {
        throw Exception('Failed: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppTranslations.of(context, 'errorUpdatingStatus')} $e'),
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
        _loadOrders(); // Load orders after sign in
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppTranslations.of(context, 'loginFailed')} ${e.message}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppTranslations.of(context, 'generalError')} $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      setState(() {
        _orders = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _supabase.auth.currentSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    // Show Login Screen if no session
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(AppTranslations.of(context, 'kitchenLogin'),
                style: TextStyle(color: textColor)),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: textColor),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Theme.of(context).cardTheme.color,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.lock, size: 64, color: textColor),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      style: TextStyle(color: textColor),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AppTranslations.of(context, 'email'),
                        labelStyle:
                            TextStyle(color: textColor?.withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: textColor!.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor)),
                        prefixIcon: Icon(LucideIcons.mail,
                            color: textColor.withOpacity(0.5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: AppTranslations.of(context, 'password'),
                        labelStyle:
                            TextStyle(color: textColor.withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: textColor.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor)),
                        prefixIcon: Icon(LucideIcons.lock,
                            color: textColor.withOpacity(0.5)),
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
                            : Text(
                                AppTranslations.of(context, 'loginToKitchen')),
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

    return AdminScaffold(
      title: AppTranslations.of(context, 'kitchenDisplayTitle'),
      activeRoute: '/kitchen',
      actions: [
        IconButton(
          icon: Icon(_isSoundEnabled ? LucideIcons.bell : LucideIcons.bellOff),
          color: _isSoundEnabled ? Colors.amber : Colors.grey,
          onPressed: () {
            setState(() {
              _isSoundEnabled = !_isSoundEnabled;
            });
            if (_isSoundEnabled) {
              _playNotificationSound(); // Preview sound
            }
          },
        ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw),
          onPressed: () => _loadOrders(),
        ),
        IconButton(
          icon: const Icon(LucideIcons.logOut),
          onPressed: _signOut,
        )
      ],
      body: _isLoadingOrders
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.checkCircle,
                          size: 64,
                          color: isDark ? Colors.greenAccent : Colors.green),
                      const SizedBox(height: 16),
                      Text(AppTranslations.of(context, 'noOrdersKitchen'),
                          style: TextStyle(
                              color: textColor?.withOpacity(0.7),
                              fontSize: 18)),
                    ],
                  ),
                )
              : !Responsive.isMobile(context)
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8, // Adjust based on card content
                      ),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        return _OrderCard(
                          order: _orders[index],
                          onAdvance: () {
                            final currentStatus = _orders[index]['status'];
                            final nextStatus =
                                currentStatus == 'pending' ? 'prep' : 'ready';
                            _updateStatus(_orders[index]['id'], nextStatus);
                          },
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    final DateTime createdAt = DateTime.parse(order['created_at']).toLocal();
    final timeStr = DateFormat('HH:mm').format(createdAt);

    final status = order['status'].toString().toUpperCase();
    final isPending = status == 'PENDING';
    final cardColor = isPending ? Colors.orange.shade900 : Colors.blue.shade900;

    // Softer background for Light Mode, Deep dark for Dark Mode
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? cardColor : cardColor.withOpacity(0.6);

    final items = List<Map<String, dynamic>>.from(order['order_items'] ?? []);

    return Card(
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isDark ? 0 : 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(isDark ? 0.3 : 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppTranslations.of(context, 'orders')} #${order['id'].toString().substring(0, 8)}',
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                // Display Table Number or Takeaway
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black38 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey[400]!,
                        width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.utensilsCrossed,
                          color: textColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        order['tables'] != null
                            ? '${AppTranslations.of(context, 'table')} ${order['tables']['table_number']}'
                            : AppTranslations.of(context, 'takeaway'),
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                      color: textColor?.withOpacity(0.7),
                      fontWeight: FontWeight.bold),
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
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ImageHelper.buildProductImage(
                          prodName,
                          product != null ? product['image_url'] : null,
                          width: 48,
                          height: 48,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prodName,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold)),
                            if (notes != null && notes.toString().isNotEmpty)
                              Text(
                                  '${AppTranslations.of(context, 'note')}: $notes',
                                  style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${quantity}x',
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.bold)),
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
                icon:
                    Icon(isPending ? LucideIcons.utensils : LucideIcons.check),
                label: Text(
                  isPending
                      ? AppTranslations.of(context, 'startPreparing')
                      : AppTranslations.of(context, 'markAsReady'),
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
