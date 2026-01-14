import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Needed for kIsWeb

import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../models/cart_item.dart';
import '../services/table_service.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();
    // No explicit background/AppBar color -> Uses Theme
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Order'),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartService.itemsNotifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Text('${item.quantity}x',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      title: Text(item.product.name),
                      subtitle: Text(NumberFormat.currency(symbol: '€')
                          .format(item.total)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () =>
                                  cartService.updateQuantity(item, -1)),
                          IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () =>
                                  cartService.updateQuantity(item, 1)),
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
            const SnackBar(
              content: Text('Order placed! Go to "Orders" tab to track it.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // Adaptation
      child: SafeArea(
        child: Column(
          children: [
            // Table Info
            ValueListenableBuilder<String?>(
              valueListenable: TableService().tableNumberNotifier,
              builder: (context, tableNumber, _) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_restaurant,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tableNumber != null
                            ? 'Mesa $tableNumber'
                            : 'No Table (Takeaway)',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
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
                    : const Text('SEND ORDER',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
