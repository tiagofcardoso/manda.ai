import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../admin/admin_login_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../services/app_translations.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _plateController = TextEditingController();
  bool _loading = false;

  // Vehicle Options
  String _selectedVehicle = 'moto';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Just check if query works, we aren't using data yet
    await _supabase.from('profiles').select().eq('id', userId).single();
    if (mounted) {
      // Load saved vehicle type if exists (mocking for now or using separate column)
      // setState(() {
      //   _selectedVehicle = data['vehicle_type'] ?? 'moto';
      // });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Update logic here
      // await _supabase.from('profiles').update({
      //   'vehicle_type': _selectedVehicle,
      //   'vehicle_plate': _plateController.text,
      // }).eq('id', userId);

      await Future.delayed(const Duration(seconds: 1)); // Mock delay

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile Updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? 'driver@example.com';

    final vehicleOptions = [
      {
        'id': 'moto',
        'label': AppTranslations.of(context, 'moto'),
        'icon': LucideIcons.bike
      },
      {
        'id': 'scooter',
        'label': AppTranslations.of(context, 'scooter'),
        'icon': LucideIcons.bike
      },
      {
        'id': 'bike',
        'label': AppTranslations.of(context, 'bike'),
        'icon': LucideIcons.bike
      },
      {
        'id': 'car',
        'label': AppTranslations.of(context, 'car'),
        'icon': LucideIcons.car
      },
      {
        'id': 'patinete',
        'label': AppTranslations.of(context, 'kickScooter'),
        'icon': LucideIcons.zap
      },
      {
        'id': 'patins',
        'label': AppTranslations.of(context, 'skates'),
        'icon': LucideIcons.footprints
      },
      {
        'id': 'other',
        'label': AppTranslations.of(context, 'otherVehicle'),
        'icon': LucideIcons.helpCircle
      },
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.red),
            onPressed: _logout,
          )
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Icon(LucideIcons.user, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(email,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20)),
              child: Text('Active Driver',
                  style: TextStyle(
                      color: Colors.green[800], fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 32),

            // Vehicle Form
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.of(context, 'vehicleType'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedVehicle,
                      decoration: InputDecoration(
                        labelText: AppTranslations.of(context, 'vehicleType'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(LucideIcons.bike),
                      ),
                      items: vehicleOptions.map((vehicle) {
                        return DropdownMenuItem<String>(
                          value: vehicle['id'] as String,
                          child: Row(
                            children: [
                              Icon(vehicle['icon'] as IconData,
                                  size: 20, color: Colors.blueGrey),
                              const SizedBox(width: 12),
                              Text(vehicle['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedVehicle = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                        labelText: 'License Plate',
                        prefixIcon: Icon(LucideIcons.hash),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Save Changes'),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
