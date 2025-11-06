import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safespace_doctor_app/screens/home_screen.dart';
import 'package:safespace_doctor_app/screens/onboarding_screen.dart';
// <-- Add your actual home screen here

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while checking session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Retrieve current session
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // ✅ User logged in — go to home screen
          return const HomeScreen();
        } else {
          // 🚪 User not logged in — go to onboarding/login/signup flow
          return const OnboardingScreen();
        }
      },
    );
  }
}
