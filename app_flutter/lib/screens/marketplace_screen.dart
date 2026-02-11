import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/cart_service.dart';
import 'menu_screen.dart';
import '../services/app_translations.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _establishments = [];
  bool _isLoading = true;
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _fetchEstablishments();
  }

  Future<void> _fetchEstablishments() async {
    try {
      var query =
          _supabase.from('establishments').select().eq('is_active', true);

      if (_selectedType != 'all') {
        query = query.eq('type', _selectedType);
      }

      final response = await query.order('name', ascending: true);

      if (mounted) {
        setState(() {
          _establishments = List<Map<String, dynamic>>.from(response);
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

  void _selectEstablishment(String id, String name) {
    // Set Context
    CartService().setEstablishmentId(id);

    // Clear any previous table session to avoid confusion
    CartService().setDeliveryAddress('Marketplace Selection');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text('Manda.AI',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
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
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Restaurants', 'restaurant'),
                const SizedBox(width: 8),
                _buildFilterChip('Pharmacies', 'pharmacy'),
                const SizedBox(width: 8),
                _buildFilterChip('Grocery', 'grocery'),
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
                            context, 'noProducts'))) // Reuse generic msg
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              2, // Simple 2 col for now, responsive later
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _establishments.length,
                        itemBuilder: (context, index) {
                          final est = _establishments[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: index * 50),
                            child: _buildEstablishmentCard(est),
                          );
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
          _isLoading = true;
        });
        _fetchEstablishments();
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

  Widget _buildEstablishmentCard(Map<String, dynamic> est) {
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
        color = const Color(0xFFEA1D2C);
    }

    return GestureDetector(
      onTap: () => _selectEstablishment(est['id'], est['name']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header / Logo Image
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: est['logo_url'] != null &&
                        est['logo_url'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Image.network(
                          est['logo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to icon if image fails to load
                            return Center(
                              child: Icon(icon, size: 48, color: color),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: color,
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(icon, size: 48, color: color),
                      ),
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      est['name'],
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      est['type'].toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
