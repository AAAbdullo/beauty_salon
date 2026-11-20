import Flutter
import UIKit
import YandexMapsMobile
import CoreLocation
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  // Менеджер геолокации создаётся только когда нужно запросить разрешение (при открытии карты),
  // а не при запуске приложения: до входа, у мастера и при выключенной настройке геолокация не нужна.
  private var locationManager: CLLocationManager?
  private var pendingLocationResult: FlutterResult?
  private let speechSynthesizer = AVSpeechSynthesizer()

  override init() {
    super.init()
    // Ключ берётся из ios/Flutter/Secrets.xcconfig (не в git) через Info.plist.
    let mapkitKey = Bundle.main.object(forInfoDictionaryKey: "YandexMapKitApiKey") as? String ?? ""
    YMKMapKit.setApiKey(mapkitKey)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Регистрация MethodChannel голосовой навигации (TTS) и запроса геолокации
    if let controller = window?.rootViewController as? FlutterViewController {
      setupTtsChannel(binaryMessenger: controller.binaryMessenger)
      setupLocationChannel(binaryMessenger: controller.binaryMessenger)
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

  // MARK: - Разрешение на геолокацию (канал com.beauty_salon/location)

  private func setupLocationChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.beauty_salon/location", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result("denied")
        return
      }
      switch call.method {
      case "status":
        result(self.statusString(self.currentAuthorizationStatus()))
      case "request":
        self.requestLocationPermission(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func currentAuthorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return (locationManager ?? CLLocationManager()).authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  private func statusString(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorizedAlways, .authorizedWhenInUse: return "granted"
    @unknown default: return "denied"
    }
  }

  /// Показывает системное окно, только если пользователя ещё не спрашивали; иначе сразу отдаёт состояние
  private func requestLocationPermission(_ result: @escaping FlutterResult) {
    let status = currentAuthorizationStatus()
    if status != .notDetermined || pendingLocationResult != nil {
      result(statusString(status))
      return
    }
    pendingLocationResult = result
    let manager = locationManager ?? CLLocationManager()
    locationManager = manager
    manager.delegate = self
    manager.requestWhenInUseAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = currentAuthorizationStatus()
    // Первый вызов приходит сразу после установки делегата, пока пользователь ещё не ответил
    if status != .notDetermined, let pending = pendingLocationResult {
      pendingLocationResult = nil
      pending(statusString(status))
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // У FlutterImplicitEngineBridge нет binaryMessenger — берём его через registrar.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BeautySalonTts") {
      setupTtsChannel(binaryMessenger: registrar.messenger())
      setupLocationChannel(binaryMessenger: registrar.messenger())
    }
  }
}
