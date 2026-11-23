package com.example.card_reader

import android.content.Context
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val HCE_CHANNEL = "com.example.card_reader/hce"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots, screen recording, and recents thumbnail capture
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPayload" -> {
                    val payload = call.argument<ByteArray>("payload") ?: byteArrayOf()
                    HceService.currentPayload = payload

                    // Persist payload to disk so it broadcasts even if app is completely closed/killed!
                    val prefs = getSharedPreferences("hce_prefs", Context.MODE_PRIVATE)
                    val hex = payload.joinToString("") { "%02X".format(it) }
                    prefs.edit().putString("saved_payload", hex).apply()

                    result.success(true)
                }
                "getSavedPayload" -> {
                    val prefs = getSharedPreferences("hce_prefs", Context.MODE_PRIVATE)
                    val hex = prefs.getString("saved_payload", null)
                    if (!hex.isNullOrEmpty()) {
                        val bytes = ByteArray(hex.length / 2)
                        for (i in 0 until hex.length step 2) {
                            bytes[i / 2] = hex.substring(i, i + 2).toInt(16).toByte()
                        }
                        result.success(bytes)
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
