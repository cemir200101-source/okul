import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/login_page.dart';
import 'services/theme_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const SinavAnalizApp(),
    ),
  );
}

class SinavAnalizApp extends StatelessWidget {
  const SinavAnalizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'Çatı Deneme - Deneme Analizi',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.themeMode,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      home: const LoginPage(),
    );
  }
}
