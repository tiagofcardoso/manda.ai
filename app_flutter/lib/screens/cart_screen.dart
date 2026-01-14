import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Needed for kIsWeb

import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../models/cart_item.dart';
import '../services/table_service.dart';
import 'order_tracking_screen.dart';
import '../services/app_translations.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    final cartService = CartService();
    // Force dark background for this screen to match mockup
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppTranslations.of(context, 'cart'),
            style: const TextStyle(color: Colors.white)),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartService.itemsNotifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
                child: Text(AppTranslations.of(context, 'emptyCart')));
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
                        color: const Color(0xFF2d2d2d),
                        borderRadius: BorderRadius.circular(12),
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
                              color: Colors.grey[800],
                              child: item.product.imageUrl != null &&
                                      item.product.imageUrl!.isNotEmpty
                                  ? Image.network(item.product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          LucideIcons.image,
                                          color: Colors.white24))
                                  : const Icon(LucideIcons.utensils,
                                      color: Colors.white24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name,
                                    style: const TextStyle(
                                        color: Colors.white,
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
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(LucideIcons.minus,
                                        size: 16, color: Colors.white),
                                    onPressed: () =>
                                        cartService.updateQuantity(item, -1)),
                                Text('${item.quantity}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                    icon: const Icon(LucideIcons.plus,
                                        size: 16, color: Colors.white),
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
      final tableId = TableService().tableId ??
          "00000000-0000-0000-0000-000000000000"; // Fallback

      // Prepare Payload
      final orderData = {
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

      // Send to Backend
      String baseUrl;
      if (kIsWeb) {
        baseUrl = 'http://127.0.0.1:8000'; // Web uses localhost
      } else {
        baseUrl = 'http://10.0.2.2:8000'; // Android Emulator alias
      }

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200) {
        final respJson = jsonDecode(response.body);
        final orderId = respJson['order_id'];

        // Save globally
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
      } else {
        throw Exception('Failed to place order: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1a1a1a),
      child: SafeArea(
        child: Column(
          children: [
            // Table Info (Centered Pill)
            ValueListenableBuilder<String?>(
              valueListenable: TableService().tableNumberNotifier,
              builder: (context, tableNumber, _) {
                return Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.utensilsCrossed,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          tableNumber != null
                              ? '${AppTranslations.of(context, 'table')} $tableNumber'
                              : AppTranslations.of(context, 'noTable'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
                    style: const TextStyle(
                        color: Colors.white,
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
