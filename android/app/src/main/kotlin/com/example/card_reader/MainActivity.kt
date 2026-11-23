package com.example.card_reader

import android.view.WindowManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState) 
        // Prevent screenshots, screen recording, and recents thumbnail capture
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}