# Correction du partage de playlist — étapes restantes

Ce que j'ai déjà corrigé dans le code de l'app (`clips`) :
- iOS : ajout de `com.apple.developer.associated-domains` dans `Runner.entitlements`.
- Android : ajout du schéma `reelr://` (qui manquait complètement) + des App Links `https://yyprdqp527-ui.github.io/...` dans `AndroidManifest.xml`.
- Dart : `PlaylistLink.tryDecode` et `app.dart` reconnaissent maintenant le lien à la fois sous sa forme `reelr://playlist...` et sous sa forme `https://yyprdqp527-ui.github.io/reelr-support/playlist...` — donc même si le lien web s'ouvre directement dans l'app (Universal/App Links), l'écran d'import s'affiche.

Il reste 3 choses que je ne peux pas faire moi-même (accès externe requis).

## 1. Récupérer l'empreinte SHA256 de signature Android

Nécessaire pour `assetlinks.json` (étape 2). Depuis ton Mac, dans le dossier du projet :

```
cd ~/clips/android
./gradlew signingReport
```

Cherche la ligne `SHA256:` sous la variante `release` (celle utilisée pour le Play Store). Garde cette valeur, tu en as besoin juste après.

## 2. Publier 2 fichiers sur le dépôt `reelr-support` (GitHub Pages)

Dans ce dépôt (celui qui héberge `playlist.html`), crée :

**`/.well-known/apple-app-site-association`** (sans extension, servi en `Content-Type: application/json`) :

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YPQ8H3U5HX.com.reelr.app",
        "paths": ["/reelr-support/playlist*"]
      }
    ]
  }
}
```

**`/.well-known/assetlinks.json`** :

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.room79.reelr",
      "sha256_cert_fingerprints": ["COLLE_ICI_LE_SHA256_DE_L'ÉTAPE_1"]
    }
  }
]
```

Commandes pour les ajouter et pousser (adapte le chemin vers ton clone local de `reelr-support`) :

```
cd ~/reelr-support
mkdir -p .well-known
# colle le contenu ci-dessus dans .well-known/apple-app-site-association
# colle le contenu ci-dessus (avec ton SHA256) dans .well-known/assetlinks.json
git add .well-known
git commit -m "Add Universal Links / App Links verification files for playlist sharing"
git push
```

Vérifie ensuite que GitHub Pages les sert bien (dans un navigateur) :
`https://yyprdqp527-ui.github.io/.well-known/apple-app-site-association`
`https://yyprdqp527-ui.github.io/.well-known/assetlinks.json`

## 3. Activer la capacité "Associated Domains" dans Xcode

L'entitlement que j'ai ajouté ne sert à rien tant que la capacité n'est pas activée côté Apple Developer Portal / Xcode, sinon la prochaine archive risque même d'échouer à la signature.

Dans Xcode : ouvre `ios/Runner.xcworkspace` → sélectionne la cible **Runner** → onglet **Signing & Capabilities** → **+ Capability** → ajoute **Associated Domains** → vérifie que `applinks:yyprdqp527-ui.github.io` apparaît (déjà repris automatiquement depuis le fichier `.entitlements`) → laisse Xcode régénérer le profil de provisioning.

## 4. Corriger le JS de `playlist.html` (dépôt `reelr-support`)

Le bug "redirige toujours vers l'App Store" vient probablement d'un minuteur qui redirige sans vérifier si l'app s'est ouverte. Remplace la logique de redirection par quelque chose comme :

```html
<script>
  const appUri = "reelr://playlist?name=...&items=..."; // généré dynamiquement
  const storeUri = "https://apps.apple.com/app/idXXXXXXXXX"; // ou le lien Play Store selon la plateforme

  let redirected = false;
  const toStore = () => {
    if (redirected) return;
    redirected = true;
    window.location.href = storeUri;
  };

  // Si l'app s'ouvre, la page passe en arrière-plan : on annule la redirection.
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) redirected = true;
  });
  window.addEventListener("pagehide", () => { redirected = true; });

  window.location.href = appUri;
  setTimeout(toStore, 1500);
</script>
```

Avec les Universal/App Links (étapes 1-3) actifs, cette page ne devrait même plus être nécessaire dans la majorité des cas : le lien `https://` ouvrira Reelr directement, sans passer par Safari.

## Résumé des commandes à coller

```
cd ~/clips/android && ./gradlew signingReport
```
puis, une fois le SHA256 en main, dans le dépôt `reelr-support` :
```
cd ~/reelr-support
mkdir -p .well-known
git add .well-known
git commit -m "Add Universal Links / App Links verification files for playlist sharing"
git push
```
