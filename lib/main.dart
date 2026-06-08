import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/argocd_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/apps_screen.dart';
import 'widgets/splash_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ArgoCDApp());
}

class ArgoCDApp extends StatelessWidget {
  const ArgoCDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArgoCD Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFe94560),
          secondary: const Color(0xFF0f3460),
          surface: const Color(0xFF16213e),
          background: const Color(0xFF1a1a2e),
        ),
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213e),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final authService = AuthService();
    var destination = const LoginScreen() as Widget;

    if (await authService.isLoggedIn()) {
      // Don't flash the dashboard if the stored token is stale — verify with
      // the server first. On network errors we trust the token and let the
      // AppsScreen handle the failure (so an offline launch still works).
      try {
        final valid = await ArgoCDService(authService).validateSession();
        if (valid) {
          destination = const AppsScreen();
        } else {
          await authService.logout();
        }
      } catch (_) {
        destination = const AppsScreen();
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) => const SplashView();
}
