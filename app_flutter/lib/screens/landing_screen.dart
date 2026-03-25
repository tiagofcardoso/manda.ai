import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'scan_screen.dart';
import 'admin/admin_login_screen.dart';
import 'marketplace_screen.dart';
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
          backgroundColor: const Color(0xFF0D0D0D),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Language Switcher
                  Align(
                    alignment: Alignment.centerRight,
                    child: _LanguageToggle(isPt: isPt),
                  ),

                  const Spacer(flex: 1),

                  // Logo + Title
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE63946), Color(0xFFAB1E25)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE63946).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: const Icon(LucideIcons.zap,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Manda.AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPt
                              ? 'Peça na mesa ou em casa'
                              : 'Order at the table or at home',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Card 1 — Scan Table (Restaurant)
                  FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 100),
                    child: _ChoiceCard(
                      icon: LucideIcons.qrCode,
                      title: isPt ? 'Estou no Restaurante' : 'I\'m at the Restaurant',
                      subtitle: isPt
                          ? 'Escanear a mesa para pedir'
                          : 'Scan the table to order',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE63946), Color(0xFFAB1E25)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScanScreen())),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card 2 — Delivery
                  FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 200),
                    child: _ChoiceCard(
                      icon: LucideIcons.bike,
                      title: isPt ? 'Pedir em Casa' : 'Order for Delivery',
                      subtitle: isPt
                          ? 'Escolher loja e fazer entrega'
                          : 'Browse stores and get delivery',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderColor: Colors.white12,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MarketplaceScreen())),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Admin/Staff Login — subtle link
                  FadeIn(
                    delay: const Duration(milliseconds: 400),
                    child: Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminLoginScreen())),
                        child: Text(
                          isPt ? 'Entrar como Colaborador' : 'Staff Login',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Small Widgets ──────────────────────────────────────────────────────────

class _LanguageToggle extends StatelessWidget {
  final bool isPt;
  const _LanguageToggle({required this.isPt});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          LocaleService().setLocale(Locale(isPt ? 'en' : 'pt')),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PT',
                style: TextStyle(
                    color: isPt ? Colors.white : Colors.white30,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const Text(' | ',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
            Text('EN',
                style: TextStyle(
                    color: !isPt ? Colors.white : Colors.white30,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final Color borderColor;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.borderColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                color: Colors.white.withOpacity(0.5), size: 22),
          ],
        ),
      ),
    );
  }
}
