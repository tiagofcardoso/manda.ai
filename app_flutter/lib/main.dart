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
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpweXNpdG5ubm9wb21yZ2piYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyODcwNzksImV4cCI6MjA4Mzg2MzA3OX0.1hgMbhmxSM2azb-0OofxamVL5smpPwm-3ZadlQv_JqA';

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
