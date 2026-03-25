import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../widgets/admin/admin_scaffold.dart';
import '../../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService();
  String _connectionType = 'bluetooth';
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _printerService.init();
    setState(() {
      _connectionType = _printerService.connectionType;
      _ipController.text = _printerService.ipAddress;
    });
  }

  Future<void> _saveSettings() async {
    await _printerService.saveSettings(
      type: _connectionType,
      ip: _ipController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas com sucesso! / Settings saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Configurações de Impressora / Printer',
      activeRoute: '/admin-printer',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de Conexão / Connection Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('Bluetooth'),
                    value: 'bluetooth',
                    groupValue: _connectionType,
                    onChanged: (value) => setState(() => _connectionType = value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Rede (TCP/IP)'),
                    value: 'tcp',
                    groupValue: _connectionType,
                    onChanged: (value) => setState(() => _connectionType = value!),
                  ),
                ],
              ),
            ),
          ),
          if (_connectionType == 'tcp') ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Endereço IP da Impressora / Printer IP Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'IP (ex: 192.168.1.100)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.network),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.save),
            label: const Text('Salvar Configurações / Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _saveSettings,
          )
        ],
      ),
    );
  }
}
