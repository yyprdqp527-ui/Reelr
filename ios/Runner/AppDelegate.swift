import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let silentShareChannelName = "reelr/share_inbox"
  private let silentShareInboxKey = "ReelrSilentInboxUrls"
  private var silentShareChannels: [FlutterMethodChannel] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didStart = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      registerSilentInboxChannel(binaryMessenger: flutterViewController.binaryMessenger)
    }

    return didStart
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerSilentInboxChannel(binaryMessenger: messenger)
  }

  private func registerSilentInboxChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: silentShareChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result([])
        return
      }
      if call.method == "drainPendingUrls" {
        result(self.drainPendingUrls())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    // Retain channel instances so handlers remain active across engine lifecycles.
    silentShareChannels.append(channel)
  }

  private func drainPendingUrls() -> [String] {
    let groupId = (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String)
      ?? "group.com.reelr.app.shared"
    guard let defaults = UserDefaults(suiteName: groupId) else {
      return []
    }

    let urls = defaults.stringArray(forKey: silentShareInboxKey) ?? []
    defaults.removeObject(forKey: silentShareInboxKey)
    defaults.synchronize()
    return urls
  }
}
