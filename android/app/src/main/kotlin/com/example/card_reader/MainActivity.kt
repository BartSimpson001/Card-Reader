package com.example.card_reader

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val HCE_CHANNEL = "com.example.card_reader/hce"
    private var nfcAdapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots, screen recording, and recents thumbnail capture
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
    }

    override fun onResume() {
        super.onResume()
        // Claim foreground dispatch so that while the app is active, tapping a card
        // is delivered directly to this activity without launching a duplicate activity
        // or opening the system tag chooser dialog.
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)
        nfcAdapter?.enableForegroundDispatch(this, pendingIntent, null, null)
    }

    override fun onPause() {
        super.onPause()
        // Release foreground dispatch when app goes to background so that
        // system intent filters can launch/resume the app on tap if configured.
        nfcAdapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Consumed here so an already-running activity is never restarted or duplicated!
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
