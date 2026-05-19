# Share Extension iOS — Guide d'installation

Pour que **Clips** apparaisse dans le menu « Partager » de Safari, YouTube, TikTok, etc. sur iOS, il faut ajouter une **Share Extension** au projet Xcode. Cela ne peut PAS être fait via Flutter seul — il faut Xcode.

> Côté Android, c'est déjà configuré dans `android/app/src/main/AndroidManifest.xml` (intent-filter `SEND` / `text/plain`). Aucune action requise.

## Prérequis

- macOS avec Xcode installé (~15 Go d'espace disque)
- Le projet déjà ouvert dans Xcode

## Étapes (à faire une fois Xcode disponible)

### 1. Ouvrir le projet dans Xcode

```bash
open ios/Runner.xcworkspace
```

### 2. Ajouter une cible Share Extension

1. `File` → `New` → `Target…`
2. Choisir **Share Extension** → `Next`
3. Product Name : `ShareExtension`
4. Language : **Swift**
5. Cliquer `Finish` (refuser l'activation automatique du schéma)

### 3. Configurer l'App Group (pour partager les données avec l'app principale)

Dans Xcode, pour **les deux cibles** (`Runner` et `ShareExtension`) :

1. Onglet `Signing & Capabilities` → `+ Capability` → `App Groups`
2. Créer un groupe : `group.com.example.clips.shared` (remplacer par votre bundle id)
3. Cocher la case pour les deux cibles

### 4. Remplacer le code de la Share Extension

Remplacer le contenu de `ios/ShareExtension/ShareViewController.swift` par :

```swift
import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    let appGroupId = "group.com.example.clips.shared"
    let urlScheme = "clipsshare"

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: nil)
            return
        }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if provider.hasItemConformingToTypeIdentifier(urlType) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { (data, _) in
                if let url = data as? URL {
                    self.saveAndOpen(text: url.absoluteString)
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(textType) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { (data, _) in
                if let text = data as? String {
                    self.saveAndOpen(text: text)
                }
            }
        } else {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    func saveAndOpen(text: String) {
        // Sauvegarde via App Group pour receive_sharing_intent
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set([text], forKey: "ShareKey")
        userDefaults?.synchronize()

        // Ouvre l'app principale via URL scheme
        let url = URL(string: "\(urlScheme)://share")!
        var responder = self as UIResponder?
        while responder != nil {
            if let app = responder as? UIApplication {
                app.perform(#selector(UIApplication.open(_:options:completionHandler:)),
                            with: url, with: [:])
            }
            responder = responder?.next
        }

        self.extensionContext?.completeRequest(returningItems: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
```

### 5. Déclarer le URL scheme dans `ios/Runner/Info.plist`

Ajouter avant `</dict>` :

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>clipsshare</string>
        </array>
    </dict>
</array>
```

### 6. Configurer les types d'éléments acceptés

Dans `ios/ShareExtension/Info.plist`, modifier la clé `NSExtensionAttributes` :

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### 7. Tester

1. Lancer sur un simulateur ou un appareil réel : `flutter run -d ios`
2. Ouvrir Safari, partager une URL → l'icône **Clips** doit apparaître
3. Le tap doit ouvrir Clips avec la feuille « Ajouter un clip » pré-remplie

## Côté Dart : déjà fait

L'app écoute déjà via `receive_sharing_intent` dans `_ClipsAppState._initShareIntent()` (lib/main.dart). Dès qu'un partage arrive :

1. `getInitialMedia()` → cold start
2. `getMediaStream()` → app déjà ouverte
3. → ouvre `AddClipSheet(initialUrl: ...)` avec auto-suggestion IA de la catégorie

## Référence

- Plugin : <https://pub.dev/packages/receive_sharing_intent>
- Section iOS du README du plugin : très détaillée, suivre étape par étape
