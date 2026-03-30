import 'package:flutter/material.dart';

import 'gravity_simulator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GravityApp());
}

class GravityApp extends StatelessWidget {
  const GravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravity Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GravitySimulatorPage(),
    );
  }
}
