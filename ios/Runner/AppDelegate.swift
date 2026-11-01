import Flutter
import UIKit
import YandexMapsMobile
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?

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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
