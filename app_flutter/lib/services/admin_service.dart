import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/api.dart';

/// Service for admin-specific operations
class AdminService {
  final _supabase = Supabase.instance.client;

  /// Fetch all orders with optional filters
  Future<List<Map<String, dynamic>>> fetchOrders({
    String? status,
    String? orderType,
    String? dateFrom,
    String? dateTo,
    int limit = 100,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (orderType != null) queryParams['order_type'] = orderType;
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    queryParams['limit'] = limit.toString();

    final uri = Uri.parse('${ApiConstants.baseUrl}/admin/orders')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to fetch orders: ${response.body}');
    }
  }

  /// Fetch single order details
  Future<Map<String, dynamic>> fetchOrderDetail(String orderId) async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/admin/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch order: ${response.body}');
    }
  }

  /// Get today's stats
  Future<Map<String, dynamic>> getTodayStats() async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/admin/stats/today'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch stats: ${response.body}');
    }
  }

  /// Get orders count by status
  Future<Map<String, int>> getOrdersByStatus() async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/admin/stats/orders-by-status'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data.map((key, value) => MapEntry(key, value as int));
    } else {
      throw Exception('Failed to fetch orders by status: ${response.body}');
    }
  }

  /// Update order status using KDS endpoint
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/kds/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': newStatus}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update order status: ${response.body}');
    }
  }
}
