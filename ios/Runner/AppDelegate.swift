import Flutter
import LinkPresentation
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

    // Apercu de lien natif (LinkPresentation) : secours pour les pages
    // que l'extraction HTTP de l'app ne sait pas lire (Reddit, pubs...).
    let previewChannel = FlutterMethodChannel(
      name: "reelr/link_preview",
      binaryMessenger: binaryMessenger
    )
    previewChannel.setMethodCallHandler { call, result in
      guard call.method == "fetch" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let raw = call.arguments as? String, let url = URL(string: raw) else {
        result(nil)
        return
      }
      // Partage depuis Safari : image et titre deja lus dans la page par
      // ReelrPreprocess.js. Prioritaire sur LinkPresentation, qui echoue
      // sur les sites anti-robots (H&M).
      if let safari = SafariPreviewStore.take(for: raw) {
        result(safari)
        return
      }
      LinkPreviewFetcher.fetch(url: url) { payload in result(payload) }
    }
    silentShareChannels.append(previewChannel)
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

/// Recupere titre et image d'une page via LinkPresentation (iOS 13+),
/// comme les apercus de liens d'iMessage.
enum LinkPreviewFetcher {
  static func fetch(url: URL, completion: @escaping ([String: Any]?) -> Void) {
    DispatchQueue.main.async {
      let provider = LPMetadataProvider()
      provider.timeout = 15
      provider.startFetchingMetadata(for: url) { metadata, error in
        guard let metadata = metadata, error == nil else {
          DispatchQueue.main.async { completion(nil) }
          return
        }
        var payload: [String: Any] = [:]
        if let title = metadata.title { payload["title"] = title }
        guard let imageProvider = metadata.imageProvider,
              imageProvider.canLoadObject(ofClass: UIImage.self) else {
          DispatchQueue.main.async { completion(payload.isEmpty ? nil : payload) }
          return
        }
        imageProvider.loadObject(ofClass: UIImage.self) { object, _ in
          var data: Data?
          if let image = object as? UIImage {
            data = LinkPreviewFetcher.resized(image, maxSide: 720).jpegData(compressionQuality: 0.85)
          }
          DispatchQueue.main.async {
            if let data = data {
              payload["image"] = FlutterStandardTypedData(bytes: data)
            }
            completion(payload.isEmpty ? nil : payload)
          }
        }
      }
    }
  }

  static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let size = image.size
    let longest = max(size.width, size.height)
    guard longest > maxSide, longest > 0 else { return image }
    let scale = maxSide / longest
    let target = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}

/// Apercus lus dans Safari par l'extension de partage (ReelrPreprocess.js),
/// ranges dans le groupe d'apps sous « ReelrSafariPreviews ». Chaque apercu
/// n'est servi qu'une fois puis retire.
enum SafariPreviewStore {
  static let key = "ReelrSafariPreviews"

  static func take(for rawURL: String) -> [String: Any]? {
    let groupId = (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String)
      ?? "group.com.reelr.app.shared"
    guard let defaults = UserDefaults(suiteName: groupId),
          var previews = defaults.dictionary(forKey: key) as? [String: [String: String]]
    else { return nil }
    let normalized = normalize(rawURL)
    guard let entry = previews[normalized] else { return nil }
    previews.removeValue(forKey: normalized)
    defaults.set(previews, forKey: key)
    defaults.synchronize()
    let image = entry["image"] ?? ""
    guard !image.isEmpty else { return nil }
    var payload: [String: Any] = ["imageUrl": image]
    if let title = entry["title"], !title.isEmpty { payload["title"] = title }
    return payload
  }

  /// Meme normalisation que l'extension de partage (ShareViewController).
  static func normalize(_ rawURL: String) -> String {
    guard var components = URLComponents(string: rawURL) else {
      return rawURL.lowercased()
    }
    let removeKeys = ["si", "utm_source", "utm_medium", "utm_campaign",
                      "fbclid", "igshid", "feature", "pp"]
    components.queryItems = components.queryItems?.filter {
      !removeKeys.contains($0.name)
    }
    if components.queryItems?.isEmpty == true {
      components.queryItems = nil
    }
    components.fragment = nil
    return (components.string ?? rawURL).lowercased()
  }
}
