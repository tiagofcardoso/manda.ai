import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  String? _tableId;
  String? _deliveryAddress;

  final ValueNotifier<List<CartItem>> itemsNotifier = ValueNotifier([]);

  String? get tableId => _tableId;

  void setTableId(String id) {
    _tableId = id;
    _deliveryAddress = null; // Reset delivery address if table is set
  }

  void setDeliveryAddress(String address) {
    _deliveryAddress = address;
    _tableId = null; // Reset table if delivery is set
  }

  List<CartItem> get items => itemsNotifier.value;

  double get totalAmount {
    return items.fold(0, (sum, item) => sum + item.total);
  }

  void addToCart(Product product) {
    // Check if product already exists
    try {
      final existingItem =
          items.firstWhere((item) => item.product.id == product.id);
      existingItem.quantity++;
      // Notify listeners (create new list reference to trigger update)
      itemsNotifier.value = List.from(items);
    } catch (e) {
      // Add new item
      final createList = List<CartItem>.from(items);
      createList.add(CartItem(product: product));
      itemsNotifier.value = createList;
    }
  }

  void removeFromCart(CartItem item) {
    final updateList = List<CartItem>.from(items);
    updateList.remove(item);
    itemsNotifier.value = updateList;
  }

  void updateQuantity(CartItem item, int delta) {
    if (item.quantity + delta <= 0) {
      removeFromCart(item);
      return;
    }
    item.quantity += delta;
    itemsNotifier.value = List.from(items);
  }

  void clear() {
    itemsNotifier.value = [];
  }
}
