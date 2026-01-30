import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'menu_screen.dart';
import 'order_tracking_screen.dart';
import 'package:manda_client/services/app_translations.dart';
import '../widgets/app_drawer.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MenuScreen(),
    const OrderTrackingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Theme awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // Important for floating nav bar
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Background (Optional Global Gradient if needed, otherwise handled by screens)
          _screens[_currentIndex],

          // Floating Glass Bottom Navigation
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 +
                MediaQuery.of(context).viewPadding.bottom, // Respect Safe Area
            child: FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.6)
                          : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: LucideIcons.utensilsCrossed,
                          label: AppTranslations.of(context, 'menu'),
                          isSelected: _currentIndex == 0,
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: LucideIcons.receipt,
                          label: AppTranslations.of(context, 'orders'),
                          isSelected: _currentIndex == 1,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE63946).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFE63946)
                  : (isDark ? Colors.white54 : Colors.black54),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              FadeInRight(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE63946),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
