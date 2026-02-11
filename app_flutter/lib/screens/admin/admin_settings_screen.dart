import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/settings_service.dart';
import '../../widgets/admin/admin_centered_layout.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = false;

  final List<Map<String, String>> _currencies = [
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': 'R\$'},
    {'code': 'AOA', 'name': 'Angolan Kwanza', 'symbol': 'Kz'},
    {'code': 'CVE', 'name': 'Cape Verdean Escudo', 'symbol': 'CVE'},
    {'code': 'MZN', 'name': 'Mozambican Metical', 'symbol': 'MT'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: AdminCenteredLayout(
        child: ListView(
          children: [
            // Currency Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'General',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(LucideIcons.dollarSign),
                title: const Text('Currency'),
                subtitle: ValueListenableBuilder<String>(
                  valueListenable: _settingsService.currencyNotifier,
                  builder: (context, currency, _) {
                    final currencyData = _currencies.firstWhere(
                      (c) => c['code'] == currency,
                      orElse: () => _currencies[0],
                    );
                    return Text(
                        '${currencyData['name']} (${currencyData['symbol']})');
                  },
                ),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _isLoading ? null : _showCurrencyPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Select Currency', style: theme.textTheme.titleLarge),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<String>(
            valueListenable: _settingsService.currencyNotifier,
            builder: (context, currentCurrency, _) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: _currencies.length,
                itemBuilder: (context, index) {
                  final currency = _currencies[index];
                  final isSelected = currency['code'] == currentCurrency;

                  return ListTile(
                    leading: Text(
                      currency['symbol']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(currency['name']!),
                    subtitle: Text(currency['code']!),
                    trailing: isSelected
                        ? Icon(LucideIcons.check,
                            color: theme.colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () => _updateCurrency(currency['code']!),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCurrency(String currency) async {
    print('🎯 _updateCurrency called with: $currency');
    Navigator.pop(context); // Close dialog

    setState(() => _isLoading = true);

    try {
      print('📞 Calling SettingsService.updateCurrency($currency)');
      await _settingsService.updateCurrency(currency);

      if (mounted) {
        print('✅ Showing success snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Currency updated to $currency'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _updateCurrency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating currency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
