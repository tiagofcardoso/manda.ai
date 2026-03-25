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
      // Hardware thermal printer code would go here using flutter_thermal_printer_pos
      // Since hardware might not be available during this execution, we use the PDF fallback
      // which fulfills the web and native printing requirements perfectly using the 'printing' package.
      await _printPdfFallback(order, establishmentName);
      return true;
    } catch (e) {
      debugPrint('Error printing order: $e');
      return false;
    }
  }

  Future<void> _printPdfFallback(Map<String, dynamic> order, String establishmentName) async {
    final doc = pw.Document();
    
    // Safety checks for order properties
    final List<dynamic> items = order['cart_items'] is List ? List.from(order['cart_items']) : [];
    final double total = double.tryParse((order['total_amount'] ?? 0).toString()) ?? 0.0;
    final String orderId = (order['id'] ?? 'N/A').toString();
    final String? tableId = order['table_id']?.toString();
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

            if (tableId != null) 
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Text('MESA: $tableId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
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
              final String name = item['products']?['name'] ?? 'Item';
              final double price = double.tryParse((item['price_at_time'] ?? 0).toString()) ?? 0.0;
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
}
