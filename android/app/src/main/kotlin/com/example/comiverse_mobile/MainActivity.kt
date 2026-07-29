package com.example.comiverse_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SCREEN_CAPTURE_CHANNEL = "comiverse/screen_capture_protection"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_CAPTURE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "setProtected") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val isProtected = call.arguments as? Boolean ?: false
            runOnUiThread {
                if (isProtected) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
        }
    }
}
