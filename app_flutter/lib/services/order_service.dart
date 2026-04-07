import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  static const String _kOrderIdKey = 'active_table_order_id';
  static const String _kOrderHistoryKey = 'recent_order_ids';

  final ValueNotifier<String?> currentOrderIdNotifier = ValueNotifier(null);
  List<String> _recentOrderIds = [];

  String? get currentOrderId => currentOrderIdNotifier.value;
  List<String> get recentOrderIds => List.unmodifiable(_recentOrderIds);

  /// Load persisted order ID from storage (survives app navigation & refresh)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kOrderIdKey);
    _recentOrderIds = prefs.getStringList(_kOrderHistoryKey) ?? [];
    if (saved != null) {
      currentOrderIdNotifier.value = saved;
    }
  }

  Future<void> setOrderId(String orderId) async {
    currentOrderIdNotifier.value = orderId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOrderIdKey, orderId);
    _recentOrderIds.remove(orderId);
    _recentOrderIds.insert(0, orderId);
    if (_recentOrderIds.length > 20) {
      _recentOrderIds = _recentOrderIds.take(20).toList();
    }
    await prefs.setStringList(_kOrderHistoryKey, _recentOrderIds);
  }

  Future<void> clearOrder() async {
    currentOrderIdNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOrderIdKey);
  }

  Future<void> removeOrderFromHistory(String orderId) async {
    _recentOrderIds.remove(orderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOrderHistoryKey, _recentOrderIds);
    if (currentOrderIdNotifier.value == orderId) {
      currentOrderIdNotifier.value =
          _recentOrderIds.isNotEmpty ? _recentOrderIds.first : null;
      if (currentOrderIdNotifier.value == null) {
        await prefs.remove(_kOrderIdKey);
      } else {
        await prefs.setString(_kOrderIdKey, currentOrderIdNotifier.value!);
      }
    }
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
