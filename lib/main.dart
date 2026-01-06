import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_program/ui/loginPage.dart';
import 'package:project_program/ui/adminPage.dart';
import 'package:project_program/theme/theme_manager.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey[800],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey[800]!,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          color: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        scaffoldBackgroundColor: Colors.grey[850],
        dialogBackgroundColor: Colors.grey[900],
      ),
      themeMode: themeManager.themeMode,
      routes: {
        '/': (context) => const LoginPage(),
        '/admin': (context) => const AdminPage(),
      },
    );
  }
}