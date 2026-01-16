import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

  @override
  void initState() {
    super.initState();
  }

  final List<Widget> _screens = [
    const MenuScreen(),
    const OrderTrackingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Theme awareness for BottomNav
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: isDark ? Colors.black : Colors.white,
        selectedItemColor: const Color(0xFFE63946),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.utensilsCrossed),
            label: AppTranslations.of(context, 'menu'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.receipt),
            label: AppTranslations.of(context, 'orders'),
          ),
        ],
      ),
    );
  }
}
