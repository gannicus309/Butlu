import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications show clash warnings while Butlu is
    // open, not just when it's in the background.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ButluTextRecognizer") {
      TextRecognizer.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ButluSigningInfo") {
      FlutterMethodChannel(name: "butlu/signing", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "expiresAt" else {
            result(FlutterMethodNotImplemented)
            return
          }
          result(AppDelegate.signingExpiry())
        }
    }
  }

  /// When this build stops opening: the ExpirationDate in the provisioning
  /// profile Xcode embedded (7 days out with a free Apple ID). Nil for App
  /// Store / TestFlight builds, which carry no profile.
  static func signingExpiry() -> String? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1),
          let match = text.range(
            of: "<key>ExpirationDate</key>\\s*<date>[^<]+</date>",
            options: .regularExpression)
    else { return nil }
    let tag = text[match]
    guard let start = tag.range(of: "<date>"), let end = tag.range(of: "</date>") else { return nil }
    return String(tag[start.upperBound..<end.lowerBound])
  }
}
