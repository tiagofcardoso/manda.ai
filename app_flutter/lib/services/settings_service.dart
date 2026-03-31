import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/api.dart';

/// Service to manage establishment settings like currency
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _supabase = Supabase.instance.client;
  final ValueNotifier<String> currencyNotifier = ValueNotifier('EUR');

  /// Load the currency setting for the current establishment
  Future<void> loadCurrency() async {
    try {
      debugPrint('🔄 SettingsService: Loading currency...');
      final userId = _supabase.auth.currentUser?.id;
      debugPrint('👤 User ID: $userId');

      if (userId == null) {
        debugPrint('⚠️ No user logged in, defaulting to EUR');
        currencyNotifier.value = 'EUR';
        return;
      }

      // Get user's establishment_id from profile
      final profile = await _supabase
          .from('profiles')
          .select('establishment_id')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('📋 Profile data: $profile');

      if (profile == null || profile['establishment_id'] == null) {
        debugPrint('⚠️ No establishment assigned, defaulting to EUR');
        currencyNotifier.value = 'EUR';
        return;
      }

      final establishmentId = profile['establishment_id'];
      debugPrint('🏢 Establishment ID: $establishmentId');

      // Get establishment's currency
      final establishment = await _supabase
          .from('establishments')
          .select('currency')
          .eq('id', establishmentId)
          .single();

      debugPrint('🏪 Establishment data: $establishment');
      final currency = establishment['currency'] ?? 'EUR';
      debugPrint('💰 Currency loaded: $currency');

      currencyNotifier.value = currency;
    } catch (e) {
      debugPrint('❌ Error loading currency: $e');
      currencyNotifier.value = 'EUR';
    }
  }

  /// Load currency for a specific establishment (e.g. for Guests scanning a QR)
  Future<void> loadCurrencyForEstablishment(String establishmentId) async {
    try {
      debugPrint('🔄 SettingsService: Loading currency for guest visiting $establishmentId...');
      final establishment = await _supabase
          .from('establishments')
          .select('currency')
          .eq('id', establishmentId)
          .maybeSingle();
          
      if (establishment != null && establishment['currency'] != null) {
        currencyNotifier.value = establishment['currency'];
        debugPrint('💰 Guest Currency loaded: ${currencyNotifier.value}');
      }
    } catch (e) {
      debugPrint('❌ Error loading guest currency: $e');
    }
  }

  /// Update the establishment's currency via API
  Future<void> updateCurrency(String currency) async {
    debugPrint('💱 Updating currency to: $currency');
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/admin/settings/currency'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'currency': currency}),
    );

    debugPrint('📡 Response status: ${response.statusCode}');
    debugPrint('📡 Response body: ${response.body}');

    if (response.statusCode == 200) {
      currencyNotifier.value = currency;
      debugPrint('✅ Currency updated successfully to: $currency');
    } else {
      debugPrint('❌ Failed to update currency: ${response.body}');
      throw Exception('Failed to update currency: ${response.body}');
    }
  }

  /// Get the current currency code
  String get currency => currencyNotifier.value;

  /// Get currency symbol for display
  String getCurrencySymbol(String currencyCode) {
    const symbols = {
      'EUR': '€',
      'USD': '\$',
      'GBP': '£',
      'BRL': 'R\$',
      'AOA': 'Kz',
      'CVE': 'CVE',
      'MZN': 'MT',
      'JPY': '¥',
      'CNY': '¥',
      'INR': '₹',
    };
    return symbols[currencyCode] ?? currencyCode;
  }
}
