import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
    final bool isDesktop = screenSize.width > 800;

    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService().localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: Colors.black, // Dark theme base
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
                child: _buildGradientBlob(Colors.purple, 400),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: _buildGradientBlob(Colors.blue, 400),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),

              // Scrollable Content
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(height: isDesktop ? 120 : 100),
                    _buildHeroSection(context, isDesktop),
                    SizedBox(height: 100),
                    _buildFeaturesSection(context, isDesktop),
                    SizedBox(height: 100),
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
        child: Container(
          color:
              _isScrolled ? Colors.black.withOpacity(0.6) : Colors.transparent,
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 50 : 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Row(
                children: [
                  Icon(LucideIcons.zap, color: Colors.amber, size: 32),
                  SizedBox(width: 8),
                  Text(
                    AppTranslations.of(context, 'appTitle'),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.1),
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
                          Text(' | ', style: TextStyle(color: Colors.white24)),
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
                  SizedBox(width: 10),

                  if (isDesktop) ...[
                    _NavButton(
                        title: AppTranslations.of(context, 'navFeatures'),
                        onTap: () {}),
                    _NavButton(
                        title: AppTranslations.of(context, 'navDrivers'),
                        onTap: () {}),
                    _NavButton(
                        title: AppTranslations.of(context, 'navRestaurants'),
                        onTap: () {}),
                    SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text(AppTranslations.of(context, 'login'),
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ] else
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        // Mobile Drawer or Menu
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
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 100 : 20),
      child: isDesktop
          ? Row(
              children: [
                Expanded(child: _buildHeroText(context, true)),
                Expanded(child: _buildHeroImage(context)),
              ],
            )
          : Column(
              children: [
                _buildHeroText(context, false),
                SizedBox(height: 50),
                _buildHeroImage(context),
              ],
            ),
    );
  }

  Widget _buildHeroText(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            AppTranslations.of(context, 'landingHeroBadge'),
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        Text(
          AppTranslations.of(context, 'landingTitle'),
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: isDesktop ? 64 : 42,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 20),
        Text(
          AppTranslations.of(context, 'landingDesc'),
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            height: 1.5,
          ),
        ),
        SizedBox(height: 40),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _StoreButton(
              icon: LucideIcons.apple,
              label: 'App Store',
              onTap: () {},
            ),
            _StoreButton(
              icon: LucideIcons.play,
              label: 'Google Play',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double w = screenSize.width > 800 ? 400 : screenSize.width * 0.8;
    final double h = screenSize.width > 800 ? 500 : w * 1.5;

    return Container(
        height: h.clamp(300.0, 500.0), // Min 300, Max 500
        width: w.clamp(250.0, 400.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Simulated Phone Screen
            Container(
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Icon(LucideIcons.layoutDashboard,
                    color: Colors.blue, size: 80),
              ),
            ),
            Positioned(
              bottom: 40,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.5), blurRadius: 20)
                    ]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.checkCircle,
                        color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text("Order #1024 Ready",
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildFeaturesSection(BuildContext context, bool isDesktop) {
    final List<Map<String, dynamic>> features = [
      {
        'title': AppTranslations.of(context, 'featureKitchen'),
        'desc': AppTranslations.of(context, 'featureKitchenDesc'),
        'icon': LucideIcons.chefHat,
        'color': Colors.orange
      },
      {
        'title': AppTranslations.of(context, 'featureDriver'),
        'desc': AppTranslations.of(context, 'featureDriverDesc'),
        'icon': LucideIcons.mapPin,
        'color': Colors.blue
      },
      {
        'title': AppTranslations.of(context, 'featureAdmin'),
        'desc': AppTranslations.of(context, 'featureAdminDesc'),
        'icon': LucideIcons.barChart,
        'color': Colors.purple
      },
    ];

    return Column(
      children: [
        Text(
          AppTranslations.of(context, 'whyManda'),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 50),
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            aspectRatio: 16 / 9,
            viewportFraction: isDesktop ? 0.3 : 0.8,
            initialPage: 0,
            enableInfiniteScroll: true,
            reverse: false,
            autoPlay: true,
            autoPlayInterval: Duration(seconds: 3),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            scrollDirection: Axis.horizontal,
          ),
          items: features.map((feature) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: EdgeInsets.symmetric(horizontal: 5.0),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (feature['color'] as Color).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(feature['icon'],
                            size: 40, color: feature['color']),
                      ),
                      SizedBox(height: 20),
                      Text(
                        feature['title'],
                        style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 10),
                      Text(
                        feature['desc'],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.0, color: Colors.white70),
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

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      color: Colors.black,
      child: Column(
        children: [
          Divider(color: Colors.white12),
          SizedBox(height: 20),
          Text(
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
          colors: [color.withOpacity(0.5), Colors.transparent],
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          title,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoreButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
