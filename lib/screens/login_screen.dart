import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/splash_view.dart';
import 'apps_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _controller;
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  // Flips on the first onPageFinished. While false we keep the WebView
  // hidden behind a full splash so the auth redirect chain (argocd →
  // /auth/login → Google) doesn't flash any intermediate UI.
  bool _firstPageReady = false;
  bool _tokenExtracted = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  // Mobile Chrome UA without the WebView "; wv)" token. Bypasses Google's
  // disallowed_useragent block while letting ArgoCD serve its mobile layout.
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  // Native channel into Android's CookieManager — reads HttpOnly cookies
  // that JS can't see. Matches the channel name in MainActivity.kt.
  static const _cookieChannel = MethodChannel('com.shopup.argocd_mobile/cookies');

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setBackgroundColor(const Color(0xFF1a1a2e))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _firstPageReady = true;
              });
            }
            await _tryExtractToken(url);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _isLoading = false);
            // Silently ignore minor resource errors; only surface fatal ones
            if (error.isForMainFrame == true) {
              _showError('Failed to load ArgoCD: ${error.description}');
            }
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('${AuthService.baseUrl}/'));
  }

  Future<void> _tryExtractToken(String url) async {
    if (_tokenExtracted) return;

    // Try to grab token from localStorage (ArgoCD stores it as 'argocd.token')
    try {
      final result = await _controller.runJavaScriptReturningResult(
        "window.localStorage.getItem('argocd.token') || ''",
      );

      // result comes back as a JSON string with surrounding quotes
      String token = result.toString();
      token = token.replaceAll('"', '').trim();

      if (token.isNotEmpty && token != 'null') {
        _tokenExtracted = true;
        await _authService.saveToken(token);
        if (mounted) _navigateToApps();
        return;
      }
    } catch (_) {
      // localStorage not available yet — retry on next navigation
    }

    // Fallback 1: read from cookie via JS (only works if the cookie isn't HttpOnly)
    try {
      final cookieResult = await _controller.runJavaScriptReturningResult(
        r"""
        (function() {
          var match = document.cookie.match(/argocd\.token=([^;]+)/);
          return match ? match[1] : '';
        })()
        """,
      );
      String cookie = cookieResult.toString().replaceAll('"', '').trim();
      if (cookie.isNotEmpty && cookie != 'null') {
        _tokenExtracted = true;
        await _authService.saveToken(cookie);
        if (mounted) _navigateToApps();
        return;
      }
    } catch (_) {
      // Not available yet
    }

    // Fallback 2: read from Android's CookieManager via platform channel.
    // ArgoCD sets argocd.token as HttpOnly so JS cannot see it, but the
    // WebView's underlying cookie store does.
    try {
      final value = await _cookieChannel.invokeMethod<String>(
        'getCookieValue',
        {'url': AuthService.baseUrl, 'name': 'argocd.token'},
      );
      if (value != null && value.isNotEmpty) {
        _tokenExtracted = true;
        await _authService.saveToken(value);
        if (mounted) _navigateToApps();
        return;
      }
    } catch (_) {
      // Channel unavailable; will retry on next page load
    }
  }

  void _navigateToApps() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppsScreen()),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Color(0xFFe94560), size: 28),
            const SizedBox(width: 10),
            const Text(
              'ArgoCD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFe94560),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // Translucent spinner overlay for subsequent loads (after the
          // first page is up and the WebView is visible).
          if (_isLoading && _firstPageReady)
            Container(
              color: const Color(0xFF1a1a2e).withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFe94560),
                ),
              ),
            ),
          // Full-bleed splash until the first page finishes — hides the
          // initial blank WebView and the brief auth-redirect flashes.
          if (!_firstPageReady) const Positioned.fill(child: SplashView()),
        ],
      ),
    );
  }
}
