import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:ui';
import 'video_autoplay_widget.dart';
import '../../services/app_translations.dart';
import '../../services/locale_service.dart';
import '../marketplace_screen.dart';
import '../main_screen.dart';
import '../../services/cart_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  // Modern Brand Colors
  final Color _brandRed = const Color(0xFFEA1D2C); // iFood Red
  final Color _textDark = const Color(0xFF1F1F1F);
  final Color _bgLight = const Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 20 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 20 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    // Check URL parameters for QR Table Code
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('est') &&
          uri.queryParameters.containsKey('table')) {
        final estId = uri.queryParameters['est']!;
        final tableNum = uri.queryParameters['table']!;

        // Auto-login to table context
        CartService().setEstablishmentId(estId);
        CartService().setTableId(tableNum, explicit: true);

        // Show PWA install prompt then navigate directly
        _showInstallInstructions(context, thenNavigate: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isDesktop = screenSize.width > 900;

    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService().localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7), // Soft background
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size(screenSize.width, 80),
            child: _buildStickyHeader(context, isDesktop),
          ),
          body: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                _buildHeroSection(context, isDesktop),
                _buildMainCardsSection(
                    context, isDesktop), // The Big Red/Green Cards
                _buildAppDownloadSection(context, isDesktop),
                _buildFooter(context, isDesktop),
              ],
            ),
          ),
        );
      },
    );
  }

  // 1. Header (Sticky, clean white)
  Widget _buildStickyHeader(BuildContext context, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: _isScrolled ? Colors.white : Colors.transparent,
        boxShadow: _isScrolled
            ? [
                const BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))
              ]
            : null,
      ),
      padding:
          EdgeInsets.symmetric(horizontal: isDesktop ? 120 : 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          FadeInLeft(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brandRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.zap,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  'Manda.AI',
                  style: GoogleFonts.outfit(
                    color: _brandRed,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Right Actions
          Row(
            children: [
              if (isDesktop) _buildLanguageSwitch(),
              if (isDesktop) const SizedBox(width: 24),
              if (isDesktop)
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      AppTranslations.of(context, 'iWantToDeliver'),
                      style: TextStyle(
                          color: _textDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (isDesktop) const SizedBox(width: 16),
              FadeInRight(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16, 
                        vertical: isDesktop ? 18 : 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/admin'),
                  child: Text(AppTranslations.of(context, 'login'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSwitch() {
    final isPt = LocaleService().localeNotifier.value.languageCode == 'pt';
    return InkWell(
      onTap: () => LocaleService().setLocale(Locale(isPt ? 'en' : 'pt')),
      child: Row(
        children: [
          Text('PT',
              style: TextStyle(
                  color: isPt ? _brandRed : Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Text('|', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 4),
          Text('EN',
              style: TextStyle(
                  color: !isPt ? _brandRed : Colors.grey,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 2. Hero Section (Centered & Search Focused)
  Widget _buildHeroSection(BuildContext context, bool isDesktop) {
    // Assets for the background carousel
    final List<Widget> carouselItems = [
      Image.asset('assets/images/barca_sushi.png', fit: BoxFit.cover),
      Image.asset('assets/images/classic_smash.png', fit: BoxFit.cover),
      Image.asset('assets/images/babidas.png', fit: BoxFit.cover),
      Image.asset('assets/images/craft_ipa.png', fit: BoxFit.cover),
      const VideoAutoplayWidget(
          assetPath: 'assets/videos/entrega.mp4'), // Reuse our video widget
      Image.asset('assets/images/mercado.png', fit: BoxFit.cover),
      Image.asset('assets/images/petshop.png', fit: BoxFit.cover),
    ];

    return SizedBox(
      height: isDesktop ? 700 : 600, // Fixed height for carousel area
      child: Stack(
        children: [
          // 1. Carousel Background
          SizedBox.expand(
            child: CarouselSlider(
              options: CarouselOptions(
                height: double.infinity,
                viewportFraction: 1.0,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 5),
                autoPlayAnimationDuration: const Duration(seconds: 2),
                scrollPhysics:
                    const NeverScrollableScrollPhysics(), // interactions disabled
              ),
              items: carouselItems.map((item) {
                return SizedBox(
                  width: double.infinity,
                  child: item,
                );
              }).toList(),
            ),
          ),

          // 2. Overlay to ensure text readability (Darker for white text)
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          // 3. Content
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: isDesktop ? 80 : 60,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        AppTranslations.of(
                            context, 'landingTitle'), // "Tudo pra facilitar..."
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 64 : 36, // Smaller for mobile
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeInDown(
                      delay: const Duration(milliseconds: 200),
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        constraints: const BoxConstraints(
                            maxWidth: 800), // Widen text area
                        child: Text(
                          AppTranslations.of(context,
                              'landingDesc'), // "O que você precisa está aqui..."
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isDesktop ? 24 : 18, 
                            color: Colors.white.withOpacity(0.9), 
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Main Cards Section (Restaurant vs Market)
  Widget _buildMainCardsSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F7F7), // Soft Off-White
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? (MediaQuery.of(context).size.width - 1000) / 2
              : 20, // Center content max 1000px
          vertical: 40),
      child: Column(
        children: [
          // Big Cards Row
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                        child: FadeInLeft(
                      delay: const Duration(milliseconds: 600),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
                        child: _HoverScaleCard(
                          child: _buildBigCard(
                            title: AppTranslations.of(context, 'restaurant'),
                            label: AppTranslations.of(context, 'viewOptions'),
                            color: _brandRed,
                            icon: LucideIcons.utensils,
                            imageAsset:
                                'assets/images/barca_sushi.png', // Sushi Boat
                          ),
                        ),
                      ),
                    )),
                    const SizedBox(width: 24),
                    Expanded(
                        child: FadeInRight(
                      delay: const Duration(milliseconds: 600),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
                        child: _HoverScaleCard(
                          child: _buildBigCard(
                            title: AppTranslations.of(context, 'market'),
                            label: AppTranslations.of(context, 'browseStores'),
                            color: const Color(0xFFB5D040), // Lime Green
                            textColor: const Color(0xFF3F3F3F),
                            icon: LucideIcons.shoppingBag,
                            overlayColor: Colors.white.withOpacity(0.3),
                            imageAsset:
                                'assets/images/mercado.png', // Market Image
                          ),
                        ),
                      ),
                    )),
                  ],
                )
              : Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
                      child: _buildBigCard(
                        title: AppTranslations.of(context, 'restaurant'),
                        label: AppTranslations.of(context, 'viewOptions'),
                        color: _brandRed,
                        icon: LucideIcons.utensils,
                        imageAsset: 'assets/images/barca_sushi.png',
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
                      child: _buildBigCard(
                        title: AppTranslations.of(context, 'market'),
                        label: AppTranslations.of(context, 'browseStores'),
                        color: const Color(0xFFB5D040),
                        textColor: const Color(0xFF3F3F3F),
                        icon: LucideIcons.shoppingBag,
                        imageAsset: 'assets/images/mercado.png',
                      ),
                    ),
                  ],
                ),

          const SizedBox(height: 60),

          // Small Category Pills Row
          // Bebidas, Farmacia, Pet Shop...
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: _buildSmallCategoryCard(
                      AppTranslations.of(context, 'drinks'),
                      LucideIcons.beer,
                      Colors.amber[50]!,
                      imageAsset: 'assets/images/babidas.png')),
              FadeInUp(
                  delay: const Duration(milliseconds: 900),
                  child: _buildSmallCategoryCard(
                      AppTranslations.of(context, 'pharmacy'),
                      LucideIcons.pill,
                      Colors.pink[50]!,
                      imageAsset: 'assets/images/farmacia.png')),
              FadeInUp(
                  delay: const Duration(milliseconds: 1000),
                  child: _buildSmallCategoryCard(
                      AppTranslations.of(context, 'petShop'),
                      LucideIcons.dog,
                      Colors.purple[50]!,
                      imageAsset: 'assets/images/petshop.png')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBigCard({
    required String title,
    required String label,
    required Color color,
    required IconData icon,
    Color textColor = Colors.white,
    Color? overlayColor,
    String? imageAsset,
  }) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: overlayColor ?? Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Icon Background
          Positioned(
              bottom: -20,
              right: -20,
              child: imageAsset != null
                  ? Transform.rotate(
                      angle: -0.2,
                      child: Image.asset(imageAsset,
                          height: 180, fit: BoxFit.contain),
                    )
                  : Transform.rotate(
                      angle: -0.2,
                      child: Icon(icon,
                          size: 160, color: Colors.black.withOpacity(0.05)),
                    )),
          // Icon Foreground
          if (imageAsset == null)
            Positioned(
              bottom: 20,
              right: 20,
              child: Icon(icon, size: 80, color: textColor.withOpacity(0.9)),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallCategoryCard(String label, IconData icon, Color bgColor,
      {String? imageAsset}) {
    return _HoverScaleCard(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              image: imageAsset != null
                  ? DecorationImage(
                      image: AssetImage(imageAsset), fit: BoxFit.cover)
                  : null,
            ),
            child: imageAsset == null
                ? Icon(icon, color: Colors.black87, size: 32)
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight, size: 14, color: Colors.red)
            ],
          )
        ],
      ),
    );
  }

  // 5. App Download
  Widget _buildAppDownloadSection(BuildContext context, bool isDesktop) {
    return Container(
      padding:
          EdgeInsets.symmetric(vertical: 80, horizontal: isDesktop ? 120 : 24),
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: EdgeInsets.all(isDesktop ? 48 : 24),
          decoration: BoxDecoration(
            color: _textDark,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Entrega Ágil e Transparente",
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: isDesktop ? 40 : 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(
                        "Da cozinha até sua porta, acompanhe sua entrega em tempo real com nossa frota dedicada.",
                        style: TextStyle(color: Colors.grey, fontSize: isDesktop ? 18 : 16)),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStoreBadge(context, LucideIcons.apple, "App Store"),
                        _buildStoreBadge(context, LucideIcons.play, "Google Play"),
                      ],
                    )
                  ],
                ),
              ),
              if (isDesktop)
                Expanded(
                  child: Transform.rotate(
                    angle: 0.05,
                    child: const VideoAutoplayWidget(
                      assetPath: 'assets/videos/entrega.mp4',
                      height: 400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreBadge(BuildContext context, IconData icon, String text) {
    return InkWell(
      onTap: () => _showInstallInstructions(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _textDark),
            const SizedBox(width: 8),
            Text(text,
                style: TextStyle(color: _textDark, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showInstallInstructions(BuildContext context, {bool thenNavigate = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(LucideIcons.download, color: _brandRed),
              const SizedBox(width: 8),
              const Text("Instalar App"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("O Manda.AI é um Web App leve e rápido! Instale direto no seu celular:", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              const Text("🍏 No iPhone/iPad (Safari):", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("1. Toque no ícone de Compartilhar (baixo da tela)."),
              const Text("2. Selecione 'Adicionar à Tela de Início'."),
              const SizedBox(height: 16),
              const Text("🤖 No Android (Chrome):", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("1. Toque nos 3 pontinhos ⋮ (canto superior direito)."),
              const Text("2. Selecione 'Instalar aplicativo' ou 'Adicionar à tela de início'."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (thenNavigate) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                  );
                }
              },
              child: Text("Entendi / Continuar", style: TextStyle(fontWeight: FontWeight.bold, color: _brandRed)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, bool isDesktop) {
    return Container(
      padding:
          EdgeInsets.symmetric(vertical: 60, horizontal: isDesktop ? 120 : 20),
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(LucideIcons.zap, color: _textDark),
                const SizedBox(width: 8),
                Text("Manda.AI",
                    style: GoogleFonts.outfit(
                        fontSize: 24, fontWeight: FontWeight.bold))
              ]),
              const Text("© 2024 Manda.AI"),
            ],
          )
        ],
      ),
    );
  }
}

// Widget Helper for Hover Animation
class _HoverScaleCard extends StatefulWidget {
  final Widget child;
  const _HoverScaleCard({required this.child});

  @override
  State<_HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<_HoverScaleCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
