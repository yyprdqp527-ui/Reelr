# Débrief — vignettes manquantes en production

**Date :** 9 août 2026
**Version de départ :** 1.0.3+17
**Symptôme signalé :** certaines vignettes de vidéos ne s'affichent pas, le logo générique de la plateforme apparaît à la place.

---

## 1. Diagnostic

Cinq causes distinctes, empilées. Aucune n'était la seule responsable.

### 1.1 — Le cache disque plafonnait à 200 images (cause racine)

`ResilientThumbnail` repose entièrement sur `DefaultCacheManager()` pour sa stratégie « last known good thumbnail ». Il était instancié nu, sans `Config`. Les valeurs par défaut de `flutter_cache_manager` 3.4.1 sont :

- `maxNrOfCacheObjects: 200`
- `stalePeriod: 30 jours`

Au 201ᵉ clip, le cache évinçait les plus anciennes miniatures. La revalidation réseau échouait ensuite (jeton CDN expiré) et le logo générique réapparaissait sur des clips qui s'affichaient correctement la veille.

Reelr étant une application d'accumulation, 200 est franchi en quelques semaines d'usage normal.

### 1.2 — Pré-cache et affichage ne visaient pas la même URL

`_hydrateClip` pré-téléchargeait l'URL **brute** ; l'affichage réclamait l'URL **proxifiée** via `bestThumbnailUrl` (Facebook, Reddit, Pinterest). Chaîne différente donc clé de cache différente : le fichier pré-téléchargé n'était jamais retrouvé.

Corollaire : `downloadFile()` n'envoyait aucun en-tête, alors que le Worker exige `x-reelr-secret` sur `/thumb` et répond 401 sans lui.

### 1.3 — `bestThumbnailUrl` n'était appliqué qu'à 1 point d'affichage sur 4

| Emplacement | Avant |
|---|---|
| Carte de clip | proxifié ✅ |
| Bandeau « récents » | brut ❌ |
| Vignette de catégorie | brut ❌ |
| Import de playlist | proxifié ✅ |

Le même clip recevait deux clés de cache selon l'écran.

### 1.4 — Les liens `share.google` n'étaient pas résolus

Observé en production sur des partages TikTok. `share.google` n'était reconnu ni par `SocialPlatform.detect` ni par `resolveShortLinkForDedup`. Conséquences en chaîne :

- plateforme enregistrée en `other` au lieu de `tiktok` ;
- pas de passage par `_fetchTikTokMetadata`, donc scraping OpenGraph générique ;
- `title = "TikTok - Make Your Day"`, `thumb = NULL` ;
- classification à `confiance: 25`, clip laissé « À trier ».

### 1.5 — Les wrappers TikTok `download-link` n'étaient pas déballés

Lien AppsFlyer contenant l'identifiant vidéo dans `af_dp` / `deep_link_value` sous la forme `aweme/detail/{id}`. L'oEmbed refuse cette URL ; `_fetchTikTokMetadata` renvoie `null` sans repli ni log.

---

## 2. Correctifs livrés

### `lib/services/thumbnail_cache.dart` *(nouveau)*

`CacheManager` réutilisant la **même clé** que `DefaultCacheManager` (`libCachedImageData`) — donc sans perte des miniatures déjà présentes sur les appareils — avec :

- `maxNrOfCacheObjects: 3000` (au lieu de 200)
- `stalePeriod: 365 jours` (au lieu de 30)
- `headersFor(url)` : centralise l'en-tête secret du proxy

### `lib/widgets/resilient_thumbnail.dart`

- lecture du cache via `ThumbnailCache.instance`
- `cacheManager: ThumbnailCache.instance` passé à `CachedNetworkImage` — **indispensable**, sans quoi l'écriture continuait d'aller dans `DefaultCacheManager`, plafonné à 200
- `httpHeaders: ThumbnailCache.headersFor(url)` remplace la logique locale dupliquée

### `lib/app.dart`

