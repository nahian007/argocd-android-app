import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles Google OIDC sign-in via Chrome Custom Tabs (flutter_appauth) and
/// persists the resulting id_token / refresh_token / expiry. The id_token
/// is what ArgoCD uses as the Bearer credential on API calls.
class AuthService {
  static const _idTokenKey = 'argocd_id_token';
  static const _refreshTokenKey = 'argocd_refresh_token';
  static const _expiryKey = 'argocd_token_expiry_iso';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _appAuth = FlutterAppAuth();

  // ArgoCD API base — used by argocd_service.dart for REST calls.
  static const String baseUrl = 'https://argocd.shopup.center';

  // OIDC config. The discovery URL avoids us hardcoding the auth/token
  // endpoints; flutter_appauth fetches them from Google.
  static const _discoveryUrl =
      'https://accounts.google.com/.well-known/openid-configuration';

  // Android OAuth 2.0 Client ID, registered in GCP Console with package
  // name `com.shopup.argocd_mobile` and the signing-key SHA-1.
  // TODO: replace with the real client_id once registered.
  static const _clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: 'REPLACE_WITH_ANDROID_OAUTH_CLIENT_ID.apps.googleusercontent.com',
  );

  // Must match `appAuthRedirectScheme` in android/app/build.gradle.kts plus
  // the standard AppAuth path. Google's OAuth flow returns to this URI.
  static const _redirectUri = 'com.shopup.argocd_mobile:/oauthredirect';

  // openid + email get us an id_token with the user's identity. ArgoCD
  // also typically wants `groups` if you've configured group-based RBAC.
  static const _scopes = ['openid', 'email', 'profile'];

  // Refresh proactively N seconds before expiry to avoid 401s on slow networks.
  static const _refreshLeadTime = Duration(seconds: 60);

  /// Returns a fresh id_token, refreshing via refresh_token if the stored
  /// one is expired or close to expiring. Returns null if the user is
  /// not signed in or refresh has irrecoverably failed.
  Future<String?> getValidIdToken() async {
    final id = await _storage.read(key: _idTokenKey);
    if (id == null || id.isEmpty) return null;

    final expiryIso = await _storage.read(key: _expiryKey);
    final expiry = expiryIso != null ? DateTime.tryParse(expiryIso) : null;
    final stillValid = expiry != null &&
        expiry.isAfter(DateTime.now().add(_refreshLeadTime));
    if (stillValid) return id;

    return _refreshIdToken();
  }

  Future<String?> _refreshIdToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final result = await _appAuth.token(TokenRequest(
        _clientId,
        _redirectUri,
        discoveryUrl: _discoveryUrl,
        refreshToken: refresh,
        scopes: _scopes,
      ));
      if (result == null || result.idToken == null) return null;
      await _persist(result);
      return result.idToken;
    } catch (_) {
      // Refresh token revoked / expired / network down — caller decides
      // whether to send the user back to the sign-in screen.
      return null;
    }
  }

  /// Drives the AppAuth flow: opens Chrome Custom Tabs to Google, receives
  /// the redirect, exchanges the code for tokens, stores them. Returns
  /// true on success.
  Future<bool> signInWithGoogle() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUri,
        discoveryUrl: _discoveryUrl,
        scopes: _scopes,
        // Ask Google for a refresh_token so we don't have to re-prompt
        // every hour when the id_token expires.
        promptValues: const ['consent'],
      ),
    );
    if (result == null || result.idToken == null) return false;
    await _persist(result);
    return true;
  }

  Future<void> _persist(TokenResponse r) async {
    if (r.idToken != null) {
      await _storage.write(key: _idTokenKey, value: r.idToken);
    }
    if (r.refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: r.refreshToken);
    }
    if (r.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _expiryKey,
        value: r.accessTokenExpirationDateTime!.toIso8601String(),
      );
    }
  }

  Future<bool> isLoggedIn() async {
    final id = await _storage.read(key: _idTokenKey);
    return id != null && id.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: _idTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiryKey);
  }
}
