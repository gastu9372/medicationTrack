import 'package:flutter/material.dart';
import 'views/dashboard_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedsTrackerApp());
}

class MedsTrackerApp extends StatelessWidget {
  const MedsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meds Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF0F172A),
          background: Color(0xFF020617),
        ),
        fontFamily: 'Roboto', // Premium native font fallback
        useMaterial3: true,
      ),
      home: const DashboardView(),
    );
  }
}
