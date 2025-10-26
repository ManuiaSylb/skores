import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SkullKingApp());
}

class SkullKingApp extends StatelessWidget {
  const SkullKingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skull King Scores',
      theme: ThemeData(
        colorSchemeSeed: const Color.fromARGB(255, 57, 10, 0),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}