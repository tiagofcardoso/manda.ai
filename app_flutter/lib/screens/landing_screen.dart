import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'scan_screen.dart';
import 'admin/admin_login_screen.dart';
import '../services/app_translations.dart';
import '../services/locale_service.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
        valueListenable: LocaleService().localeNotifier,
        builder: (context, locale, _) {
          final isPt = locale.languageCode == 'pt';
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                  child: InkWell(
                    onTap: () {
                      LocaleService().setLocale(Locale(isPt ? 'en' : 'pt'));
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('PT',
                              style: TextStyle(
                                  color: isPt ? Colors.white : Colors.white38,
                                  fontWeight: FontWeight.bold)),
                          const Text(' | ',
                              style: TextStyle(color: Colors.white24)),
                          Text('EN',
                              style: TextStyle(
                                  color: !isPt ? Colors.white : Colors.white38,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/background_manda.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black
                        .withOpacity(0.6), // Dark overlay for readability
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Scan Button (Primary)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ScanScreen()),
                        );
                      },
                      icon: const Icon(LucideIcons.qrCode),
                      label: Text(AppTranslations.of(context, 'scanTable')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. Login Delivery Button (Secondary)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AdminLoginScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(AppTranslations.of(context, 'login')),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
