import 'package:flutter/material.dart';
import 'locale_service.dart';

class AppTranslations {
  static final Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Manda.AI',
      'welcome': 'Welcome',
      'scanTable': 'Scan Table QR Code',
      'skipDemo': 'Skip (Demo Mode)',
      'menu': 'Menu',
      'cart': 'Cart',
      'orders': 'Orders',
      'addToCart': 'Add to Cart',
      'placeOrder': 'Place Order',
      'total': 'Total',
      'table': 'Table',
      'noTable': 'No Table (Takeaway)',
      'kitchenDisplay': 'Kitchen Display',
      'login': 'Login',
      'orderPlaced': 'Order placed successfully!',
      'checkOrdersTab': 'Check the Orders tab for updates.',
      'emptyCart': 'Your cart is empty',
      'items': 'items',
    },
    'pt': {
      'appTitle': 'Manda.AI',
      'welcome': 'Bem-vindo',
      'scanTable': 'Escanear QR Code',
      'skipDemo': 'Pular (Demo)',
      'menu': 'Cardápio',
      'cart': 'Carrinho',
      'orders': 'Pedidos',
      'addToCart': 'Adicionar',
      'placeOrder': 'Fazer Pedido',
      'total': 'Total',
      'table': 'Mesa',
      'noTable': 'Sem Mesa (Viagem)',
      'kitchenDisplay': 'Cozinha (KDS)',
      'login': 'Entrar',
      'orderPlaced': 'Pedido enviado!',
      'checkOrdersTab': 'Acompanhe na aba Pedidos.',
      'emptyCart': 'Carrinho vazio',
      'items': 'itens',
    },
  };

  static String of(BuildContext context, String key) {
    final locale = LocaleService().localeNotifier.value.languageCode;
    return _values[locale]?[key] ?? key;
  }
}
