import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import '../services/app_translations.dart';
import '../services/cart_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false; // Prevent multiple scans

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _processScan(String code) async {
    try {
      Map<String, dynamic>? response;

      // Only try querying by ID if it looks like a UUID (32+ chars)
      // "5" is definitely not a UUID, so this avoids the 22P02 Postgres error.
      if (code.length >= 32) {
        try {
          response = await _supabase
              .from('tables')
              .select('table_number, id')
              .eq('id', code)
              .maybeSingle();
        } catch (_) {
          // If ID query fails (e.g. invalid format despite length), ignore and try table_number
        }
      }

      // If uuid not found or skipped, try table_number
      if (response == null) {
        response = await _supabase
            .from('tables')
            .select('table_number, id')
            .eq('table_number', code.padLeft(2, '0')) // Try "05"
            .maybeSingle();

        // Try exact match "5"
        if (response == null) {
          response = await _supabase
              .from('tables')
              .select('table_number, id')
              .eq('table_number', code)
              .maybeSingle();
        }
      }

      if (response == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${AppTranslations.of(context, 'invalidQR')}: $code'),
                backgroundColor: Colors.red),
          );
          _isScanned = false; // Allow retry
          return;
        }
      }

      final tableNumber = response!['table_number'];

      // Update global CartService so Checkout knows the table!
      CartService().setTableId(tableNumber.toString(),
          explicit: true); // QR scan = explicit

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppTranslations.of(context, 'table')} $tableNumber ${AppTranslations.of(context, 'tableConfirmed')}'),
              backgroundColor: Colors.green),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppTranslations.of(context, 'generalError')} $e'),
              backgroundColor: Colors.red),
        );
        _isScanned = false;
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final code = barcode.rawValue!;
        // Accept ANY code (UUID or "5")
        if (code.isNotEmpty) {
          _isScanned = true;
          _processScan(code);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.of(context, 'scanTable'))),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertTriangle,
                    color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                Text(
                    '${AppTranslations.of(context, 'cameraError')}: ${error.errorCode}'),
              ],
            ),
          );
        },
      ),
    );
  }
}
