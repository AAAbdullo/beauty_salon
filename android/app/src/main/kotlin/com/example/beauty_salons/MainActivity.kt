package com.example.beauty_salons

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.speech.tts.TextToSpeech
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    // Запрос разрешения на геолокацию: запрашивается при открытии карты, а не при запуске приложения
    private var pendingLocationResult: MethodChannel.Result? = null
    private val locationRequestCode = 4101
    private val locationPrefs = "location_permission"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tts = TextToSpeech(this, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.beauty_salon/tts").setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")
                    if (text != null && isTtsReady) {
                        tts?.stop()
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "NavGuidance")
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stop" -> {
                    tts?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.beauty_salon/location").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(locationStatus())
                "request" -> requestLocationPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true // до Android 6 разрешение выдаётся при установке
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun wasLocationAsked(): Boolean =
        getSharedPreferences(locationPrefs, MODE_PRIVATE).getBoolean("asked", false)

    /// Можно ли показать системное окно ещё раз: после первого отказа Android разрешает переспросить,
    /// пока пользователь не отметил «Больше не спрашивать» (тогда rationale == false).
    private fun canAskAgain(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION)

    /// granted | notDetermined (ещё не спрашивали) | denied (отказали, можно спросить снова) |
    /// permanentlyDenied (отказали навсегда — только через настройки телефона)
    private fun locationStatus(): String = when {
        hasLocationPermission() -> "granted"
        !wasLocationAsked() -> "notDetermined"
        canAskAgain() -> "denied"
        else -> "permanentlyDenied"
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        val status = locationStatus()
        // Уже разрешено, отказали навсегда или запрос уже идёт — отвечаем сразу, окно не показываем
        if (status == "granted" || status == "permanentlyDenied" || pendingLocationResult != null) {
            result.success(status)
            return
        }
        // До Android 6 разрешение выдаётся при установке — запрашивать нечего (сюда не попадём, но lint требует проверку)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success("granted")
            return
        }
        // notDetermined или denied: показываем системное окно (повторно — после прежнего отказа)
        pendingLocationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            locationRequestCode
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == locationRequestCode) {
            getSharedPreferences(locationPrefs, MODE_PRIVATE).edit().putBoolean("asked", true).apply()
            pendingLocationResult?.success(locationStatus())
            pendingLocationResult = null
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale("ru")
            isTtsReady = true
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
