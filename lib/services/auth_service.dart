import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AuthService {
  static const _tokenKey = 'argocd_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String baseUrl = 'https://argocd.shopup.center';

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    // Also clear the WebView's cookie jar — otherwise ArgoCD's HttpOnly
    // session cookie persists and the next LoginScreen visit auto-logs
    // the user straight back in.
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {
      // best-effort; clearing the secure-storage token is enough on its own
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
