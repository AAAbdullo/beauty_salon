import Flutter
import UIKit
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override init() {
    super.init()
    YMKMapKit.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    YMKMapKit.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    YMKMapKit.setApiKey("a7b20b8e-db40-4187-9f36-3e3c1a8d5db4")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
