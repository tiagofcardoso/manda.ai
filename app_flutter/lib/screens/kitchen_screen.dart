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
import '../services/printer_service.dart';
import '../services/backend_heartbeat_service.dart';
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
  String _establishmentName = 'Manda.AI'; 
  Set<String> _printedOrderIds = {}; 

  @override
  void initState() {
    super.initState();
    BackendHeartbeatService().start();
    _setupRealtimeSubscription();
    _loadOrders(); // Initial Load

    // Polling fallback to ensure reliability (every 1s)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _loadOrders(silent: true);
    });

    _fetchEstablishmentInfo();

    // Listen for Auth Changes to re-subscribe if needed
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        print("Kitchen: Auth changed (Signed In), re-subscribing...");
        _subscription?.unsubscribe();
        _setupRealtimeSubscription();
        _loadOrders();
      }
    });
  }

  Future<void> _fetchEstablishmentInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final profile = await _supabase.from('profiles').select('establishment_id').eq('id', user.id).maybeSingle();
      final estId = profile?['establishment_id'];
      if (estId != null) {
        final est = await _supabase.from('establishments').select('name').eq('id', estId).maybeSingle();
        if (mounted && est != null) {
          setState(() => _establishmentName = est['name'] ?? 'Manda.AI');
        }
      }
    } catch (e) {
      debugPrint('Error fetching establishment info: $e');
    }
  }

  @override
  void dispose() {
    BackendHeartbeatService().stop();
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
    _subscription = _supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            print("Kitchen: Change detected! Refreshing...");
            if (mounted) {
              _loadOrders(silent: true); 

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

      await _audioPlayer.play(AssetSource(soundFile), volume: 1.0);
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoadingOrders = true);

    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
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

        if (silent && mounted) {
          final oldIds = _orders.map((e) => e['id']).toSet();
          final hasNew = newOrders.any((o) => !oldIds.contains(o['id']));
          if (hasNew) {
            if (_isSoundEnabled) _playNotificationSound();
            
            // AUTO-PRINT NEW ORDERS
            for (var order in newOrders) {
               if (!oldIds.contains(order['id']) && !_printedOrderIds.contains(order['id'])) {
                  _printedOrderIds.add(order['id']);
                  PrinterService().printOrder(order, _establishmentName).then((success) {
                    if (!success && mounted) {
                       _printedOrderIds.remove(order['id']);
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Erro na impressora! Verifique conexão.'), backgroundColor: Colors.red),
                       );
                    }
                  });
               }
            }

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
        if (mounted) setState(() => _isLoadingOrders = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      final session = _supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) return;

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
          _loadOrders(silent: true);
        }
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
  bool _isSigningIn = false;

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        _loadOrders();
        _fetchEstablishmentInfo();
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
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
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

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(AppTranslations.of(context, 'kitchenLogin')),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: textColor),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
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
                      decoration: InputDecoration(labelText: AppTranslations.of(context, 'email')),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(labelText: AppTranslations.of(context, 'password')),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: _isSigningIn ? null : _signIn,
                        child: _isSigningIn
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(AppTranslations.of(context, 'loginToKitchen')),
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
            setState(() => _isSoundEnabled = !_isSoundEnabled);
            if (_isSoundEnabled) _playNotificationSound();
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
                      Icon(LucideIcons.checkCircle, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(AppTranslations.of(context, 'noOrdersKitchen')),
                    ],
                  ),
                )
              : Responsive.isMobile(context)
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) => _OrderCard(
                        order: _orders[index],
                        establishmentName: _establishmentName,
                        onAdvance: () {
                          final currentStatus = _orders[index]['status'];
                          _updateStatus(_orders[index]['id'], currentStatus == 'pending' ? 'prep' : 'ready');
                        },
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) => _OrderCard(
                        order: _orders[index],
                        establishmentName: _establishmentName,
                        onAdvance: () {
                          final currentStatus = _orders[index]['status'];
                          _updateStatus(_orders[index]['id'], currentStatus == 'pending' ? 'prep' : 'ready');
                        },
                      ),
                    ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String establishmentName;
  final VoidCallback onAdvance;

  const _OrderCard({required this.order, required this.establishmentName, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    final createdAt = DateTime.parse(order['created_at']).toLocal();
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final status = order['status'].toString().toUpperCase();
    final isPending = status == 'PENDING';
    final cardColor = isPending ? Colors.orange.shade900 : Colors.blue.shade900;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final rawItems = order['order_items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Card(
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isDark ? cardColor : cardColor.withOpacity(0.6), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(isDark ? 0.3 : 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Pedido #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(LucideIcons.printer, size: 20),
                  onPressed: () => PrinterService().printOrder(order, establishmentName),
                ),
                Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.map((item) {
                final product = item['products'];
                return Row(
                  children: [
                    Text('${item['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(product?['name'] ?? 'Item')),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: onAdvance,
                 style: ElevatedButton.styleFrom(backgroundColor: isPending ? Colors.orange : Colors.blue, foregroundColor: Colors.white),
                 icon: Icon(isPending ? LucideIcons.utensils : LucideIcons.check),
                 label: Text(isPending ? AppTranslations.of(context, 'startPreparing') : AppTranslations.of(context, 'markAsReady')),
               ),
            ),
          ),
        ],
      ),
    );
  }
}
