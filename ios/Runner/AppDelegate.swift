import Flutter
import UIKit
import YandexMapsMobile
import CoreLocation
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  private let speechSynthesizer = AVSpeechSynthesizer()

  override init() {
    super.init()
    YMKMapKit.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    YMKMapKit.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")

    // Инициализация и системный запрос разрешения на геопозицию для Yandex MapKit
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    locationManager?.requestWhenInUseAuthorization()
    locationManager?.startUpdatingLocation()

    // Регистрация MethodChannel голосовой навигации (TTS)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupTtsChannel(binaryMessenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupTtsChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.beauty_salon/tts", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
        return
      }
      if call.method == "speak" {
        if let args = call.arguments as? [String: Any], let text = args["text"] as? String {
          self.speechSynthesizer.stopSpeaking(at: .immediate)
          let utterance = AVSpeechUtterance(string: text)
          utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
          utterance.rate = 0.50
          utterance.pitchMultiplier = 1.0
          self.speechSynthesizer.speak(utterance)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing text argument", details: nil))
        }
      } else if call.method == "stop" {
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    if status == .authorizedWhenInUse || status == .authorizedAlways {
      manager.startUpdatingLocation()
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    YMKMapKit.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
    setupTtsChannel(binaryMessenger: engineBridge.binaryMessenger)
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
