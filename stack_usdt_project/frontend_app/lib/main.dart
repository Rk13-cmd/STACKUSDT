import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/game/game_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STACK USDT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const GameScreen(),
    );
  }
}