- le pré-cache vise désormais `bestThumbnailUrl(clip.url, resolvedThumbnailUrl)`, c'est-à-dire exactement l'URL que l'affichage réclamera
- `downloadFile(url, authHeaders: ThumbnailCache.headersFor(url))`

### `lib/screens/home_screen.dart`

`bestThumbnailUrl` appliqué au bandeau « récents » et aux vignettes de catégorie.

### `lib/services/oembed.dart`

- `resolveShortLinkForDedup` reconnaît `share.google`
- garde-fou : une redirection vers un schéma d'application ou une cible sans hôte ne remplace plus l'URL d'origine
- log `[shortlink]` de chaque résolution
- `_tiktokVideoIdFromDownloadLink` + `_decodeVariants` : extraction de l'identifiant depuis le wrapper AppsFlyer, puis résolution via `m.tiktok.com/v/{id}.html`

---

## 3. État de vérification

| Correctif | Statut | Preuve |
|---|---|---|
| Plafond de cache | Vérifié partiellement | Les 17 vignettes de catégorie lues depuis le disque juste après le changement de gestionnaire → réutilisation de clé confirmée. L'effet (non-éviction) est préventif, non observable aujourd'hui. |
| Alignement des URLs | Vérifié partiellement | Vignette « Actualités » passée par le proxy puis mise en cache. Aucun changement visible attendu côté utilisateur. |
| `share.google` | **Vérifié de bout en bout** | `share.google` → URL canonique → titre, auteur, miniature → classé Musique à 85 (contre 25 « À trier » avant). |
| `download-link` | **Non vérifié** | Jamais déclenché en test. Pari sur `m.tiktok.com/v/{id}.html`, forme legacy que TikTok bloque activement selon les sources publiques. Repli sûr : conserve l'URL d'origine en cas d'échec, donc pas de régression possible. |

---

## 4. Ce qui n'est pas corrigé

> **Mise à jour du 9 août, 23 h.** Une session de tests a invalidé plusieurs
> conclusions ci-dessous. Les corrections apportées sont dans les commits
> `de06fad`, `9206551` et `b2a493e`. Lire les annotations avant d'agir sur
> quoi que ce soit dans cette section.
>
> La cause racine du problème de vignettes n'était **pas** structurelle :
> `_fetchTikTokMetadata` jetait tout le payload oEmbed dès que le titre
> était vide, y compris une vignette valide. 9 clips réparés sur 9 après
> correction. Des clips diagnostiqués « vidéos supprimées » avaient une
> vignette disponible depuis le début.

**Structurel, sans solution par scraping :**

- **Reddit** — `.json` en 403, coquille React vide en repli, pas d'`og:image`. `thumb = NULL`. Nécessiterait une app OAuth Reddit (type script, gratuite) ou un passage par le Worker.
- ~~**Facebook Reels** — même profil, `thumb = NULL`.~~ **INFIRMÉ le 9 août au soir.** Deux liens `facebook.com/share/r/` testés en conditions réelles ramènent titre complet, vignette servie par le proxy Worker et classification à 95 et 75 de confiance. Facebook n'est pas un échec structurel. Cause probable du constat initial : les en-têtes réalistes n'étaient pas encore étendus, ou la vignette était perdue par le même bug que TikTok (payload jeté quand le titre est vide). **Ne pas abandonner Facebook.**
- **Instagram** — fonctionne aujourd'hui, mais par scraping OpenGraph sans jeton (`_instagramAccessToken` est vide). Peut casser sans préavis.

**Dettes identifiées, non traitées :**

