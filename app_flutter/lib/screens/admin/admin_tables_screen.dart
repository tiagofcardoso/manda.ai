import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../widgets/admin/admin_scaffold.dart';

class AdminTablesScreen extends StatefulWidget {
  const AdminTablesScreen({super.key});

  @override
  State<AdminTablesScreen> createState() => _AdminTablesScreenState();
}

class _AdminTablesScreenState extends State<AdminTablesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;
  String? _establishmentId;
  String? _establishmentName;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get establishment for this admin
      final profile = await _supabase
          .from('profiles')
          .select('establishment_id')
          .eq('id', userId)
          .maybeSingle();

      _establishmentId = profile?['establishment_id'];

      if (_establishmentId != null) {
        final est = await _supabase
            .from('establishments')
            .select('name, logo_url')
            .eq('id', _establishmentId!)
            .maybeSingle();
        _establishmentName = est?['name'];
        _logoUrl = est?['logo_url'];

        final tables = await _supabase
            .from('tables')
            .select('id, table_number')
            .eq('establishment_id', _establishmentId!)
            .order('table_number');

        if (mounted) {
          setState(() {
            _tables = List<Map<String, dynamic>>.from(tables);
            _tables.sort((a, b) => (int.tryParse(a['table_number'].toString()) ?? 0).compareTo(int.tryParse(b['table_number'].toString()) ?? 0));
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching tables: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTable() async {
    final tableNumberController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova Mesa', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tableNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número da Mesa *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.hash),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && tableNumberController.text.trim().isNotEmpty) {
      try {
        final tableNumber = int.parse(tableNumberController.text.trim());
        await _supabase.from('tables').insert({
          'establishment_id': _establishmentId,
          'table_number': tableNumber,
        });
        await _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteTable(String tableId, int tableNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar Mesa'),
        content: Text('Deseja apagar a Mesa $tableNumber? O QR code impresso deixará de funcionar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _supabase.from('tables').delete().eq('id', tableId);
      await _fetchData();
    }
  }

  Future<void> _printQR(Map<String, dynamic> table) async {
    final tableNumber = table['table_number'];
    final qrData = 'https://mandaai-c52e9.web.app/#/?est=$_establishmentId&table=$tableNumber';

    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();

          pw.ImageProvider? logoProvider;
          if (_logoUrl != null && _logoUrl!.isNotEmpty) {
            try {
              final response = await http.get(Uri.parse(_logoUrl!));
              if (response.statusCode == 200) {
                logoProvider = pw.MemoryImage(response.bodyBytes);
              }
            } catch (e) {
              debugPrint('Error loading logo for PDF: $e');
            }
          }

          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a5,
              build: (pw.Context ctx) {
                return pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      if (logoProvider != null) ...[
                        pw.Image(logoProvider, width: 64, height: 64),
                        pw.SizedBox(height: 12),
                      ],
                      pw.Text(
                        _establishmentName ?? 'Manda.AI',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Mesa $tableNumber',
                        style: const pw.TextStyle(fontSize: 18),
                      ),
                      pw.SizedBox(height: 24),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 200,
                        height: 200,
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'Escaneie para fazer o pedido',
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
          
          return doc.save();
        },
        name: 'Mesa-$tableNumber-QR.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao imprimir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Gestão de Mesas',
      activeRoute: '/admin-tables',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
          child: ElevatedButton.icon(
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Nova Mesa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _addTable,
          ),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? _buildEmptyState()
              : _buildTableGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.layoutGrid, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Nenhuma mesa cadastrada',
            style: GoogleFonts.outfit(fontSize: 20, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque em "Nova Mesa" para começar',
            style: GoogleFonts.outfit(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.plus),
            label: const Text('Criar Primeira Mesa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _addTable,
          ),
        ],
      ),
    );
  }

  Widget _buildTableGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _tables.length,
      itemBuilder: (context, index) => _buildTableCard(_tables[index]),
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table) {
    final tableNumber = table['table_number'];
    final qrData = 'https://mandaai-c52e9.web.app/#/?est=$_establishmentId&table=$tableNumber';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: _logoUrl != null && _logoUrl!.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(_logoUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.85),
                    BlendMode.lighten,
                  ),
                ),
              )
            : null,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
            Row(
              children: [
                const Icon(LucideIcons.armchair, size: 16, color: Color(0xFFE63946)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mesa $tableNumber',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // QR Preview
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 90,
              ),
            ),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                  tooltip: 'Apagar',
                  onPressed: () => _deleteTable(table['id'], tableNumber),
                ),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.printer, size: 14),
                  label: const Text('Print', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _printQR(table),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
