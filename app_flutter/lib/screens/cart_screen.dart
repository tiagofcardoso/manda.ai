import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Needed for kIsWeb

import '../services/cart_service.dart';
import '../models/cart_item.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

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
                child: ListView.builder(
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
      // Prepare Payload
      final orderData = {
        "table_id":
            "00000000-0000-0000-0000-000000000000", // TODO: Get REAL Table ID from QR Scan
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
        widget.cartService.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order sent to kitchen! 👨‍🍳')));
          Navigator.pop(context);
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
      color: Colors.grey.shade900,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
