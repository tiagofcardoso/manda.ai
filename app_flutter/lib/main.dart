import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/landing_screen.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: Hardcoding credentials to bypass Flutter Web 'assets/.env' 500 error.
  // We can switch back to dotenv for mobile builds later.

  // try {
  //   await dotenv.load(fileName: ".env");
  // } catch (e) {
  //   debugPrint("Warning: Failed to load .env file: $e");
  // }

  const supabaseUrl = 'https://jpysitnnnopomrgjbaxq.supabase.co';
  const supabaseKey = 'sb_publishable_2ydfHF0FqCYOr5ZQ5NZ4QQ_UUDvboCo';

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    debugPrint("CRITICAL: Supabase credentials missing!");
  }

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  runApp(const MandaApp());
}

class MandaApp extends StatelessWidget {
  const MandaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
            valueListenable: LocaleService().localeNotifier,
            builder: (context, locale, _) {
              return MaterialApp(
                title: 'Manda.AI',
                debugShowCheckedModeBanner: false,
                themeMode: themeMode,
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
                // Themes
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFFE63946),
                      brightness: Brightness.light),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
                  textTheme: GoogleFonts.interTextTheme(),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  cardTheme: CardTheme(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                  ),
                ),
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFFE63946),
                      brightness: Brightness.dark),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  textTheme: GoogleFonts.interTextTheme().apply(
                      bodyColor: Colors.white, displayColor: Colors.white),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  cardTheme: CardTheme(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                home: const LandingScreen(),
              );
            });
      },
    );
  }
}
