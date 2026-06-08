package com.shopup.argocd_mobile

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cookieChannel = "com.shopup.argocd_mobile/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cookieChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCookieValue") {
                    val url = call.argument<String>("url")
                    val name = call.argument<String>("name")
                    if (url == null || name == null) {
                        result.error("BAD_ARGS", "url and name are required", null)
                        return@setMethodCallHandler
                    }
                    // CookieManager.getCookie returns "k1=v1; k2=v2" for all cookies
                    // set on the URL — including HttpOnly ones, which JS can't read.
                    val raw = CookieManager.getInstance().getCookie(url)
                    if (raw == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val value = raw.split(";")
                        .map { it.trim() }
                        .firstOrNull { it.startsWith("$name=") }
                        ?.substringAfter("=")
                    result.success(value)
                } else {
                    result.notImplemented()
                }
            }
    }
}
