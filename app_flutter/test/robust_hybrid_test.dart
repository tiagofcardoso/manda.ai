import 'package:flutter_test/flutter_test.dart';
import 'package:manda_client/services/cart_service.dart';

void main() {
  group('Robust Hybrid Architecture State Tests', () {
    late CartService cartService;

    setUp(() {
      cartService = CartService();
      cartService.clear();
      // Reset state ensures isolation for these tests
      // Note: In a real app, we might need a way to fully reset the singleton,
      // but clear() combined with setting nulls below works for these fields.
      cartService.setTableId('RESET');
      cartService.setDeliveryAddress('RESET');

      // Force reset to a known clean state
      // This relies on the fact that setTableId(value) might clear address, etc.
      // But looking at CartService, we need to be careful.
      // The best way to reset is to simulate a "new" context.
      cartService.clear();
      // Manually nullify if needed via existing methods
    });

    test('CartService correctly stores Table ID for Guest/Table Mode', () {
      // Act
      cartService.setTableId(
          'TABLE-TEST-123'); // This should ALSO clear delivery address if logic is correct

      // Assert
      expect(cartService.tableId, 'TABLE-TEST-123');
    });

    test('CartService correctly stores Address for Delivery Mode', () {
      // Arrange
      cartService.setTableId('TABLE-OLD');

      // Act
      cartService.setDeliveryAddress('123 Testing St');

      // Assert
      // The requirement for Robust Architecture is strict separation.
      // If we set an address, we assume we are in Client Mode.
      // However, CartService might not AUTO-CLEAR tableId unless explicitly programmed.
      // Let's verify if the logic currently supports this or if we need to enforce it.
      // If this fails, it means we need to update CartService to ensure mutual exclusivity.
      expect(cartService.tableId, isNull,
          reason: "Table ID should be null when Address is set");
    });
  });
}
