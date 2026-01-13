import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/menu_screen.dart';

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
    return MaterialApp(
      title: 'Manda.AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE63946), // A vibrant red
          brightness: Brightness.dark, // Dark mode for bars/pubs
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context)
              .textTheme
              .apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const MenuScreen(),
    );
  }
}
