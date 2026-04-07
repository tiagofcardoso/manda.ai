import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../services/app_translations.dart';
import '../../services/settings_service.dart';
import '../../utils/image_helper.dart';
import '../../widgets/admin/admin_scaffold.dart';
import '../../services/printer_service.dart';

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
  Set<String> _knownOrderIds = {};
  bool _isFirstLoad = true;

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
        if (!_isFirstLoad) {
          for (var order in orders) {
            final id = order['id'].toString();
            final status = order['status'].toString();
            if (!_knownOrderIds.contains(id) && status == 'pending') {
              try {
                PrinterService().printOrder(order, 'Cozinha Manda.AI');
              } catch (e) {
                // Prevent crash if blocked by browser
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Atenção: Novo Pedido Chegou!'),
                  backgroundColor: Colors.green.shade700,
                  duration: const Duration(seconds: 15),
                  action: SnackBarAction(
                    label: 'IMPRIMIR MANUALMENTE',
                    textColor: Colors.white,
                    onPressed: () => PrinterService().printOrder(order, 'Cozinha Manda.AI'),
                  ),
                ),
              );
            }
          }
        }
        
        setState(() {
          _orders = orders;
          _isLoading = false;
          _knownOrderIds = orders.map((e) => e['id'].toString()).toSet();
          _isFirstLoad = false;
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
      builder: (context) => _OrderDetailSheet(
        order: order,
        onStatusChange: (orderId, newStatus) {
          Navigator.pop(context); // Close sheet
          _updateOrderStatus(orderId, newStatus);
        },
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.of(context, 'orderUpdated') + ' $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.of(context, 'errorUpdatingStatus')} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return AdminScaffold(
      title: AppTranslations.of(context, 'orders'),
      activeRoute: '/admin-orders',
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.refreshCw),
          onPressed: _loadOrders,
        ),
      ],
      body: CustomScrollView(
        slivers: [
          // Remove SliverAppBar as AdminScaffold handles the header

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 24, 16, 8), // Added top padding
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
          else if (_selectedStatus == null || _selectedStatus == 'all')
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildKanbanColumn('pending', 'Pedidos Recebidos', isDark, textColor),
                    _buildKanbanColumn('prep', 'Preparando', isDark, textColor),
                    _buildKanbanColumn('ready', 'Pronto para retirar', isDark, textColor),
                    _buildKanbanColumn('on_way', 'Saiu para entrega', isDark, textColor),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 170, // Fixed height for cards
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
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

  Widget _buildKanbanColumn(String status, String title, bool isDark, Color? textColor) {
    final columnOrders = _filteredOrders.where((o) => o['status'] == status).toList();
    
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${columnOrders.length}',
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Column Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: columnOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = columnOrders[index];
                return _OrderCard(
                  order: order,
                  onTap: () => _showOrderDetails(order),
                  getStatusColor: _getStatusColor,
                  getStatusIcon: _getStatusIcon,
                  getStatusLabel: _getStatusLabel,
                );
              },
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
        ? 'Mesa ${order['tables']['table_number']}'
        : (isDelivery ? 'Delivery' : 'Takeaway');
        
    final typeColor = isDelivery 
        ? Colors.blue 
        : Colors.orange;

    final typeBgColor = isDelivery 
        ? Colors.blue.withOpacity(isDark ? 0.2 : 0.1)
        : Colors.orange.withOpacity(isDark ? 0.2 : 0.1);

    final typeTextColor = isDelivery 
        ? (isDark ? Colors.blue[300] : Colors.blue[700])
        : (isDark ? Colors.orange[300] : Colors.orange[800]);

    return Container(
      // margin: const EdgeInsets.only(bottom: 12), // Handled by GridView spacing
      decoration: BoxDecoration(
        color: isDark ? statusColor.withOpacity(0.1) : statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(isDark ? 0.3 : 0.4),
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: statusColor.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: statusColor.withOpacity(0.1),
                  blurRadius: 8,
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
                        color: typeBgColor,
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
                            color: typeTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tableNumber.toString(),
                            style: TextStyle(
                              color: typeTextColor,
                              fontWeight: FontWeight.w700,
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
                    IconButton(
                      icon: Icon(LucideIcons.printer, color: textColor?.withOpacity(0.8), size: 20),
                      onPressed: () {
                         PrinterService().printOrder(order, 'Manda.AI');
                      },
                    ),
                    Text(
                      NumberFormat.currency(symbol: SettingsService().getCurrencySymbol(SettingsService().currency)).format(total),
                      style: const TextStyle(
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
  final Function(String orderId, String newStatus) onStatusChange;

  const _OrderDetailSheet({required this.order, required this.onStatusChange});

  Widget _buildActionButtons(BuildContext context) {
    final status = order['status'].toString();
    final orderId = order['id'].toString();
    final orderType = order['order_type'].toString();
    
    // Determine which buttons to show based on status
    if (status == 'pending') {
      return ElevatedButton.icon(
        onPressed: () => onStatusChange(orderId, 'prep'),
        icon: const Icon(LucideIcons.chefHat),
        label: Text(AppTranslations.of(context, 'startPreparing')),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
      );
    } else if (status == 'prep') {
      return ElevatedButton.icon(
        onPressed: () => onStatusChange(orderId, 'ready'),
        icon: const Icon(LucideIcons.checkCircle),
        label: Text(AppTranslations.of(context, 'markAsReady')),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
      );
    } else if (status == 'ready') {
      if (orderType == 'delivery') {
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(orderId, 'on_way'),
          icon: const Icon(LucideIcons.bike),
          label: const Text('Dispatch for Delivery'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
        );
      } else {
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(orderId, 'completed'),
          icon: const Icon(LucideIcons.checkCheck),
          label: const Text('Complete Order'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
        );
      }
    } else if (status == 'on_way') {
      return ElevatedButton.icon(
        onPressed: () => onStatusChange(orderId, 'delivered'),
        icon: const Icon(LucideIcons.packageCheck),
        label: const Text('Mark as Delivered'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
      );
    }
    
    return const SizedBox.shrink(); // No actions for delivered/completed
  }

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
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                   width: double.infinity,
                   height: 50,
                   child: _buildActionButtons(context),
                ),
              ),
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
                                    style: const TextStyle(
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
