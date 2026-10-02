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
        SafariPreviewStore.firstReachable(safari.candidates) { image in
          guard let image = image else {
            LinkPreviewFetcher.fetch(url: url) { payload in result(payload) }
            return
          }
          var payload: [String: Any] = ["imageUrl": image]
          if !safari.title.isEmpty { payload["title"] = safari.title }
          result(payload)
        }
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

  /// Adresses d'images qui ne sont qu'un logo ou une icone de site.
  static func looksGeneric(_ imageURL: String) -> Bool {
    let path = (URL(string: imageURL)?.path ?? imageURL).lowercased()
    // Mots entiers seulement : « silicone » ou « iconic » ne sont pas des icones.
    let pattern = "(^|[/_.-])(logos?|favicon|apple-touch-icon|icons?|sprites?|placeholder)([/_.-]|[0-9]|$)"
    return path.range(of: pattern, options: .regularExpression) != nil
  }

  /// Premiere image qui n'est pas morte (HEAD, 3 s max chacune), dans
  /// l'ordre des candidats. Seuls 404 et 410 ecartent une image : beaucoup
  /// de CDN refusent HEAD (403, 405) alors que l'image s'affiche tres bien.
  /// Rappel sur le fil principal.
  static func firstReachable(_ candidates: [String], completion: @escaping (String?) -> Void) {
    guard let first = candidates.first, let url = URL(string: first) else {
      DispatchQueue.main.async { completion(nil) }
      return
    }
    var request = URLRequest(url: url, timeoutInterval: 3)
    request.httpMethod = "HEAD"
    URLSession.shared.dataTask(with: request) { _, response, error in
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      if error == nil && code != 404 && code != 410 {
        DispatchQueue.main.async { completion(first) }
      } else {
        firstReachable(Array(candidates.dropFirst()), completion: completion)
      }
    }.resume()
  }

  static func take(for rawURL: String) -> (title: String, candidates: [String])? {
    guard let entry = takeEntry(for: rawURL) else { return nil }
    var candidates: [String] = []
    for key in ["image", "image2"] {
      if let u = entry[key], !u.isEmpty, !candidates.contains(u) { candidates.append(u) }
    }
    // Les logos et icones de site sont ecartes : une vraie photo ou rien.
    let real = candidates.filter { !looksGeneric($0) }
    guard !real.isEmpty else { return nil }
    return (title: entry["title"] ?? "", candidates: real)
  }

  static func takeEntry(for rawURL: String) -> [String: String]? {
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
    return entry
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
