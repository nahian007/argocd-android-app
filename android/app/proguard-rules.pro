# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress Play Core warnings — referenced by Flutter's
# PlayStoreDeferredComponentManager, which this app does not use.
-dontwarn com.google.android.play.core.**

# flutter_secure_storage
-keep class androidx.security.crypto.** { *; }

# webview_flutter
-keep class android.webkit.** { *; }

# Prevent stripping of annotations used by json serialization
-keepattributes *Annotation*
-keepattributes Signature

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
