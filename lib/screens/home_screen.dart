import 'package:flutter/material.dart';
import '../authentication/auth_service.dart';
// lib/screens/home_screen.dart

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();

  String? _displayName;
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    setState(() {
      _loading = true;
    });

    try {
      final uid = _authService.getCurrentUserId();
      _userId = uid;

      final name = await _authService.fetchDisplayName();
      setState(() {
        _displayName = name;
      });
    } catch (e, st) {
      debugPrint('Error initializing user: $e\n$st');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String get _greeting {
    if (_loading) return 'Hello Doctor 👋';
    if (_displayName != null && _displayName!.isNotEmpty) {
      // If displayName already includes "Dr." you may avoid prefixing again.
      final name = _displayName!.trim();
      if (name.toLowerCase().startsWith('dr') || name.toLowerCase().startsWith('doctor')) {
        return 'Hello $name 👋';
      }
      return 'Hello Dr. $name 👋';
    }
    return 'Hello Doctor 👋';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Dashboard"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _loading
                ? Row(
                    children: const [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading your profile...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  )
                : Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            if (_userId != null) ...[
              const SizedBox(height: 8),
              Text(
                "User ID: $_userId",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              "Welcome to your client management system.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.people),
              label: const Text("View Clients"),
              onPressed: () {
                // TODO: Navigate to Clients screen
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: const Text("Appointments"),
              onPressed: () {
                // TODO: Navigate to Appointments screen
              },
            ),
          ],
        ),
      ),
    );
  }
}