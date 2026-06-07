# ArgoCD Mobile — shopup.center

Flutter Android app for managing ArgoCD at `https://argocd.shopup.center/`.

## Setup

```bash
cd argocd_mobile
flutter pub get
flutter run
```

## How Login Works

The app opens `https://argocd.shopup.center/` in a WebView. After you complete SSO login (Google/OIDC), ArgoCD stores a JWT in `localStorage['argocd.token']`. The app reads this automatically and saves it to Android's encrypted `EncryptedSharedPreferences` via `flutter_secure_storage`. You stay logged in across restarts until you explicitly log out.

> **If auto-token extraction doesn't work with your SSO provider**, you can generate a static API token in ArgoCD: Settings → Accounts → [your user] → Generate Token, then paste it when prompted.

## Features

- SSO / OIDC login via WebView
- App list with sync & health status badges
- Search + filter by sync/health status
- Pull-to-refresh
- Trigger sync or hard refresh per app
- App detail: Overview tab (status, metadata, actions) + Resources tab (pods, deployments, etc.)
- Pod log viewer with color coding (errors red, warnings yellow) and copy-to-clipboard
- Secure token storage (encrypted shared prefs)
- Auto-logout on 401

## File Structure

```
lib/
  main.dart                     # Entry, splash, routing
  models/
    argocd_app.dart             # ArgoApp, SyncStatus, HealthStatus, ResourceNode
  services/
    auth_service.dart           # Token storage (flutter_secure_storage)
    argocd_service.dart         # API calls (list, sync, refresh, logs)
  screens/
    login_screen.dart           # WebView SSO screen
    apps_screen.dart            # App list with search/filter
    app_detail_screen.dart      # Overview + resource tree tabs
    logs_screen.dart            # Log stream viewer
  widgets/
    status_badge.dart           # SyncBadge, HealthBadge
android/
  app/
    build.gradle                # minSdk 21, release build config
    proguard-rules.pro
    src/main/
      AndroidManifest.xml       # INTERNET permission, hardware accel
      res/xml/
        network_security_config.xml  # HTTPS only, trust system CAs
```

## Build Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```
