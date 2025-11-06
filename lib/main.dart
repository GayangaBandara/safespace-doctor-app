import 'package:flutter/material.dart';
import 'package:safespace_doctor_app/config.dart';
import 'package:safespace_doctor_app/authentication/auth_gate.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initializeSupabase(); // ✅ Initialize Supabase connection

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Management App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(), // ✅ Routes to AuthGate
    );
  }
}
