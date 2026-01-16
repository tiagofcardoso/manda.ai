import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'scan_screen.dart';
import 'main_screen.dart';
import '../services/table_service.dart';
import '../services/app_translations.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_manda.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6), // Dark overlay for readability
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Placeholder
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE63946),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.utensils,
                    size: 64, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const SizedBox(height: 32),
              Text(
                AppTranslations.of(context, 'welcomeMessage'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.of(context, 'scanInstruction'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 48),

              // Scan Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanScreen()),
                  );
                },
                icon: const Icon(LucideIcons.qrCode),
                label: Text(AppTranslations.of(context, 'scanTable')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 16),

              // Demo/Skip Button
              TextButton(
                onPressed: () {
                  // Set Dummy Table ID for testing
                  TableService().setTable(
                      '11111111-1111-1111-1111-111111111111', '01 (Demo)');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                  );
                },
                child: Text(AppTranslations.of(context, 'skipDemo'),
                    style: const TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
