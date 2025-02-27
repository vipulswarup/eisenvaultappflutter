import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EisenVault DMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: EVColors.screenBackground,
        fontFamily: 'SF Pro Display', // iOS-style font
      ),
      home: const LoginScreen(),
    );
  }
}