- ~~**Aucune re-hydratation.**~~ **CORRIGÉ** (`de06fad`, étendu dans `b2a493e`). Passe au démarrage : 12 clips par lancement, re-résolution de l'URL avant ré-extraction, 3 tentatives maximum par clip. Elle couvre aussi les **vignettes mortes** — URL signée expirée sans fichier en cache — que la première version manquait puisqu'elles ont un `thumbnailUrl` non vide. Taux de récupération observé bien meilleur qu'annoncé : 9 sur 9.
- ~~**Le formulaire d'ajout manuel (`+`) contourne `resolveShortLinkForDedup`.**~~ **CORRIGÉ** (`b2a493e`). Il résout les liens courts, applique le garde-fou, détecte la plateforme sur l'URL résolue et incrémente le compteur à vie. Il permettait aussi de **dépasser la limite gratuite de 50 clips** sans jamais déclencher le paywall.
- ~~**Les URLs sans contenu sont enregistrées comme clips.**~~ **CORRIGÉ** (`de06fad`). `isContentlessUrl()` les bloque avant l'incrément du compteur, avec un message à l'utilisateur. Attention : la première version laissait passer `tiktok.com/foryou?lang=fr`, tout paramètre étant considéré comme porteur de contenu — seules les clés d'identifiant comptent désormais. `linkedin.com/feed/update/...` était rejeté à tort.
- ~~**Échec du pré-cache = logo définitif.**~~ **PARTIELLEMENT CORRIGÉ** (`de06fad`). 3 tentatives au lieu d'une, et les vignettes mortes sont désormais reprises par la passe de réparation. TikTok et Instagram ne passent toujours pas par le proxy : à traiter avec le cache d'extraction côté Worker.
- **3000 est un nouveau plafond, pas l'infini.** Toujours valable.
- ~~**`debugPrint('[badge]')` dans une méthode `build`**~~ **SUPPRIMÉ** (`de06fad`).

**Nouvelles dettes découvertes le 9 août au soir :**

- **Jeton Twitch expiré.** L'API Helix répond `401 Invalid OAuth token`. Tous les clips et VOD Twitch retombaient silencieusement sur OpenGraph, qui ne renvoie que le logo Twitch. La branche non-200 est désormais bavarde. À régénérer via `client_credentials` sur `id.twitch.tv/oauth2/token` — et ça réexpirera dans ~60 jours, d'où l'intérêt de déplacer le jeton vers le Worker.
- **Cache d'extraction côté Worker.** Le seul chantier qui compose : une URL extraite une fois, resservie indéfiniment. Résout l'expiration des jetons, rend la détection des vignettes mortes largement superflue, et évite d'extraire cinquante fois le même lien partagé par cinquante utilisateurs.
- **`vm.tiktok.com` non testé** depuis les modifications du 9 août au soir.

---

## 5. Contraintes TikTok confirmées

- L'oEmbed est officiel, public, sans authentification. **Aucune intégration ni compte développeur nécessaire.**
- Les URLs de miniature `p16-*.tiktokcdn*.com` sont signées avec `x-expires` et `x-signature`, validité observée ~24 h.
- TikTok **refuse les requêtes HEAD** et ses URLs de miniature **n'ont pas d'extension de fichier** — à prendre en compte si le Worker `/thumb` est un jour étendu à TikTok.
- Les points d'entrée legacy non officiels sont activement bloqués, ce qui fragilise le pari `m.tiktok.com/v/{id}.html`.
- **Ajout du 9 août au soir.** L'oEmbed TikTok répond régulièrement `200` avec un **titre vide mais une vignette valide**. Ce cas n'est ni une vidéo supprimée ni une limitation de débit : c'est le comportement normal des vidéos sans légende. Le code le traitait comme un échec total et jetait la vignette. C'était la cause racine de tout le problème.

---

## 6. Scripts créés

Dans `~/clips`, non suivis par git :

- `fix_thumbnail_cache_config.py`
- `fix_thumbnail_url_unification.py`
- `fix_share_google_resolution.py`
- `fix_tiktok_download_link.py`
- `verify_tiktok_resolution.dart` — diagnostic isolé, à supprimer une fois la question `m.tiktok.com` tranchée

---

## 7. Prochaine étape la plus utile

Ni TikTok, ni les vignettes : **le garde-fou contre l'enregistrement de liens sans contenu**, dans `_ingestSharedUrl`, avant l'incrément du compteur à vie. C'est ce qui empêchera les cartes vides d'apparaître, et c'est le seul point qui touche directement la facturation de l'utilisateur.
