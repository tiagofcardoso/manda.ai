import 'package:flutter/material.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final ValueNotifier<String?> currentOrderIdNotifier = ValueNotifier(null);

  String? get currentOrderId => currentOrderIdNotifier.value;

  void setOrderId(String orderId) {
    currentOrderIdNotifier.value = orderId;
  }

  void clearOrder() {
    currentOrderIdNotifier.value = null;
  }
}
