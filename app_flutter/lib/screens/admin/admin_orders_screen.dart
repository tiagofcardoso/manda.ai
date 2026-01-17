import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../services/app_translations.dart';
import '../../utils/image_helper.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _adminService = AdminService();
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _subscription;

  String? _selectedStatus; // null = all
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<String> _statusFilters = [
    'all',
    'pending',
    'prep',
    'ready',
    'on_way',
    'delivered',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _subscription = _supabase
        .channel('admin:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint('Order changed, refreshing...');
            _loadOrders();
          },
        )
        .subscribe();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() => _isLoading = true);
      final orders = await _adminService.fetchOrders(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;

    return _orders.where((order) {
      final orderId = order['id'].toString().toLowerCase();
      final tableNumber = order['tables'] != null
          ? order['tables']['table_number'].toString()
          : '';
      final userName = order['profiles'] != null
          ? (order['profiles']['full_name'] ?? '').toString().toLowerCase()
          : '';

      final query = _searchQuery.toLowerCase();
      return orderId.contains(query) ||
          tableNumber.contains(query) ||
          userName.contains(query);
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'prep':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'on_way':
        return Colors.blue;
      case 'delivered':
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return LucideIcons.clock;
      case 'prep':
        return LucideIcons.chefHat;
      case 'ready':
        return LucideIcons.checkCircle;
      case 'on_way':
        return LucideIcons.bike;
      case 'delivered':
      case 'completed':
        return LucideIcons.packageCheck;
      default:
        return LucideIcons.helpCircle;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return AppTranslations.of(context, 'statusPending');
      case 'prep':
        return AppTranslations.of(context, 'statusPrep');
      case 'ready':
        return AppTranslations.of(context, 'statusReady');
      case 'on_way':
        return AppTranslations.of(context, 'statusOnWay');
      case 'delivered':
        return AppTranslations.of(context, 'statusDelivered');
      case 'completed':
        return 'Completed';
      default:
        return status.toUpperCase();
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: textColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                AppTranslations.of(context, 'orders'),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                onPressed: _loadOrders,
              ),
            ],
          ),
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search by order ID, table, or customer...',
                  hintStyle: TextStyle(color: textColor?.withOpacity(0.5)),
                  prefixIcon: Icon(LucideIcons.search, color: textColor),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),
          // Status Filter Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _statusFilters.length,
                itemBuilder: (context, index) {
                  final status = _statusFilters[index];
                  final isSelected = (_selectedStatus == status) ||
                      (_selectedStatus == null && status == 'all');

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        status == 'all' ? 'All' : _getStatusLabel(status),
                        style: TextStyle(
                          color: isSelected ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = status == 'all' ? null : status;
                        });
                        _loadOrders();
                      },
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      selectedColor: _getStatusColor(status),
                      checkmarkColor: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // Orders List
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredOrders.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.inbox,
                        size: 64, color: textColor?.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(
                          color: textColor?.withOpacity(0.5), fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = _filteredOrders[index];
                    return _OrderCard(
                      order: order,
                      onTap: () => _showOrderDetails(order),
                      getStatusColor: _getStatusColor,
                      getStatusIcon: _getStatusIcon,
                      getStatusLabel: _getStatusLabel,
                    );
                  },
                  childCount: _filteredOrders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final String Function(String) getStatusLabel;

  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.getStatusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    final status = order['status'].toString();
    final statusColor = getStatusColor(status);
    final createdAt = DateTime.parse(order['created_at']).toLocal();
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final dateStr = DateFormat('dd/MM').format(createdAt);

    final items = List<Map<String, dynamic>>.from(order['order_items'] ?? []);
    final itemCount = items.fold<int>(
        0, (sum, item) => sum + (item['quantity'] as int? ?? 0));

    final total = order['total_amount'];
    final orderType = order['order_type'];
    final isDelivery = orderType == 'delivery';

    final tableNumber = order['tables'] != null
        ? order['tables']['table_number']
        : (isDelivery ? 'Delivery' : 'Takeaway');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(getStatusIcon(status),
                              size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            getStatusLabel(status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Time
                    Text(
                      '$dateStr • $timeStr',
                      style: TextStyle(
                        color: textColor?.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Order ID & Table
                Row(
                  children: [
                    Text(
                      '#${order['id'].toString().substring(0, 8)}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDelivery
                                ? LucideIcons.bike
                                : LucideIcons.utensilsCrossed,
                            size: 12,
                            color: textColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tableNumber.toString(),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Items count & Total
                Row(
                  children: [
                    Icon(LucideIcons.shoppingBag,
                        size: 16, color: textColor?.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      '$itemCount items',
                      style: TextStyle(
                        color: textColor?.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      NumberFormat.currency(symbol: '€').format(total),
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final items = List<Map<String, dynamic>>.from(order['order_items'] ?? []);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Order #${order['id'].toString().substring(0, 8)}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Items List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final product = item['products'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ImageHelper.buildProductImage(
                              product['name'],
                              product['image_url'],
                              width: 60,
                              height: 60,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (item['notes'] != null &&
                                    item['notes'].toString().isNotEmpty)
                                  Text(
                                    item['notes'],
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${item['quantity']}x',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
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
        );
      },
    );
  }
}
