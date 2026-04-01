import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screens/landing_screen.dart' as mobile_landing;
import 'screens/web/landing_screen.dart' as web_landing;
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/super_admin_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/cart_service.dart';
import 'services/order_service.dart';
import 'services/settings_service.dart';
import 'constants/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Credentials are injected at build time via --dart-define.
  // For local dev, the default values below are used automatically.
  // For CI/CD or production builds, inject via:
  //   flutter build web \
  //     --dart-define=SUPABASE_URL=https://... \
  //     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jpysitnnnopomrgjbaxq.supabase.co',
  );
  const supabaseKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2ydfHF0FqCYOr5ZQ5NZ4QQ_UUDvboCo',
  );

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    debugPrint("CRITICAL: Supabase credentials missing!");
  }

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }


  // Initialize Services with Persistence
  await CartService().init();
  await OrderService().init();

  // Initialize Localization (Saved Pref > Geolocation)
  // Fire and forget to avoid blocking runApp due to web location permission prompt!
  LocaleService().init();

  // Initialize Settings (Currency)
  await SettingsService().loadCurrency();

  // Enable Edge-to-Edge UI for premium look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MandaApp());
}

class MandaApp extends StatelessWidget {
  const MandaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeModeNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<Locale>(
            valueListenable: LocaleService().localeNotifier,
            builder: (context, locale, _) {
              return MaterialApp(
                title: 'Manda.AI',
                debugShowCheckedModeBanner: false,
                // Localizations
                locale: locale,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en'), // English
                  Locale('pt'), // Portuguese
                ],

                ///Themes
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeService().getEffectiveThemeMode(),
                home: kIsWeb
                    ? _webHome()
                    : const mobile_landing.LandingScreen(),
                routes: {
                  '/login': (context) => const mobile_landing.LandingScreen(),
                  '/admin': (context) => const AdminLoginScreen(),
                  '/super-admin-dashboard': (context) =>
                      const SuperAdminDashboardScreen(),
                  '/admin-dashboard': (context) => const AdminDashboardScreen(),
                },
              );
            });
      },
    );
  }
  /// On web: mobile screens (PWA) → mobile landing, desktop → web marketing
  static Widget _webHome() {
    // Use physical screen width to detect mobile at startup
    final width = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (width < 700) {
      return const mobile_landing.LandingScreen();
    }
    return const web_landing.LandingScreen();
  }
}
