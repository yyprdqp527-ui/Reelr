import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let silentShareChannelName = "reelr/share_inbox"
  private let silentShareInboxKey = "ReelrSilentInboxUrls"
  private var silentShareChannels: [FlutterMethodChannel] = []

  // Sursis demande a iOS quand l'app passe en arriere-plan, pour que les
  // extractions et telechargements de vignettes en cours puissent finir.
  // Sans lui, iOS suspend l'app en quelques secondes : un utilisateur qui
  // ouvre Reelr (vidage de la boite de partage) puis repart aussitot
  // retrouvait des clips sans vignette.
  private var finishWorkTask: UIBackgroundTaskIdentifier = .invalid
  private var finishWorkGeneration = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didStart = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Notifications plutot que applicationDidEnterBackground : elles sont
    // emises aussi avec le cycle de vie UIScene.
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification, object: nil)

    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      registerSilentInboxChannel(binaryMessenger: flutterViewController.binaryMessenger)
    }

    return didStart
  }

  @objc private func appDidEnterBackground() {
    guard finishWorkTask == .invalid else { return }
    finishWorkGeneration += 1
    let generation = finishWorkGeneration
    finishWorkTask = UIApplication.shared.beginBackgroundTask(
      withName: "reelr.finishThumbnails"
    ) { [weak self] in
      self?.endFinishWorkTask()
    }
    // Rendu volontairement avant la limite d'iOS (~30 s).
    DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
      guard let self, self.finishWorkGeneration == generation else { return }
      self.endFinishWorkTask()
    }
  }

  @objc private func appWillEnterForeground() {
    endFinishWorkTask()
  }

  private func endFinishWorkTask() {
    guard finishWorkTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(finishWorkTask)
    finishWorkTask = .invalid
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
      } else if call.method == "setSharedLocale" {
        self.setSharedLocale(call.arguments)
        result(nil)
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
  private func setSharedLocale(_ arguments: Any?) {
    guard let languageCode = arguments as? String else { return }
    let groupId = (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String)
      ?? "group.com.reelr.app.shared"
    guard let defaults = UserDefaults(suiteName: groupId) else { return }
    defaults.set(languageCode, forKey: "locale")
    defaults.synchronize()
  }
}
