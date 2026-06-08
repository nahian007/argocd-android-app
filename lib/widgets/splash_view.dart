import 'package:flutter/material.dart';

/// Branded full-screen loading view used during startup, logout, and the
/// login-flow's initial redirect chain — anywhere we want to hide a stale
/// or in-flight screen so the user doesn't see content flash through.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1a1a2e),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, color: Color(0xFFe94560), size: 64),
            SizedBox(height: 20),
            Text(
              'ArgoCD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'shopup.center',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Color(0xFFe94560),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
