import 'package:flutter/material.dart';

import 'screens/menu_screen.dart';

class NumberMasterApp extends StatelessWidget {
  const NumberMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B82F6),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MenuScreen(),
    );
  }
}
