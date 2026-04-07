import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// Note: flutter_thermal_printer_pos package is added, but pending exact hardware API details.
// For now, using the PDF fallback per requirements, which works perfectly for Web & native system dialogs.

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  String connectionType = 'bluetooth'; // 'bluetooth' or 'tcp'
  String ipAddress = '';
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    connectionType = prefs.getString('printer_type') ?? 'bluetooth';
    ipAddress = prefs.getString('printer_ip') ?? '';
  }

  Future<void> saveSettings({required String type, required String ip}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_type', type);
    await prefs.setString('printer_ip', ip);
    connectionType = type;
    ipAddress = ip;
  }

  Future<bool> printOrder(Map<String, dynamic> order, String establishmentName) async {
    try {
      debugPrint('PrinterService: Starting print for order ${order['id']}');
      
      // Hardware thermal printer code would go here using flutter_thermal_printer_pos
      // Since hardware might not be available during this execution, we use the PDF fallback
      // which fulfills the web and native printing requirements perfectly using the 'printing' package.
      
      // Safety check: ensure we have at least ID and some data
      if (order['id'] == null) {
        debugPrint('PrinterService Error: Order ID is null');
        return false;
      }

      await _printPdfFallback(order, establishmentName);
      debugPrint('PrinterService: Successfully sent to system print dialog');
      return true;
    } catch (e, stack) {
      debugPrint('PrinterService CRASH: $e');
      debugPrint('Stack trace: $stack');
      return false;
    }
  }

  Future<void> _printPdfFallback(Map<String, dynamic> order, String establishmentName) async {
    final doc = pw.Document();
    
    // Safety checks for order properties
    final items = _normalizeItems(
      _extractRawItems(order),
      orderTotal: double.tryParse((order['total'] ?? order['total_amount'] ?? 0).toString()) ?? 0.0,
    );
    final double total = double.tryParse((order['total'] ?? order['total_amount'] ?? 0).toString()) ?? 0.0;
    final String orderId = (order['id'] ?? 'N/A').toString();
    // Prefer resolved table_number over raw UUID
    final String? tableNumber = order['tables']?['table_number']?.toString() ?? order['table_id']?.toString();
    final String? address = order['delivery_address']?.toString();
    final bool isDelivery = address != null && address.isNotEmpty;
    
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(10), // Small margin for roll printers
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Center(
              child: pw.Text(establishmentName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Pedido #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Data: ${dateFormat.format(DateTime.now())}'),
            pw.SizedBox(height: 8),

            if (tableNumber != null)
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Text('MESA: $tableNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ),
            if (isDelivery) 
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Text('ENTREGA:\n$address', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ),
              
            pw.SizedBox(height: 10),
            pw.Divider(),
            ...items.map((item) {
              final num qty = item['quantity'] ?? 1;
              final String name = item['name'] ?? 'Item';
              final double price = item['price'] ?? 0.0;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pw.Text('${qty}x $name', style: pw.TextStyle(fontSize: 12))),
                    pw.Text(currencyFormat.format(price * qty), style: pw.TextStyle(fontSize: 12)),
                  ]
                )
              );
            }).toList(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text(currencyFormat.format(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text('*** OBRIGADO ***')),
          ],
        );
      }
    ));

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Pedido_$orderId',
    );
  }

  Future<void> printTableBill(List<Map<String, dynamic>> orders, String tableNumber, String establishmentName, double subtotal) async {
    final doc = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(10),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Center(
              child: pw.Text(establishmentName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('CONTA DA MESA $tableNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ),
            pw.Text('Fechamento: ${dateFormat.format(DateTime.now())}'),
            pw.SizedBox(height: 10),
            pw.Divider(),
            ...orders.expand((order) {
              final items = _normalizeItems(
                _extractRawItems(order),
                orderTotal: double.tryParse((order['total'] ?? order['total_amount'] ?? 0).toString()) ?? 0.0,
              );
              final orderId = (order['id'] ?? '').toString();
              return [
                pw.Text('Pedido #${orderId.substring(0, orderId.length > 6 ? 6 : orderId.length)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ...items.map((item) {
                  final num qty = item['quantity'] ?? 1;
                  final String name = item['name'] ?? 'Item';
                  final double price = item['price'] ?? 0.0;
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(child: pw.Text('${qty}x $name', style: const pw.TextStyle(fontSize: 12))),
                        pw.Text(currencyFormat.format(price * qty), style: const pw.TextStyle(fontSize: 12)),
                      ]
                    )
                  );
                }),
                pw.SizedBox(height: 4),
              ];
            }).toList(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SUBTOTAL', style: const pw.TextStyle(fontSize: 14)),
                pw.Text(currencyFormat.format(subtotal), style: const pw.TextStyle(fontSize: 14)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SERVIÇO (10%)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.Text(currencyFormat.format(subtotal * 0.10), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL A PAGAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.Text(currencyFormat.format(subtotal * 1.10), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text('*** OBRIGADO PELA PREFERENCIA ***', style: const pw.TextStyle(fontSize: 10))),
          ],
        );
      }
    ));

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Conta_Mesa_$tableNumber',
    );
  }

  List<dynamic> _extractRawItems(Map<String, dynamic> order) {
    final sources = [
      order['order_items'],
      order['items'],
      order['cart_items'],
    ];
    for (final source in sources) {
      if (source is List) return List<dynamic>.from(source);
    }
    return const <dynamic>[];
  }

  List<Map<String, dynamic>> _normalizeItems(
    List<dynamic> rawItems, {
    double orderTotal = 0.0,
  }) {
    final normalized = <Map<String, dynamic>>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final product = item['products'] is Map
          ? Map<String, dynamic>.from(item['products'])
          : (item['product'] is Map ? Map<String, dynamic>.from(item['product'] as Map) : const <String, dynamic>{});

      final qty = item['quantity'] is num
          ? item['quantity'] as num
          : (num.tryParse((item['quantity'] ?? item['qty'] ?? 1).toString()) ?? 1);

      final originalName = (product['name'] ??
              item['name'] ??
              item['product_name'] ??
              item['title'] ??
              item['product_title'] ??
              'Item')
          .toString();
      // Print default Helvetica only supports Latin1. Strip emojis and special characters.
      final name = originalName.replaceAll(RegExp(r'[^\x00-\x7F\u00C0-\u00FF]'), '').trim();
      final price = _extractItemPrice(item, product, qty);

      normalized.add({
        'quantity': qty,
        'name': name,
        'price': price,
      });
    }

    // Last-resort fallback: if we have total but every item is zero, split by quantity.
    final hasKnownPrice = normalized.any((e) => (e['price'] as double) > 0);
    if (!hasKnownPrice && orderTotal > 0) {
      final totalQty = normalized.fold<num>(0, (sum, e) => sum + ((e['quantity'] as num?) ?? 0));
      if (totalQty > 0) {
        final unit = orderTotal / totalQty;
        for (final item in normalized) {
          item['price'] = unit;
        }
      }
    }

    return normalized;
  }

  double _extractItemPrice(
    Map<String, dynamic> item,
    Map<String, dynamic> product,
    num qty,
  ) {
    final directCandidates = <dynamic>[
      item['price_at_time'],
      item['unit_price'],
      item['unitPrice'],
      item['price'],
      item['value'],
      item['product_price'],
      item['products_price'],
      item['preco'],
      product['price'],
      product['value'],
      product['preco'],
    ];
    for (final candidate in directCandidates) {
      final parsed = _parseMoney(candidate);
      if (parsed != null && parsed > 0) return parsed;
    }

    final lineCandidates = <dynamic>[
      item['line_total'],
      item['subtotal'],
      item['total'],
      item['amount'],
      item['total_price'],
      item['price_total'],
    ];
    for (final candidate in lineCandidates) {
      final parsed = _parseMoney(candidate);
      if (parsed != null && parsed > 0 && qty > 0) return parsed / qty;
    }

    return 0.0;
  }

  double? _parseMoney(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    final normalized = cleaned.contains(',') && !cleaned.contains('.')
        ? cleaned.replaceAll(',', '.')
        : cleaned.replaceAll(',', '');
    return double.tryParse(normalized);
  }
}
