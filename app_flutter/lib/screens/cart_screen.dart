import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../models/cart_item.dart';
import '../services/app_translations.dart';
import '../services/auth_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    final cartService = CartService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppTranslations.of(context, 'cart'),
            style: TextStyle(color: textColor)),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartService.itemsNotifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
                child: Text(AppTranslations.of(context, 'emptyCart'),
                    style: TextStyle(color: textColor)));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ],
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          // Product Image Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 60,
                              height: 60,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                              child: item.product.imageUrl != null &&
                                      item.product.imageUrl!.isNotEmpty
                                  ? Image.network(item.product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                          LucideIcons.image,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.grey))
                                  : Icon(LucideIcons.utensils,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name,
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(
                                  NumberFormat.currency(symbol: '€')
                                      .format(item.total),
                                  style: const TextStyle(
                                      color: Color(0xFFE63946),
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          // Quantity Controls
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: Icon(LucideIcons.minus,
                                        size: 16, color: textColor),
                                    onPressed: () =>
                                        cartService.updateQuantity(item, -1)),
                                Text('${item.quantity}',
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                    icon: Icon(LucideIcons.plus,
                                        size: 16, color: textColor),
                                    onPressed: () =>
                                        cartService.updateQuantity(item, 1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _CheckoutArea(cartService: cartService),
            ],
          );
        },
      ),
    );
  }
}

class _CheckoutArea extends StatefulWidget {
  final CartService cartService;
  const _CheckoutArea({required this.cartService});

  @override
  State<_CheckoutArea> createState() => _CheckoutAreaState();
}

class _CheckoutAreaState extends State<_CheckoutArea> {
  bool _isLoading = false;

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);

    try {
      final tableId = widget.cartService.tableId;
      final user = AuthService().currentUser;

      // ====================================================
      // A) TABLE ORDERS (Dine-In)
      // ====================================================
      if (tableId != null) {
        // Guests ALLOWED. No Address Required.
        final payload = {
          "table_id": tableId,
          "total": widget.cartService.totalAmount,
          "items": widget.cartService.items
              .map((item) => {
                    "product_id": item.product.id,
                    "quantity": item.quantity,
                    "price": item.product.price,
                    "notes": item.notes
                  })
              .toList()
        };

        // Call Dedicated Table Endpoint
        final response = await OrderService().placeTableOrder(payload);
        _handleSuccess(response['order_id']);
        return;
      }

      // ====================================================
      // B) DELIVERY ORDERS (Client)
      // ====================================================
      // 1. Enforce Auth
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.of(context, 'loginRequired')),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'LOGIN',
                textColor: Colors.white,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          );
        }
        return;
      }

      // 2. Determine Address
      String deliveryAddress = '';
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('street, city, zip_code')
            .eq('id', user.id)
            .single();

        final street = profile['street'] ?? '';
        final city = profile['city'] ?? '';

        if (street.toString().trim().isEmpty) {
          throw Exception(
              'Please update your address in Profile before ordering.');
        }

        deliveryAddress = '$street, $city';
      } catch (e) {
        if (e.toString().contains('Please update')) rethrow;
        deliveryAddress = 'Address not found';
      }

      final payload = {
        "user_id": user.id,
        "total": widget.cartService.totalAmount,
        "delivery_address": deliveryAddress,
        "items": widget.cartService.items
            .map((item) => {
                  "product_id": item.product.id,
                  "quantity": item.quantity,
                  "price": item.product.price,
                  "notes": item.notes
                })
            .toList()
      };

      // Call Dedicated Delivery Endpoint
      final response = await OrderService().placeDeliveryOrder(payload);
      _handleSuccess(response['order_id']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSuccess(String orderId) {
    OrderService().setOrderId(orderId);
    widget.cartService.clear();

    if (mounted) {
      Navigator.pop(context); // Close Cart

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppTranslations.of(context, 'orderPlaced')} ${AppTranslations.of(context, 'checkOrdersTab')}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Table Info (Centered Pill)
            ValueListenableBuilder<List<CartItem>>(
              // Reusing the itemsNotifier for rebuild trigger, assuming simpler logic for now
              valueListenable: widget.cartService.itemsNotifier,
              builder: (context, _, __) {
                final tableId = widget.cartService.tableId;
                return Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            tableId != null
                                ? LucideIcons.utensilsCrossed
                                : LucideIcons.bike,
                            color: textColor?.withOpacity(0.7),
                            size: 16),
                        const SizedBox(width: 8),
                        Text(
                          tableId != null
                              ? '${AppTranslations.of(context, 'table')} $tableId'
                              : 'Delivery Mode',
                          style: TextStyle(
                              color: textColor, fontWeight: FontWeight.bold),
                        ),
                        if (tableId != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              widget.cartService.setDeliveryAddress(
                                  'Reset'); // Clears Table ID
                              // Force rebuild
                              setState(() {});
                            },
                            child: const Icon(LucideIcons.xCircle,
                                color: Colors.red, size: 20),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppTranslations.of(context, 'total'),
                    style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(
                  NumberFormat.currency(symbol: '€')
                      .format(widget.cartService.totalAmount),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE63946)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _placeOrder,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppTranslations.of(context, 'placeOrder').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
