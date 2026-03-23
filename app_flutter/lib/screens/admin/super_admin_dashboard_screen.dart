import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive.dart';
import 'admin_login_screen.dart';
import 'admin_dashboard_screen.dart';
import '../../widgets/admin/admin_centered_layout.dart';
import 'establishment_editor_screen_modern.dart';
import '../../constants/api.dart';
import '../../services/app_translations.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _establishments = [];
  bool _isLoading = true;

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
          .order('created_at', ascending: false);

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

  Future<void> _createEstablishment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EstablishmentEditorScreenModern(),
      ),
    );

    if (result == true) {
      _fetchEstablishments();
    }
  }

  Future<void> _editEstablishment(Map<String, dynamic> establishment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EstablishmentEditorScreenModern(establishment: establishment),
      ),
    );

    if (result == true) {
      _fetchEstablishments();
    }
  }

  Future<void> _deleteEstablishment(String id, String name) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. FIRST CONFIRMATION
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2d2d2d) : Colors.white,
        title: Text(AppTranslations.of(context, 'deleteEstablishment'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text(
            '${AppTranslations.of(context, 'deleteEstablishmentConfirm')} "$name"?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppTranslations.of(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppTranslations.of(context, 'confirmDelete')),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    if (!mounted) return;

    // 2. SECOND CONFIRMATION (Double Check)
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2d2d2d) : Colors.white,
        title: Text(AppTranslations.of(context, 'irreversibleAction'),
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(AppTranslations.of(context, 'irreversibleDeleteMessage'),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppTranslations.of(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppTranslations.of(context, 'confirmDestroy')),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception("No active session");
      }

      // Call Backend to delete safely (bypassing RLS)
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/admin/establishments/$id'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppTranslations.of(context, 'storeDeleted'))),
          );
          _fetchEstablishments();
        }
      } else if (response.statusCode == 409) {
        // Handle Pending Orders Warning (Popup as requested)
        final body = jsonDecode(response.body);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2d2d2d) : Colors.white,
              title: Text(AppTranslations.of(context, 'cannotDelete'),
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertTriangle,
                      color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    body['message'] ??
                        AppTranslations.of(context, 'pendingOrdersWarning'),
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTranslations.of(context, 'resolvePendingOrders'),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppTranslations.of(context, 'ok')),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception("Backend error: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleActive(String id, bool currentStatus) async {
    try {
      await _supabase
          .from('establishments')
          .update({'is_active': !currentStatus}).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Establishment ${!currentStatus ? "activated" : "suspended"}')),
        );
        _fetchEstablishments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _enterAsAdmin(Map<String, dynamic> establishment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update({
        'establishment_id': establishment['id'],
      }).eq('id', userId);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminDashboardScreen(),
        ),
      ).then((_) {
        // Clear context on return
        _supabase.from('profiles').update({
          'establishment_id': null,
        }).eq('id', userId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !Responsive.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1a1a1a) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Super Admin Dashboard', style: GoogleFonts.outfit()),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AdminCenteredLayout(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Establishments',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isDesktop)
                          ElevatedButton.icon(
                            onPressed: _createEstablishment,
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: const Text('New Store'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA1D2C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _establishments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.store,
                                      size: 64,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black12),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No establishments found',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                mainAxisExtent:
                                    220, // Fixed height for consistency
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _establishments.length,
                              itemBuilder: (context, index) {
                                return _buildEstablishmentCard(
                                    _establishments[index], isDark);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: !isDesktop
          ? FloatingActionButton(
              onPressed: _createEstablishment,
              backgroundColor: const Color(0xFFEA1D2C),
              child: const Icon(LucideIcons.plus, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEstablishmentCard(Map<String, dynamic> est, bool isDark) {
    final isActive = est['is_active'] ?? true;
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: isActive
              ? (isDark ? Colors.white10 : Colors.black12)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark ? Colors.white10 : Colors.grey[100])
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(est['type']),
                  color: isActive
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      est['name'],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      est['type']?.toUpperCase() ?? 'UNKNOWN',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(isActive),
            ],
          ),
          const Spacer(),
          Text(
            'Slug: /${est['slug']}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _enterAsAdmin(est),
                  icon: const Icon(LucideIcons.arrowRight, size: 16),
                  label: const Text('Admin Panel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreVertical,
                    color: isDark ? Colors.white54 : Colors.grey),
                color: isDark ? const Color(0xFF333333) : Colors.white,
                onSelected: (value) {
                  if (value == 'toggle') {
                    _toggleActive(est['id'], isActive);
                  } else if (value == 'edit') {
                    _editEstablishment(est);
                  } else if (value == 'delete') {
                    _deleteEstablishment(est['id'], est['name']);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(LucideIcons.edit,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                            isActive
                                ? LucideIcons.pauseCircle
                                : LucideIcons.playCircle,
                            size: 18,
                            color: isActive ? Colors.orange : Colors.green),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Suspend' : 'Activate',
                            style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(LucideIcons.trash2,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'SUSPENDED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'restaurant':
        return LucideIcons.utensils;
      case 'pharmacy':
        return LucideIcons.pill;
      case 'grocery':
        return LucideIcons.shoppingBag;
      case 'shop':
        return LucideIcons.shoppingBag;
      default:
        return LucideIcons.store;
    }
  }
}
