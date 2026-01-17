import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final ValueNotifier<String?> currentOrderIdNotifier = ValueNotifier(null);

  String? get currentOrderId => currentOrderIdNotifier.value;

  // Initialize (no-op for now, OrderService doesn't persist)
  Future<void> init() async {
    // Guest order persistence was reverted
    // Table sessions are now handled by CartService
  }

  void setOrderId(String orderId) {
    currentOrderIdNotifier.value = orderId;
  }

  void clearOrder() {
    currentOrderIdNotifier.value = null;
  }

  Future<Map<String, dynamic>> placeTableOrder(
      Map<String, dynamic> orderData) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/orders/table'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(orderData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to place table order: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> placeDeliveryOrder(
      Map<String, dynamic> orderData) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/orders/delivery'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(orderData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to place delivery order: ${response.body}');
    }
    return jsonDecode(response.body);
  }
}
