import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  String? _tableId;
  String? _establishmentId; // [NEW] Track active store
  String? _deliveryAddress;
  bool _isExplicitTableMode = false; // Tracks if table was set by QR scan

  final ValueNotifier<List<CartItem>> itemsNotifier = ValueNotifier([]);

  String? get tableId => _tableId;
  String? get establishmentId => _establishmentId;
  bool get isExplicitTableMode => _isExplicitTableMode;

  // Load table session on app start
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTableId = prefs.getString('table_id');
    final savedEstId = prefs.getString('establishment_id');
    final savedExplicitFlag = prefs.getBool('is_explicit_table_mode') ?? false;

    // Restore establishment if available
    if (savedEstId != null) {
      _establishmentId = savedEstId;
    }

    // Only restore if it was an explicit QR scan session
    if (savedTableId != null && savedExplicitFlag) {
      _tableId = savedTableId;
      _isExplicitTableMode = true;
    }
  }

  Future<void> setTableId(String id,
      {bool explicit = false, String? establishmentId}) async {
    _tableId = id;
    _isExplicitTableMode = explicit; // Mark if this was a QR scan
    _deliveryAddress = null; // Reset delivery address if table is set

    // Update establishment if provided
    if (establishmentId != null) {
      await setEstablishmentId(establishmentId);
    }

    // Persist if explicit (QR scan)
    if (explicit) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('table_id', id);
      await prefs.setBool('is_explicit_table_mode', true);
    }
  }

  Future<void> setEstablishmentId(String id) async {
    if (_establishmentId != id) {
      _establishmentId = id;
      // Optionally clear cart if switching stores? For now, keep it simple.
      // itemsNotifier.value = [];
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('establishment_id', id);
  }

  Future<void> setDeliveryAddress(String address) async {
    _deliveryAddress = address;
    _tableId = null; // Reset table if delivery is set
    _isExplicitTableMode = false; // Clear the flag

    // Clear persisted table session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('table_id');
    await prefs.remove('is_explicit_table_mode');

    // NOTE: We do NOT clear establishment_id here, as delivery still happens within a store context.
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

  Future<void> clear() async {
    itemsNotifier.value = [];
    _tableId = null;
    _deliveryAddress = null;
    _isExplicitTableMode = false; // Reset the flag

    // Clear persisted table session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('table_id');
    await prefs.remove('is_explicit_table_mode');
  }

  void clearCartItemsOnly() {
    itemsNotifier.value = [];
  }
}
