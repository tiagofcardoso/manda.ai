import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/cart_service.dart';
import 'main_screen.dart'; // Changed from menu_screen
import '../services/app_translations.dart';
import '../services/auth_service.dart';
import 'scan_screen.dart';
import 'landing_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allEstablishments = [];
  List<Map<String, dynamic>> _establishments = [];
  Set<String> _availableTypes = {};
  bool _isLoading = true;
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _fetchEstablishments();
  }

  Future<void> _fetchEstablishments() async {
    try {
      final response = await _supabase
          .from('establishments')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _allEstablishments = List<Map<String, dynamic>>.from(response);
          _availableTypes = _allEstablishments
              .map((e) => e['type'].toString())
              .where((type) => type.isNotEmpty)
              .toSet();
          _filterEstablishments();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterEstablishments() {
    if (_selectedType == 'all') {
      _establishments = List.from(_allEstablishments);
    } else {
      _establishments = _allEstablishments
          .where((e) => e['type'].toString() == _selectedType)
          .toList();
    }
  }

  void _selectEstablishment(String id, String name) {
    // Set Context
    CartService().setEstablishmentId(id);

    // Clear any previous table session to avoid confusion
    CartService().setDeliveryAddress('Marketplace Selection');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              color: Colors.white,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(24),
              child: Text(
                'Manda.AI',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE63946),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.qrCode),
              title: Text(AppTranslations.of(context, 'scanTable') == 'scanTable' ? 'Ler QR' : AppTranslations.of(context, 'scanTable')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.bike),
              title: Text(AppTranslations.of(context, 'orderHome') == 'orderHome' ? 'Entregar' : AppTranslations.of(context, 'orderHome')),
              onTap: () {
                Navigator.pop(context); // Already on marketplace
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.logOut, color: Colors.grey),
              title: Text(AppTranslations.of(context, 'logout') == 'logout' ? 'Sair' : AppTranslations.of(context, 'logout'), style: const TextStyle(color: Colors.grey)),
              onTap: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('Manda.AI',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(AppTranslations.of(context, 'catAll'), 'all'),
                ..._availableTypes.map((type) {
                  // Format label using translation keys like 'typeRestaurant'
                  if (type.isEmpty) return const SizedBox.shrink();
                  final typeKey = 'type${type[0].toUpperCase()}${type.substring(1).toLowerCase()}';
                  final translated = AppTranslations.of(context, typeKey);
                  // Fallback to capitalized DB string if translation not found
                  final label = translated == typeKey 
                      ? (type[0].toUpperCase() + type.substring(1).toLowerCase())
                      : translated;
                  
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildFilterChip(label, type),
                  );
                }),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEA1D2C)))
                : _establishments.isEmpty
                    ? Center(
                        child: Text(AppTranslations.of(
                            context, 'noEstablishments'), style: const TextStyle(color: Colors.grey))) // Reuse generic msg
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          
                          if (isMobile) {
                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              itemCount: _establishments.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 20),
                              itemBuilder: (context, index) {
                                final est = _establishments[index];
                                return FadeInUp(
                                  delay: Duration(milliseconds: index * 50),
                                  child: _buildEstablishmentCard(est, isMobile: true),
                                );
                              },
                            );
                          } else {
                            return GridView.builder(
                              padding: const EdgeInsets.all(20),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                              ),
                              itemCount: _establishments.length,
                              itemBuilder: (context, index) {
                                final est = _establishments[index];
                                return FadeInUp(
                                  delay: Duration(milliseconds: index * 50),
                                  child: _buildEstablishmentCard(est, isMobile: false),
                                );
                              },
                            );
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedType = value;
          _filterEstablishments();
        });
      },
      selectedColor: const Color(0xFFEA1D2C),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEstablishmentCard(Map<String, dynamic> est, {bool isMobile = true}) {
    IconData icon;
    Color color;

    switch (est['type']) {
      case 'pharmacy':
        icon = LucideIcons.pill;
        color = Colors.blue;
        break;
      case 'grocery':
        icon = LucideIcons.shoppingBag;
        color = Colors.green;
        break;
      default:
        icon = LucideIcons.utensils;
        color = const Color(0xFFE63946);
    }

    // Mock Rating and Time for UI purposes
    final rating = '4.9'; 
    final deliveryTime = '30-40 min';

    return GestureDetector(
      onTap: () => _selectEstablishment(est['id'], est['name']),
      child: Container(
        height: isMobile ? 220 : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header / Logo Image
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: est['logo_url'] != null && est['logo_url'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Image.network(
                              est['logo_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(child: Icon(icon, size: 48, color: color)),
                            ),
                          )
                        : Center(child: Icon(icon, size: 48, color: color)),
                  ),
                  
                  // Favorite Button (Mock)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.heart, size: 18, color: Colors.grey),
                    ),
                  ),

                  // Delivery Time Badge
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        deliveryTime,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          est['name'],
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final rawType = est['type'].toString();
                            final typeKey = rawType.isNotEmpty 
                                ? 'type${rawType[0].toUpperCase()}${rawType.substring(1).toLowerCase()}' 
                                : 'typeOther';
                            final translated = AppTranslations.of(context, typeKey);
                            final displayType = translated == typeKey ? rawType : translated;
                            
                            return Text(
                              displayType.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 1.0,
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  // Rating Badge 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          rating,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.star, size: 14, color: Color(0xFFFFB300)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
