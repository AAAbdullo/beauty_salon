package com.example.beauty_salons

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
    }
}
