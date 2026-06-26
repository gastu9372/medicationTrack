import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved theme mode
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0 = system, 1 = light, 2 = dark
  ThemeMode initialThemeMode = ThemeMode.system;
  if (themeIndex == 1) {
    initialThemeMode = ThemeMode.light;
  } else if (themeIndex == 2) {
    initialThemeMode = ThemeMode.dark;
  }
  
  MedsTrackerApp.themeNotifier.value = initialThemeMode;
  
  runApp(const MedsTrackerApp());
}

class MedsTrackerApp extends StatelessWidget {
  const MedsTrackerApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Meds Tracker',
          debugShowCheckedModeBanner: false,
          
          // Light Mode Color System
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF6366F1),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF10B981),
              surface: Colors.white,
              background: Color(0xFFF8FAFC),
              onSurface: Color(0xFF0F172A),
            ),
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          
          // Dark Mode Color System
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF6366F1),
            scaffoldBackgroundColor: const Color(0xFF020617),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF10B981),
              surface: Color(0xFF0F172A),
              background: Color(0xFF020617),
              onSurface: Colors.white,
            ),
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          
          // Matches selected setting (System, Light, Dark)
          themeMode: currentMode,
          
          home: const DashboardView(),
        );
      },
    );
  }
}
