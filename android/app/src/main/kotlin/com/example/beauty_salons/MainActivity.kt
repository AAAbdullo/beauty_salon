package com.example.beauty_salons

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.yandex.mapkit.MapKitFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        MapKitFactory.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
        super.configureFlutterEngine(flutterEngine)
    }
}
