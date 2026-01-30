import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:ui';
import '../../services/app_translations.dart';
import '../../services/locale_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
        setState(() => _isScrolled = false);
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
    final bool isDesktop =
        screenSize.width > 900; // Increased breakpoint for tablet safety

    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService().localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A), // Slate 900
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size(screenSize.width, 80),
            child: _buildGlassAppBar(context, isDesktop),
          ),
          body: Stack(
            children: [
              // Background Gradient Blobs
              Positioned(
                top: -100,
                right: -100,
                child: FadeIn(
                    duration: const Duration(seconds: 2),
                    child: _buildGradientBlob(Colors.purpleAccent, 500)),
              ),
              Positioned(
                bottom: -150,
                left: -150,
                child: FadeIn(
                    duration: const Duration(seconds: 3),
                    child: _buildGradientBlob(Colors.blueAccent, 600)),
              ),
              Positioned(
                top: screenSize.height * 0.4,
                left: screenSize.width * 0.2,
                child: FadeIn(
                    duration: const Duration(seconds: 4),
                    child: _buildGradientBlob(
                        Colors.pinkAccent.withOpacity(0.4), 300)),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),

              // Scrollable Content
              SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: isDesktop ? 140 : 120),
                    _buildHeroSection(context, isDesktop),
                    const SizedBox(height: 120),
                    _buildFeaturesSection(context, isDesktop),
                    const SizedBox(height: 120),
                    _buildSocialProofSection(context, isDesktop),
                    const SizedBox(height: 120),
                    _buildFooter(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassAppBar(BuildContext context, bool isDesktop) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _isScrolled
              ? const Color(0xFF0F172A).withOpacity(0.8)
              : Colors.transparent,
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 80 : 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Row(
                children: [
                  FadeInLeft(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber, // Brand color
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.zap,
                          color: Colors.black, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FadeInLeft(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      AppTranslations.of(context, 'appTitle'),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),

              // Nav Buttons
              Row(
                children: [
                  // Language Toggle
                  InkWell(
                    onTap: () {
                      final current = LocaleService().localeNotifier.value;
                      LocaleService().setLocale(
                          Locale(current.languageCode == 'pt' ? 'en' : 'pt'));
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: Row(
                        children: [
                          Text('PT',
                              style: TextStyle(
                                  color: LocaleService()
                                              .localeNotifier
                                              .value
                                              .languageCode ==
                                          'pt'
                                      ? Colors.white
                                      : Colors.white38,
                                  fontWeight: FontWeight.bold)),
                          const Text(' | ',
                              style: TextStyle(color: Colors.white24)),
                          Text('EN',
                              style: TextStyle(
                                  color: LocaleService()
                                              .localeNotifier
                                              .value
                                              .languageCode !=
                                          'pt'
                                      ? Colors.white
                                      : Colors.white38,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  if (isDesktop) ...[
                    // Desktop Menu
                    FadeInDown(
                        delay: const Duration(milliseconds: 200),
                        child: _NavButton(
                            title: AppTranslations.of(context, 'navFeatures'),
                            onTap: () {})),
                    FadeInDown(
                        delay: const Duration(milliseconds: 300),
                        child: _NavButton(
                            title: "Pricing", onTap: () {})), // Placeholder
                    FadeInDown(
                        delay: const Duration(milliseconds: 400),
                        child: _NavButton(
                            title: "Contact", onTap: () {})), // Placeholder
                    const SizedBox(width: 24),
                    FadeInRight(
                      delay: const Duration(milliseconds: 500),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFE63946), // Primary Red
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: Text(AppTranslations.of(context, 'login'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 120 : 24),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: _buildHeroText(context, true)),
                const SizedBox(width: 60),
                Expanded(flex: 6, child: _buildHeroImage(context)),
              ],
            )
          : Column(
              children: [
                _buildHeroImage(context),
                const SizedBox(height: 60),
                _buildHeroText(context, false),
              ],
            ),
    );
  }

  Widget _buildHeroText(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        FadeInDown(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sparkles, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.of(context, 'landingHeroBadge'),
                  style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          child: Text(
            AppTranslations.of(context, 'landingTitle'),
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: isDesktop ? 72 : 48,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          child: Text(
            AppTranslations.of(context, 'landingDesc'),
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: Colors.blueGrey, // Better contrast than white70
              fontSize: 18,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 48),
        FadeInUp(
          delay: const Duration(milliseconds: 600),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
            children: [
              _StoreButton(
                icon: LucideIcons.apple,
                label: 'App Store',
                onTap: () {},
                isPrimary: true,
              ),
              _StoreButton(
                icon: LucideIcons.play,
                label: 'Google Play',
                onTap: () {},
                isPrimary: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FadeInUp(
          delay: const Duration(milliseconds: 800),
          child: Row(
            mainAxisAlignment:
                isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              _buildTrustedAvatar('https://i.pravatar.cc/100?img=1'),
              _buildTrustedAvatar('https://i.pravatar.cc/100?img=3'),
              _buildTrustedAvatar('https://i.pravatar.cc/100?img=12'),
              _buildTrustedAvatar('https://i.pravatar.cc/100?img=5'),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("1,000+",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text("Happy Restaurants",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTrustedAvatar(String url) {
    return Align(
      widthFactor: 0.7,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
            color: Color(0xFF0F172A), shape: BoxShape.circle),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[800],
          // backgroundImage: NetworkImage(url), // Commented out to avoid error if offline
          child: const Icon(Icons.person, size: 16, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return FadeInRight(
      duration: const Duration(seconds: 1),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Background Glow
            Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE63946).withOpacity(0.4),
                    Colors.transparent
                  ],
                  stops: const [0, 0.7],
                ),
              ),
            ),

            // Glass Card (Simulating Dashboard)
            Transform.rotate(
              angle: -0.1, // Slight tilt
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 380,
                    height: 600,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 0),
                        ]),
                    child: Column(
                      children: [
                        // Fake Header
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.white12))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(LucideIcons.menu,
                                  color: Colors.white54),
                              Container(
                                  width: 100,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(4))),
                              const Icon(LucideIcons.bell,
                                  color: Colors.white54),
                            ],
                          ),
                        ),
                        // Fake Chart
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Daily Revenue",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 8),
                              const Text("\$1,240.50",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12))),
                              const SizedBox(height: 20),
                              // List Items
                              _buildFakeListItem(),
                              _buildFakeListItem(),
                              _buildFakeListItem(),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Elements
            Positioned(
              right: -40,
              top: 100,
              child: BounceInDown(
                delay: const Duration(seconds: 1),
                child: _buildFloatingCard(
                    icon: LucideIcons.timer,
                    color: Colors.orange,
                    title: "Avg Time",
                    subtitle: "12m 30s"),
              ),
            ),

            Positioned(
              left: -40,
              bottom: 100,
              child: BounceInUp(
                delay: const Duration(seconds: 1),
                child: _buildFloatingCard(
                    icon: LucideIcons.trendingUp,
                    color: Colors.green,
                    title: "Growth",
                    subtitle: "+24.5%"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFakeListItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 80,
                  height: 8,
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  width: 50,
                  height: 8,
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFloatingCard(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ]),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isDesktop) {
    final List<Map<String, dynamic>> features = [
      {
        'title': AppTranslations.of(context, 'featureKitchen'),
        'desc': AppTranslations.of(context, 'featureKitchenDesc'),
        'icon': LucideIcons.chefHat,
        'color': Colors.orangeAccent
      },
      {
        'title': AppTranslations.of(context, 'featureDriver'),
        'desc': AppTranslations.of(context, 'featureDriverDesc'),
        'icon': LucideIcons.bike,
        'color': Colors.blueAccent
      },
      {
        'title': AppTranslations.of(context, 'featureAdmin'),
        'desc': AppTranslations.of(context, 'featureAdminDesc'),
        'icon': LucideIcons.layoutDashboard,
        'color': Colors.purpleAccent
      },
      {
        'title': "QR Ordering",
        'desc': "Seamless table ordering for your customers.",
        'icon': LucideIcons.qrCode,
        'color': Colors.greenAccent
      },
    ];

    return Column(
      children: [
        FadeInUp(
          child: Text(
            AppTranslations.of(context, 'whyManda'),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 60),
        CarouselSlider(
          options: CarouselOptions(
            height: 320,
            viewportFraction: isDesktop ? 0.25 : 0.85,
            initialPage: 0,
            enableInfiniteScroll: true,
            reverse: false,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 1000),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            scrollDirection: Axis.horizontal,
          ),
          items: features.map((feature) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 10.0),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white10),
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.transparent
                          ])),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (feature['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(feature['icon'],
                            size: 32, color: feature['color']),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        feature['title'],
                        style: const TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        feature['desc'],
                        style: const TextStyle(
                            fontSize: 16.0, color: Colors.grey, height: 1.5),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSocialProofSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
          border: Border.symmetric(
              horizontal: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Column(
        children: [
          const Text("TRUSTED BY INNOVATIVE TEAMS",
              style: TextStyle(
                  color: Colors.grey,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Wrap(
            spacing: isDesktop ? 60 : 30,
            runSpacing: 30,
            alignment: WrapAlignment.center,
            children: [
              _buildLogoPlaceholder("Brand A"),
              _buildLogoPlaceholder("Brand B"),
              _buildLogoPlaceholder("Brand C"),
              _buildLogoPlaceholder("Brand D"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder(String text) {
    return Opacity(
      opacity: 0.5,
      child: Text(text,
          style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 80, bottom: 40, left: 40, right: 40),
      color: Colors.black,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.zap, color: Colors.amber),
              const SizedBox(width: 8),
              Text("Manda.AI",
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 40),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text(
            '© 2024 Manda.AI. All rights reserved.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.3), Colors.transparent],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        child: Text(
          title,
          style: const TextStyle(
              color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _StoreButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
            color: isPrimary ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isPrimary ? Colors.transparent : Colors.white24,
                width: 2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24, color: isPrimary ? Colors.black : Colors.white),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? Colors.black : Colors.white)),
          ],
        ),
      ),
    );
  }
}
