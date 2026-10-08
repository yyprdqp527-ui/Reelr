import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/clip.dart';
import '../models/client_profile.dart';
import '../services/classifier.dart';
import '../models/classification_result.dart';
import '../services/database.dart';
import '../core/l10n.dart';
import 'dart:async';
import '../services/oembed.dart';
import '../services/thumbnail_store.dart';
import '../services/profile_service.dart';
import '../services/sorting_notebook.dart';
import 'package:uuid/uuid.dart';

/// Table de correspondance accent → lettre de base, utilisée par
/// [normalizeForSearch] pour que la recherche ignore les accents (ex.
/// "eleve" retrouve "élève"). Couvre les caractères latins accentués
/// courants en français et dans les autres langues européennes usuelles.
const Map<String, String> _searchAccentMap = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Normalise un texte pour la recherche : minuscules + accents retirés.
/// Utilisé à la fois côté requête tapée par l'utilisateur et côté texte
/// des clips (titre, tags, catégorie...), pour que la comparaison soit
/// insensible à la casse ET aux accents.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_searchAccentMap[ch] ?? ch);
  }
  return buffer.toString();
}

/// Découpe une requête de recherche en mots (tokens) normalisés, pour une
/// correspondance "tous ces mots quelque part" plutôt qu'une phrase exacte
/// dans l'ordre tapé (ex. "chat noir" retrouve aussi "noir chat" ou "chat
/// très noir").
List<String> searchTokensFor(String query) => normalizeForSearch(query)
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// Limite le nombre de classifications Claude simultanées (utile lors de
/// l'import de playlists avec plusieurs clips d'un coup) pour éviter les
/// timeouts en cascade quand trop d'appels réseau partent en parallèle
/// sans contrôle. Les appels au-delà de la limite patientent en file
/// plutôt que d'échouer.
class _ClassifyLimiter {
  static const int _maxConcurrent = 4;
  static int _active = 0;
  static final List<Completer<void>> _waiting = [];

  static Future<void> acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    await completer.future;
  }

  static void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _active--;
    }
  }
}

// ─────────────────────────────────────────────
// SUBCATEGORY MODEL
// ─────────────────────────────────────────────

class SubCategory {
  final String id;
  final String name;
  final String categoryId;
  final Color color;
  final IconData icon;

  const SubCategory({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'color': color.toARGB32(),
        'icon': icon.codePoint,
        'position': 0,
      };

  factory SubCategory.fromMap(Map<String, dynamic> map) => SubCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        categoryId: map['categoryId'] as String,
        color: Color(map['color'] as int),
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      );
}

// ─────────────────────────────────────────────
// SUBSUBCATEGORY MODEL
// ─────────────────────────────────────────────

class SubSubCategory {
  final String id;
  final String name;
  final String subCategoryId;
  final Color color;
  final IconData icon;

  const SubSubCategory({
    required this.id,
    required this.name,
    required this.subCategoryId,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subCategoryId': subCategoryId,
        'color': color.toARGB32(),
        'icon': icon.codePoint,
        'position': 0,
      };

  factory SubSubCategory.fromMap(Map<String, dynamic> map) => SubSubCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        subCategoryId: map['subCategoryId'] as String,
        color: Color(map['color'] as int),
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      );
}

enum SortOrder { chronological, alphabetical, manual }

List<Clip> sortClipsByOrder(List<Clip> src, SortOrder order) {
  final list = List<Clip>.from(src);
  switch (order) {
    case SortOrder.chronological:
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    case SortOrder.alphabetical:
      list.sort((a, b) => a.title.compareTo(b.title));
    case SortOrder.manual:
      list.sort((a, b) {
        final cmp = a.position.compareTo(b.position);
        return cmp != 0 ? cmp : b.addedAt.compareTo(a.addedAt);
      });
  }
  return list;
}

class ClipsState extends ChangeNotifier {
  List<Clip> _clips = [];
  final Set<String> _newlyClassifiedCategoryIds = {};
  List<ClipCategory> _categories = [];
  List<SubCategory> _subcategories = [];
  Map<String, String> _clipSubcategoryMap = {};
  List<SubSubCategory> _subsubcategories = [];
  Map<String, String> _clipSubSubcategoryMap = {};
  String _searchQuery = '';
  bool _isLoading = false;
  final Map<String, SortOrder> _categorySortOrders = {};
  final Map<String, bool> _categoryGridViews = {};

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  List<ClipCategory> get categories => _categories;

  Set<String> get newlyClassifiedCategoryIds => Set.unmodifiable(_newlyClassifiedCategoryIds);

  void markCategoryViewed(String categoryId) {
    _newlyClassifiedCategoryIds.remove(categoryId);
    notifyListeners();
  }

  /// Sous-catégorie correspondant à [id], ou `null` si introuvable/absente.
  SubCategory? _subCategoryById(String? id) {
    if (id == null) return null;
    for (final s in _subcategories) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Sous-dossier correspondant à [id], ou `null` si introuvable/absent.
  SubSubCategory? _subSubCategoryById(String? id) {
    if (id == null) return null;
    for (final ss in _subsubcategories) {
      if (ss.id == id) return ss;
    }
    return null;
  }

  /// Texte de recherche complet d'un clip : titre, URL, tags, nom de
  /// catégorie et nom de sous-catégorie, tout normalisé (minuscules, sans
  /// accents) et concaténé en un seul bloc pour la comparaison.
  String _searchHaystackFor(Clip c) {
    final category = categoryById(c.categoryId);
    final sub = _subCategoryById(_clipSubcategoryMap[c.id]);
    final subSub = _subSubCategoryById(_clipSubSubcategoryMap[c.id]);
    return normalizeForSearch([
      c.title,
      c.url,
      c.tags.join(' '),
      category?.name ?? '',
      sub?.name ?? '',
      subSub?.name ?? '',
    ].join(' '));
  }

  List<Clip> get clips {
    var result = _clips;
    if (_searchQuery.isNotEmpty) {
      final tokens = searchTokensFor(_searchQuery);
      if (tokens.isNotEmpty) {
        result = result.where((c) {
          final haystack = _searchHaystackFor(c);
          return tokens.every((t) => haystack.contains(t));
        }).toList();
      }
    }
    return result;
  }

  List<String> get searchSuggestions {
    if (_searchQuery.isEmpty) return [];
    final tokens = searchTokensFor(_searchQuery);
    if (tokens.isEmpty) return [];
    final set = <String>{};
    for (final cat in _categories) {
      final normalizedName = normalizeForSearch(cat.name);
      if (tokens.every((t) => normalizedName.contains(t))) {
        set.add(cat.name);
      }
    }
    for (final sub in _subcategories) {
      final normalizedName = normalizeForSearch(sub.name);
      if (tokens.every((t) => normalizedName.contains(t))) {
        set.add(sub.name);
      }
    }
    for (final subSub in _subsubcategories) {
      final normalizedName = normalizeForSearch(subSub.name);
      if (tokens.every((t) => normalizedName.contains(t))) {
        set.add(subSub.name);
      }
    }
    for (final c in _clips) {
      final normalizedTitle = normalizeForSearch(c.title);
      if (tokens.every((t) => normalizedTitle.contains(t))) {
        set.add(c.title);
      }
      for (final t in c.tags) {
        final normalizedTag = normalizeForSearch(t);
        if (tokens.every((tok) => normalizedTag.contains(tok))) {
          set.add('#$t');
        }
      }
    }
    return set.take(5).toList();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    _clips = await DatabaseHelper.instance.getAllClips();
    // Recorrige rétroactivement la plateforme des clips déjà enregistrés
    // (ex. anciens liens Pinterest/Instagram tombés dans "Autre" avant que
    // la détection ne soit corrigée) : purement recalculé à partir de
    // l'URL déjà stockée, sans appel réseau, et ne touche à rien d'autre
    // (titre, catégorie, vignette, position...). Contrairement à
    // l'ancienne migration icône/couleur retirée ci-dessus, `platform`
    // n'est jamais modifiable par l'utilisateur : recalculer cette valeur
    // ne peut donc jamais écraser un choix qu'il aurait fait.
    for (var i = 0; i < _clips.length; i++) {
      final c = _clips[i];
      final detected = SocialPlatform.detect(c.url).id;
      if (detected != c.platform) {
        final fixed = Clip(
          id: c.id,
          url: c.url,
          title: c.title,
          platform: detected,
          categoryId: c.categoryId,
          tags: c.tags,
          addedAt: c.addedAt,
          thumbnailUrl: c.thumbnailUrl,
          position: c.position,
          channel: c.channel,
          description: c.description,
        );
        _clips[i] = fixed;
        unawaited(DatabaseHelper.instance.upsertClip(fixed));
      }
    }
    await _mergeDuplicateClips();
    // Les couleurs/icônes des catégories standard (cat_xxx) sont déjà
    // correctement définies à la création (voir plus bas dans ce fichier).
    // On ne les réécrase plus ici à chaque chargement : une ancienne
    // "migration" le faisait systématiquement, ce qui annulait silencieusement
    // tout renommage/changement d'icône fait par l'utilisateur dans l'onglet
    // Catégories dès le redémarrage suivant de l'app.
    _categories = await DatabaseHelper.instance.getAllCategories();
    final subMaps = await DatabaseHelper.instance.getAllSubCategories();
    _subcategories = subMaps.map(SubCategory.fromMap).toList();
    _clipSubcategoryMap = await DatabaseHelper.instance.getClipSubcategoryMapAll();
    final subSubMaps = await DatabaseHelper.instance.getAllSubSubCategories();
    _subsubcategories = subSubMaps.map(SubSubCategory.fromMap).toList();
    _clipSubSubcategoryMap = await DatabaseHelper.instance.getClipSubSubcategoryMapAll();
    _isLoading = false;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Adresses normalisees en cours d'enregistrement : ferme la fenetre
  /// entre la verification et l'insertion (deux partages simultanes du
  /// meme lien, double appui sur Enregistrer).
  final Set<String> _addingUrls = {};

  /// Enregistre [clip]. Renvoie false, sans rien ecrire, si un clip de
  /// meme adresse normalisee existe deja ou est en cours d'ajout. Dernier
  /// rempart commun a toutes les voies d'ajout (partage, boite de
  /// partage, formulaire, import de playlist).
  Future<bool> addClip(Clip clip) async {
    final key = _normalizeUrl(clip.url);
    if (_addingUrls.contains(key) ||
        _clips.any((c) => _normalizeUrl(c.url) == key)) {
      debugPrint('[dedup] doublon refuse : ${clip.url}');
      return false;
    }
    _addingUrls.add(key);
    try {
      await DatabaseHelper.instance.insertClip(clip);
      _clips.insert(0, clip);
    } finally {
      _addingUrls.remove(key);
    }
    notifyListeners();
    if (clip.categoryId == null) _schedulePendingClassificationRefresh(clip);
    return true;
  }

  /// Durée pendant laquelle un clip sans catégorie est considéré « en
  /// cours de classement » par l'interface.
  static const Duration pendingClassificationWindow = Duration(seconds: 45);

  /// Clips dont le classement est termine, avec ou sans categorie.
  ///
  /// La fenetre ci-dessus n'est plus qu'un garde-fou : « en cours » cesse
  /// des que le classement rend la main, au lieu d'attendre la fin du delai
  /// quand il se termine sans categorie (confiance trop basse, « A trier »,
  /// Claude indisponible, aucun signal exploitable).
  final Set<String> _classificationDone = {};

  /// Marque le classement d'un clip comme termine et reveille l'interface.
  void markClassificationDone(String clipId) {
    if (!_classificationDone.add(clipId)) return;
    try {
      notifyListeners();
    } catch (_) {}
  }

  /// Vrai tant que le clip est sans categorie, que son classement n'est pas
  /// termine et que la fenetre de securite n'est pas ecoulee.
  bool isClassificationPending(Clip clip) =>
      clip.categoryId == null &&
      !_classificationDone.contains(clip.id) &&
      DateTime.now().difference(clip.addedAt) < pendingClassificationWindow;

  /// Réveille l'interface à la fin de la fenêtre d'attente.
  ///
  /// `hasPendingClassification` dépend de l'heure courante, mais n'est
  /// réévalué qu'au moment d'un redessin. Or plusieurs chemins de
  /// classification se terminent sans jamais notifier : confiance trop
  /// basse, aucune catégorie exploitable, repli par mots-clés
  /// infructueux, et — depuis l'ajout du garde-fou — les clips sans
  /// aucun signal exploitable, pour lesquels le classifieur n'est même
  /// plus appelé.
  ///
  /// Sans ce réveil, la tuile « Tout » restait figée sur `ReelrLoader`,
  /// une animation `..repeat()` : l'écran se redessinait en continu et
  /// consommait de la batterie indéfiniment, en donnant l'impression que
  /// l'application cherchait encore.
  void _schedulePendingClassificationRefresh(Clip clip) {
    final remaining =
        pendingClassificationWindow - DateTime.now().difference(clip.addedAt);
    if (remaining.isNegative) return;
    Timer(remaining + const Duration(milliseconds: 200), () {
      // Le notifier peut avoir ete dispose entre-temps.
      try {
        notifyListeners();
      } catch (_) {}
    });
  }

  ClipCategory? findBestCategoryMatch(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    // 1. Match exact par ID (cat_xxx)
    for (final cat in _categories) {
      if (cat.id == name.trim()) return cat;
    }
    // 2. Match exact par nom, insensible aux accents, a la casse et au
    // pluriel simple (« Beaute » = « Beauté »).
    final comparable = AppL10n.normalizeCategoryLabel(name);
    for (final cat in _categories) {
      if (AppL10n.normalizeCategoryLabel(cat.name) == comparable) return cat;
    }
    // 2bis. Meme categorie standard dans l'autre langue (ex. "Food" /
    // "Recette") : l'IA repond toujours dans la langue fixee par son
    // prompt, indifferemment de la langue de l'app. Sans cette etape, une
    // categorie existante nommee "Recette" n'etait jamais retrouvee quand
    // Claude renvoyait "Food", et une seconde categorie naissait pour la
    // meme chose. Generalise a tout le catalogue standard `cat_xxx`, pas
    // seulement a Food/Recette.
    final canonicalId = AppL10n.canonicalCategoryId(name);
    if (canonicalId != null) {
      for (final cat in _categories) {
        if (cat.id == canonicalId ||
            AppL10n.canonicalCategoryId(cat.name) == canonicalId) {
          return cat;
        }
      }
    }
    // 3. Match partiel par nom
    for (final cat in _categories) {
      final cName = cat.name.trim().toLowerCase();
      // `A && B || C` s'evaluait `(A && B) || C` : la branche C
      // (`normalized.contains(cName)`) n'avait aucune garde de longueur, si
      // bien qu'une categorie courte absorbait n'importe quel nom la
      // contenant. On applique desormais la meme regle symetrique que
      // `CategoryClassifier.matchExisting` : le plus court doit representer
      // plus de 60 % du plus long.
      final shorter = cName.length <= normalized.length ? cName : normalized;
      final longer = cName.length > normalized.length ? cName : normalized;
      if (shorter.length >= 5 &&
          longer.contains(shorter) &&
          shorter.length / longer.length > 0.6) {
        return cat;
      }
    }
    return null;
  }

  Future<void> classifyClipInBackground(Clip clip) async {
    try {
      debugPrint('[classify] starting for: ${clip.title}');
      _registerForBatch(clip);
      final sw = Stopwatch()..start();
      final profile = await ProfileService().loadProfile();
      // Twitch = Gaming, toujours (regle d'Anne, 2026-10-08). Meme traitement
      // que le titre « Twitch » seul : Gaming par defaut, sans appel a
      // Claude. Avant, un profil (« Nico_la - Live on Twitch ») partait en
      // Voyage a 75 : le titre ne porte que le pseudo et Claude devinait.
      final isTwitchLink = clip.url.toLowerCase().contains('twitch.tv');
      final effectiveTitle = clip.title.isEmpty || clip.title == "Twitch" || isTwitchLink ? "gaming streaming ${clip.url}" : clip.title;
      // Lien web hors plateformes connues (article, boutique, fiche...) :
      // les couches locales 1 et 2 sont reglees sur des titres de videos
      // et sur des createurs. Sur une page web, le titre porte souvent un
      // rayon ou un fil d'Ariane (« Amazon.fr: Cuisine et Maison » a envoye
      // un matelas dans Food) et `channel` vaut og:site_name (« Amazon.fr »,
      // « Le Monde ») : un mot-cle fortuit, un media connu ou l'historique
      // du site decidaient sans consulter Claude. Ces liens passent donc
      // toujours par Claude. Les videos ne sont pas concernees.
      final isWebLink = SocialPlatform.detect(clip.url).id == 'other';
      String? catName;
      // Journal de decision. Ces informations arrivaient deja de Claude mais
      // etaient silencieusement jetees : `updateClipClassification` existait
      // sans jamais etre appelee. On ne change rien au classement, on arrete
      // seulement de perdre l'explication.
      var decisionSource = "aucune";
      var decisionConfidence = 0;
      var decisionReason = "";
      var decisionTags = const <String>[];

      // Court-circuit local, dans l'ordre de fiabilite :
      // 1) Marque/influenceur/media connu (liste figee, fiable des la 1ere fois)
      catName = isWebLink
          ? null
          : CategoryClassifier.detectStrongMatch(effectiveTitle, channel: clip.channel);
      if (catName != null) {
        debugPrint('[classify] correspondance forte -> $catName (Claude saute)');
        decisionSource = "couche 1 · mots-clés locaux";
        decisionReason = "Marque, influenceur ou mot-clé fort reconnu dans le "
            "titre. Claude n'a pas été appelé.";
      }

      // 1 bis) Site de reservation de voyage (Booking, Airbnb, Expedia,
      // Hotels.com, Trivago, Tripadvisor) : toujours Voyage. Claude
      // hesitait selon le nom de l'hotel (« Suites FL » parti en Immo,
      // « B&B Hotel » en Voyage).
      if (catName == null && isWebLink) {
        final host = Uri.tryParse(clip.url)?.host.toLowerCase() ?? '';
        final isTravelBooking = RegExp(
          r'(^|\.)(booking\.com|hotels\.com|airbnb\.[a-z.]+|'
          r'expedia\.[a-z.]+|trivago\.[a-z.]+|tripadvisor\.[a-z.]+)$',
        ).hasMatch(host);
        if (isTravelBooking) {
          catName = 'cat_travel';
          debugPrint('[classify] site de reservation $host -> Voyage (Claude saute)');
          decisionSource = "couche 1 bis · site de réservation";
          decisionReason = "Lien d'un site de réservation de voyage "
              "($host). Claude n'a pas été appelé.";
        }
      }

      // 1 quater) Tuile personnelle portant le nom du site (ex. tuile
      // « Vinted » pour un lien vinted.fr, « Carrefour » pour carrefour.fr)
      // : routage local, sans Claude. Claude connait mal les tuiles
      // personnelles et classait Vinted en Mode avec 95 de confiance.
      if (catName == null && isWebLink) {
        final named = _customCategoryMatchingSite(clip.url, clip.channel);
        if (named != null) {
          catName = named.name;
          debugPrint('[classify] tuile personnelle "${named.name}" = site '
              '${_siteKey(clip.url)} (Claude saute)');
          decisionSource = "couche 1 quater · tuile du même nom";
          decisionReason = "Tu as une tuile « ${named.name} » qui porte le "
              "nom de ce site. Claude n'a pas été appelé.";
        }
      }

      // 1 ter) Site web deja range a la main dans une tuile creee par
      // l'utilisatrice (ex. Vinted, Carrefour) : meme tuile, sans Claude.
      // Appris uniquement d'un geste humain (_learnSiteFromUserChoice).
      if (catName == null && isWebLink) {
        final siteCat = _learnedSiteCategory(profile, clip.url);
        if (siteCat != null) {
          catName = siteCat.name;
          debugPrint('[classify] site appris ${_siteKey(clip.url)} -> $catName (Claude saute)');
          decisionSource = "couche 2 bis · site appris";
          decisionReason = "Tu as rangé un lien de ce site dans cette tuile. "
              "Claude n'a pas été appelé.";
        }
      }

      // 1 quinquies) Enseigne commerciale connue (Auchan, Lidl, Amazon,
      // Walmart, Tesco...) : une tuile par enseigne, creee au premier lien,
      // quel que soit le produit (litiere, jouet, courses). Passe apres les
      // choix de l'utilisatrice : une tuile du meme nom ou un site range a
      // la main gagnent toujours.
      if (catName == null && isWebLink) {
        await OEmbedService.loadShopHosts();
        final shopHost = _linkHost(clip.url);
        // Enseigne connue : une tuile par enseigne. Autre boutique : pas de
        // tuile automatique (une liste du meme sujet reste ensemble) ; on
        // n'utilise qu'une tuile du meme nom DEJA existante.
        final knownBrand = _retailBrandOf(shopHost);
        final otherBrand = (knownBrand == null &&
                OEmbedService.isShopHost(shopHost))
            ? (_brandInTitle(clip.title) ?? _shopNameFor(clip, shopHost))
            : null;
        final brand = knownBrand ??
            ((otherBrand != null && findBestCategoryMatch(otherBrand) != null)
                ? otherBrand
                : null);
        if (otherBrand != null && brand == null) {
          debugPrint('[classify] boutique $otherBrand : pas de tuile '
              'automatique, classement par sujet');
        }
        if (brand != null) {
          final tile = await addCategory(ClipCategory(
            id: const Uuid().v4(),
            name: brand,
            color: _brandColor(brand),
            icon: Icons.storefront_rounded,
          ));
          catName = tile.name;
          debugPrint('[classify] enseigne $brand -> tuile "${tile.name}" '
              '(Claude saute)');
          decisionSource = "couche 2 ter · enseigne";
          decisionReason = "Lien d'une enseigne commerciale ($brand) : "
              "tuile dédiée. Claude n'a pas été appelé.";
        }
      }

      // 2) Chaine deja vue et apprise automatiquement -- SAUF si le titre
      // de CETTE video porte un indice, meme faible, vers une AUTRE
      // categorie precise. Sans ce garde-fou, un createur a contenu mixte
      // (ex. tricot ET crochet) voit toutes ses videos forcees dans la
      // categorie dominante de son historique, meme quand le titre dit
      // clairement autre chose (observe en production : une video de
      // crochet classee Tricot). Seuil abaisse a 2 (vs. 3 pour une
      // correspondance forte autonome, cf. `detectStrongMatch`) : on ne
      // decide pas seul avec un indice faible, on evite seulement
      // d'ecraser l'evidence du titre avec l'historique de la chaine.
      if (catName == null &&
          !isWebLink &&
          clip.channel != null &&
          clip.channel!.isNotEmpty) {
        final learned = profile.learnedCategoryForChannel(clip.channel!);
        if (learned != null) {
          final hint = CategoryClassifier.detectStrongMatch(
              effectiveTitle,
              minScore: 2);
          final learnedCat = findBestCategoryMatch(learned);
          final hintContradictsLearned = hint != null &&
              learnedCat != null &&
              hint.toLowerCase() != learnedCat.name.trim().toLowerCase();
          if (!hintContradictsLearned) {
            catName = learned;
            debugPrint('[classify] chaine connue "${clip.channel}" -> $catName (Claude saute)');
            decisionSource = "couche 2 · chaîne apprise";
            decisionReason = "La chaîne « ${clip.channel} » a déjà été classée "
                "au moins 3 fois dans cette catégorie. Claude n'a pas été "
                "appelé. Cet apprentissage vient des prédictions passées, pas "
                "de tes corrections.";
          } else {
            debugPrint('[classify] chaine connue "${clip.channel}" -> $learned, '
                'mais le titre suggere "$hint" : appel de Claude par '
                'prudence (chaine possiblement a contenu mixte).');
          }
        }
      }

      // 3) Vocabulaire personnel appris automatiquement -- DESACTIVE :
      // ce mecanisme apprend mot par mot (y compris des mots generiques
      // comme "vie", "affaire") et peut court-circuiter Claude a tort.
      // Voir discussion du 2026-08-09. Ne pas reactiver sans garde-fou
      // de discriminance (TF-IDF ou equivalent).
      // catName ??= profile.detectByPersonalVocabulary(effectiveTitle);
      // if (catName != null) {
      //   debugPrint('[classify] vocabulaire personnel -> $catName (Claude saute)');
      // }

      // Garde-fou AVANT l'appel payant, et seulement lui : les couches 1
      // et 2 ci-dessus sont locales, gratuites et deterministes, elles
      // doivent toujours s'executer.
      //
      // Quand la video n'a pas de legende, `_hydrateClip` met le nom du
      // createur en titre. Interroger Claude sur un pseudonyme seul
      // produit une reponse sure d'elle mais arbitraire, et instable :
      // « Mouhamed VJ🤴🏾 » a donne `cat_mode` a 82 de confiance a 15 h,
      // puis `cat_deco` a 65 a 20 h — meme clip, meme entree, deux
      // categories, toutes deux au-dessus du seuil d'application.
      //
      // Mieux vaut ne pas classer : le clip porte alors la puce
      // « À trier », visible et rangeable en un appui — et ce rangement
      // enseigne le createur, donc la prochaine video du meme compte
      // sera tranchee gratuitement par la couche 2.
      final channelTrimmed = clip.channel?.trim() ?? '';
      final titreEstSeulementLeCreateur = channelTrimmed.isNotEmpty &&
          effectiveTitle.trim() == channelTrimmed;
      final aUneDescription = clip.description?.trim().isNotEmpty ?? false;
      if (catName == null && titreEstSeulementLeCreateur && !aUneDescription) {
        debugPrint('[classify] Claude non appele : le titre n\'est que le '
            'createur ("$channelTrimmed"), aucun signal a interpreter');
        return;
      }

      // Lien Google Images : l'adresse porte l'image touchee et les mots de
      // la page d'origine, meme quand la page bloque l'extraction (titre
      // reduit au nom de domaine, vignette locale illisible par Claude).
      final gHints = _googleImagesHints(clip.url);
      // Image de mur de connexion (TikTok...) : aucun contenu, on ne l'envoie pas.
      final rawThumb = clip.thumbnailUrl;
      final isLoginWallImage = rawThumb != null &&
          RegExp(r'login_static|Take_A_Break|login_wall', caseSensitive: false)
              .hasMatch(rawThumb);
      final classifyImage =
          gHints['image'] ?? (isLoginWallImage ? null : rawThumb);
      final classifyDescription = gHints['words'] == null
          ? clip.description
          : [
              if (clip.description?.trim().isNotEmpty ?? false)
                clip.description!.trim(),
              gHints['words']!,
            ].join('\n');

      // Exemples du carnet : rangements faits a la main sur le meme sujet.
      final userExamples = await SortingNotebook().promptExamples(
        [
          effectiveTitle,
          classifyDescription ?? '',
          clip.channel ?? '',
          _linkHost(clip.url),
        ].join(' '),
        excludeId: clip.id,
      );
      if (userExamples.isNotEmpty) {
        debugPrint('[classify] exemples du carnet : $userExamples');
      }

      if (catName == null) {
        try {
          await _ClassifyLimiter.acquire();
          final ClassificationResult result;
          try {
            result = await ClaudeClassifier.classify(
              video: VideoData(
                title: effectiveTitle,
                platform: clip.platform,
                thumbnailUrl: classifyImage,
                channel: clip.channel,
                description: classifyDescription,
              ),
              profile: profile,
              customCategories: _customCategoryNames(),
              userExamples: userExamples,
            );
          } finally {
            _ClassifyLimiter.release();
          }
          catName = result.categoriePrincipale;
          decisionSource = "Claude";
          decisionConfidence = result.confiance;
          decisionReason = result.raison;
          decisionTags = result.tagsSuggeres;
          debugPrint('[classify] result: "${clip.title}" -> $catName | confiance: ${result.confiance}');
          debugPrint('[classify] elapsed: ${sw.elapsedMilliseconds}ms');
          if (result.confiance >= 60) {
            await ProfileService().confirmClassification(
              result: result,
              videoTitle: effectiveTitle,
              channel: clip.channel,
            );
          }
          // ABSTENTION. Mesure du 2026-08-09 sur le jeu golden (127 cas) :
          // sous 40 de confiance, Haiku donne la bonne categorie environ une
          // fois sur quatre. L'ancien comportement — « classement conserve
          // quand meme » — produisait la totalite des erreurs restantes sous
          // seuil. Une tuile fausse abime la confiance dans toute la grille ;
          // un clip a trier ne coute qu'un appui.
          //
          // Le repli mots-cles est retire d'ici volontairement : cette couche
          // n'a jamais ete mesuree sur ces cas precis, et rien ne dit qu'elle
          // fasse mieux que le doute. Elle reste active plus bas, dans le
          // chemin « Claude indisponible », ou elle est le seul recours.
          if (result.confiance < 40) {
            debugPrint('[classify] confiance trop basse (${result.confiance}), clip laisse a trier: ${clip.id}');
            // Le journal est ecrit malgre tout : sans lui, « A trier » serait
            // une boite noire et tu ne saurais pas pourquoi le clip y est.
            await DatabaseHelper.instance.updateClipClassification(
              clipId: clip.id,
              category: "",
              confidence: result.confiance,
              reason: "[abstention] Confiance ${result.confiance}, sous le "
                  "seuil de 40. Raison de Claude : ${result.raison}",
              tags: result.tagsSuggeres,
            );
            return;
          }
        } catch (e) {
          debugPrint('[classify] Claude failed, retrying once: $e');
          try {
            await Future.delayed(const Duration(milliseconds: 300));
            await _ClassifyLimiter.acquire();
            final ClassificationResult retryResult;
            try {
              retryResult = await ClaudeClassifier.classify(
                video: VideoData(
                  title: effectiveTitle,
                  platform: clip.platform,
                  thumbnailUrl: classifyImage,
                  channel: clip.channel,
                  description: classifyDescription,
                ),
                profile: profile,
                customCategories: _customCategoryNames(),
                userExamples: userExamples,
              );
            } finally {
              _ClassifyLimiter.release();
            }
            catName = retryResult.categoriePrincipale;
            decisionSource = "Claude (2e tentative)";
            decisionConfidence = retryResult.confiance;
            decisionReason = retryResult.raison;
            decisionTags = retryResult.tagsSuggeres;
            debugPrint('[classify] retry succeeded: $catName');
          } catch (e2) {
            debugPrint('[classify] retry failed, falling back to keywords: $e2');
            final existingNames = _categories.map((c) => c.name).toList();
            catName = CategoryClassifier.detectByKeywords(effectiveTitle, existingNames);
            if (catName == null) {
              debugPrint('[classify] keyword fallback found nothing, clip stays unclassified: ${clip.id}');
              return;
            }
            debugPrint('[classify] keyword fallback result: $catName');
            decisionSource = "repli mots-clés (Claude indisponible)";
            decisionReason = "Claude n'a pas répondu après 2 tentatives. "
                "Classement effectué par mots-clés locaux uniquement.";
          }
        }
      }
      // Claude renvoie parfois un JSON sans `categorie_principale` : le repli
      // de `ClassificationResult.fromJson` vaut alors « À trier ». Sans cette
      // garde, cette chaîne descendait jusqu'à `addCategory` et devenait une
      // vraie catégorie en base — c'est l'origine de la tuile fantôme.
      // On laisse simplement le clip sans catégorie.
      const noResultLabels = {
        'à trier', 'a trier', 'non classé', 'non classe', 'unclassified',
      };
      if (noResultLabels.contains(catName.trim().toLowerCase())) {
        debugPrint('[classify] aucune categorie exploitable, clip laisse a trier: ${clip.id}');
        return;
      }
      _categories = await DatabaseHelper.instance.getAllCategories();
      var matchedCat = findBestCategoryMatch(catName);
      if (matchedCat == null) {
        const catNames = <String, String>{
          'cat_food': 'Food', 'cat_fitness': 'Fitness',
          'cat_gaming': 'Gaming', 'cat_beauty': 'Beauté',
          'cat_mode': 'Mode', 'cat_travel': 'Voyage',
          'cat_humour': 'Humour', 'cat_musique': 'Musique',
          'cat_wellness': 'Bien-être', 'cat_podcast': 'Podcast',
          'cat_famille': 'Famille', 'cat_finance': 'Finance',
          'cat_business': 'Business', 'cat_actu': 'Actualités',
          'cat_societe': 'Société', 'cat_diy': 'DIY',
          'cat_deco': 'Déco', 'cat_auto': 'Auto', 'cat_moto': 'Moto',
          'cat_culture': 'Culture', 'cat_cinema': 'Cinéma',
          'cat_growth': 'Dév. Personnel', 'cat_pets': 'Animaux',
          'cat_nature': 'Nature', 'cat_truecrime': 'True Crime',
          'cat_astro': 'Astrologie', 'cat_sport': 'Sport',
          'cat_sante': 'Santé', 'cat_science': 'Science',
          'cat_bebe': 'Bébé', 'cat_tricot': 'Couture', 'cat_tricotage': 'Tricot', 'cat_crochet': 'Crochet', 'cat_broderie': 'Broderie',
          'cat_doc': 'Documentaire', 'cat_religion': 'Religion',
          'cat_immo': 'Immobilier', 'cat_manga': 'Anime & Manga',
          'cat_politique': 'Politique', 'cat_crypto': 'Crypto',
          'cat_lang': 'Langues', 'cat_histoire': 'Histoire',
          'cat_art': 'Art', 'cat_photo': 'Photo',
          'cat_outdoor': 'Outdoor', 'cat_psycho': 'Psychologie',
          'cat_luxe': 'Luxe', 'cat_entrepreneuriat': 'Entrepreneuriat',
          'cat_education': 'Éducation', 'cat_cosplay': 'Cosplay',
          'cat_dance': 'Danse', 'cat_comedy': 'Stand-up',
          'cat_jardin': 'Jardinage', 'cat_sport_extreme': 'Extrême',
          'cat_nutrition': 'Nutrition', 'cat_vintage': 'Vintage',
          'cat_fail': 'Fails',
          'cat_vibes': 'Vibes', 'cat_tech': 'Tech',
          'cat_shopping': 'Shopping',
          'cat_design': 'Design & UX',
        };
        // `catName` est le libelle brut renvoye par Claude (ex. "Food"),
        // jamais un ID `cat_xxx` litteral : l'ancien test
        // `catName.startsWith('cat_')` etait donc toujours faux, et CHAQUE
        // nouvelle categorie IA partait avec un ID `ai_<timestamp>` et les
        // couleurs/icones par defaut, sans jamais rejoindre le catalogue
        // standard localise ci-dessus. On resout maintenant le libelle vers
        // son ID canonique (FR ou EN) quand il est reconnu, pour que Food et
        // Recette (ou toute autre paire FR/EN du catalogue) restent une
        // seule et meme categorie, quelle que soit la langue dans laquelle
        // Claude a repondu.
        final canonicalId = AppL10n.canonicalCategoryId(catName);
        final resolvedKey = canonicalId ?? catName;
        final isCatId = canonicalId != null;
        final newCat = ClipCategory(
          id: isCatId ? resolvedKey : 'ai_${DateTime.now().millisecondsSinceEpoch}',
          name: catNames[resolvedKey] ?? catName,
          // Couleur/icone : source unique dans AppL10n (voir sa doc), pour
          // ne plus jamais diverger de ce que `DatabaseHelper` utilise pour
          // reparer les categories existantes tombees sur le violet/dossier
          // par defaut.
          color: AppL10n.categoryColors[resolvedKey] ?? const Color(0xFF7C3AED),
          icon: AppL10n.categoryIcons[resolvedKey] ?? Icons.folder_rounded,
        );
        matchedCat = await addCategory(newCat);
      }
      Clip current = clip;
      for (final c in _clips) {
        if (c.id == clip.id) {
          current = c;
          break;
        }
      }
      if (current.categoryId != null) return;
      final updated = current.copyWith(categoryId: matchedCat.id);
      await updateClip(updated);
      // L'ordre n'est plus contraint depuis que `updateClip` passe par
      // `upsertClip` : un UPDATE partiel ne touche plus aux colonnes
      // classification_*. On le conserve tel quel, il reste le plus lisible
      // — le clip existe avant qu'on journalise sa classification.
      await DatabaseHelper.instance.updateClipClassification(
        clipId: updated.id,
        category: catName,
        confidence: decisionConfidence,
        reason: "[$decisionSource] $decisionReason",
        tags: decisionTags,
      );
      _newlyClassifiedCategoryIds.add(matchedCat.id);
      _categories = await DatabaseHelper.instance.getAllCategories();
      _clips = await DatabaseHelper.instance.getAllClips();
      notifyListeners();
    } catch (e) {
      debugPrint('[classify] error: $e');
    } finally {
      // Fin du classement, avec ou sans categorie : l'interface cesse
      // d'afficher « en cours » tout de suite.
      markClassificationDone(clip.id);
    }
  }

  // ─────────────────────────────────────────────
  // CLASSEMENT DU LOT (2026-10-07)
  //
  // Des liens partages ensemble ont souvent une intention commune (une
  // recherche d'inspiration : UX, couleurs...), que le classement lien par
  // lien ne voit pas : Tech, Art, Deco, Photo pour le meme sujet. Une fois
  // le lot au calme, UN seul appel Claude lit tous les titres ensemble. Si
  // un sujet commun ressort avec assez de confiance, les liens juges par
  // la machine (ou laisses a trier) rejoignent cette categorie. Un lien
  // deja range a la main, ou decide par une regle locale, n'est jamais
  // deplace.
  // ─────────────────────────────────────────────
  final Set<String> _batchIds = {};
  Timer? _batchTimer;
  static const Duration _batchQuietDelay = Duration(seconds: 8);
  static const int _batchMinItems = 3;
  // Un sous-groupe de meme sujet (plantes, entreprises...) a partir de 2 liens.
  static const int _batchMinGroup = 2;
  static const int _batchMaxItems = 20;
  static const int _batchMinConfidence = 75;

  /// Note qu'un lien vient d'etre classe. Seuls les liens ajoutes dans les
  /// dernieres minutes comptent : une reclassification d'anciens clips ne
  /// forme pas un lot.
  void _registerForBatch(Clip clip) {
    if (DateTime.now().difference(clip.addedAt) > const Duration(minutes: 10)) {
      return;
    }
    _batchIds.add(clip.id);
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchQuietDelay, () {
      final ids = _batchIds.toList();
      _batchIds.clear();
      if (ids.length >= _batchMinGroup) unawaited(_reviewBatch(ids));
    });
  }

  Future<void> _reviewBatch(List<String> ids) async {
    try {
      _categories = await DatabaseHelper.instance.getAllCategories();
      final items = <_BatchItem>[];
      for (final id in ids.take(_batchMaxItems)) {
        final clip = _clips.where((c) => c.id == id).firstOrNull;
        if (clip == null) continue;
        final journal =
            await DatabaseHelper.instance.getClassificationDiagnostic(id);
        if (journal == null) continue;
        final reason = (journal['classification_reason'] as String?) ?? '';
        final predicted =
            (journal['classification_category'] as String?)?.trim() ?? '';
        final conf = (journal['classification_confidence'] as int?) ?? 0;
        // Decision d'une regle locale (couches 1, 2, site appris...) : on
        // n'y touche pas.
        final localRule = reason.startsWith('[') &&
            !reason.startsWith('[Claude') &&
            !reason.startsWith('[abstention]');
        if (localRule) continue;
        final current = clip.categoryId;
        final bool eligible;
        var isAnchor = false;
        if (current == null || current.isEmpty) {
          // Laisse a trier : abstention ou aucun resultat, personne ne l'a
          // range.
          eligible = predicted.isEmpty;
        } else {
          // Range par la machine et pas deplace depuis, avec une confiance
          // pas deja tres haute.
          final cat = predicted.isEmpty ? null : findBestCategoryMatch(predicted);
          final machineDecided = cat != null && cat.id == current;
          // Un lien deja sur de lui (>= 90) ne bouge jamais, mais il reste
          // dans le lot comme « ancre » : la serie suit sa categorie.
          isAnchor = machineDecided && conf >= 90;
          eligible = machineDecided;
        }
        if (!eligible) continue;
        final hints = _googleImagesHints(clip.url);
        final info = '${clip.title} ${hints['words'] ?? ''} '
            '${clip.channel ?? ''}';
        // Un lien sans aucun mot exploitable n'apporte rien au lot.
        if (SortingNotebook.tokens(info).length < 2) continue;
        final flat = clip.title.replaceAll(RegExp(r'\s+'), ' ').trim();
        final shortTitle =
            flat.length > 90 ? '${flat.substring(0, 90)}…' : flat;
        final ref = hints['ref_words'];
        final host = _linkHost(clip.url);
        final line = '$shortTitle'
            '${ref != null ? ' ($ref)' : ''}'
            '${host.isNotEmpty ? ' [$host]' : ''}';
        final tags = ((journal['classification_tags'] as String?) ?? '')
            .split(',')
            .where((t) => t.trim().isNotEmpty)
            .toList();
        items.add(_BatchItem(clip, line, tags, current,
            SortingNotebook.tokens(info).map(_stem).toSet(),
            anchor: isAnchor, image: _lotImage(clip)));
      }
      if (items.length < _batchMinGroup) {
        debugPrint('[lot] ${items.length} lien(s) eligible(s), rien a faire');
        return;
      }

      // 0) Lecture du lot en une fois : Claude separe les liens en
      // groupes de meme sujet (mesure : 29/29 contre 24/29 lien par
      // lien). Si l'appel echoue, les passes ci-dessous prennent le
      // relais comme avant.
      if (await _partitionAndMove(items)) return;

      // 1) Le lot entier : un seul sujet commun ?
      var wholeTried = false;
      if (items.length >= _batchMinItems) {
        wholeTried = true;
        if (await _classifyAndMoveGroup(items, 'lot')) return;
      }
      // 2) Sinon, sous-groupes de meme sujet (mots communs) : un lot
      // melange (plantes + entreprises + archives...) est range groupe par
      // groupe au lieu d'etre refuse en bloc.
      final groups = _clusterBatch(items);
      for (final g in groups) {
        if (wholeTried && g.length == items.length) continue;
        await _classifyAndMoveGroup(g, 'sous-groupe');
      }
    } catch (e) {
      debugPrint('[lot] erreur: $e');
    }
  }

  /// Racine grossiere d'un mot (pluriel, feminin) pour rapprocher
  /// "plante"/"plantes", "verte"/"vertes".
  static String _stem(String w) {
    var t = w;
    if (t.length > 3 && (t.endsWith('s') || t.endsWith('x'))) {
      t = t.substring(0, t.length - 1);
    }
    if (t.length > 4 && t.endsWith('e')) t = t.substring(0, t.length - 1);
    return t;
  }

  /// Regroupe les liens du lot qui partagent au moins 2 mots (composantes
  /// connexes). Ne garde que les groupes d'au moins [_batchMinGroup] liens.
  List<List<_BatchItem>> _clusterBatch(List<_BatchItem> items) {
    final parent = List<int>.generate(items.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        if (items[i].tokens.intersection(items[j].tokens).length >= 2) {
          parent[find(i)] = find(j);
        }
      }
    }
    final byRoot = <int, List<_BatchItem>>{};
    for (var i = 0; i < items.length; i++) {
      byRoot.putIfAbsent(find(i), () => []).add(items[i]);
    }
    return [
      for (final g in byRoot.values)
        if (g.length >= _batchMinGroup) g,
    ];
  }

  /// Soumet [group] a Claude comme un lot et range les liens dans la
  /// categorie commune si la confiance est suffisante. Renvoie true si une
  /// categorie commune a ete retenue (meme si aucun lien n'a eu a bouger).
  Future<bool> _classifyAndMoveGroup(List<_BatchItem> group, String kind) async {
    // Que des liens surs : rien a deplacer.
    if (group.every((it) => it.anchor)) return false;
    final numbered = StringBuffer();
    for (var i = 0; i < group.length; i++) {
      numbered.writeln('${i + 1}. ${group[i].line}');
    }
    final profile = await ProfileService().loadProfile();
    final ClassificationResult result;
    await _ClassifyLimiter.acquire();
    try {
      result = await ClaudeClassifier.classify(
        video: VideoData(
          title: 'Lot de ${group.length} liens partagés en même temps :\n'
              '$numbered',
          platform: 'other',
          description: 'Ces liens ont été partagés ensemble : ils ont '
              'probablement un sujet commun. Si un sujet commun ressort, '
              'classe le lot dans la catégorie de ce sujet. Si les liens '
              'parlent de sujets sans rapport, mets une confiance de 30 '
              'ou moins.',
        ),
        profile: profile,
        customCategories: _customCategoryNames(),
      );
    } finally {
      _ClassifyLimiter.release();
    }
    final target = result.categoriePrincipale;
    debugPrint('[lot] $kind de ${group.length} liens -> $target '
        '(confiance ${result.confiance}) : ${result.raison}');
    const noResult = {'à trier', 'a trier', 'non classé', 'non classe'};
    if (result.confiance < _batchMinConfidence ||
        target.trim().isEmpty ||
        noResult.contains(target.trim().toLowerCase())) {
      return false;
    }
    _categories = await DatabaseHelper.instance.getAllCategories();
    var cat =
        findBestCategoryMatch(target) ?? await _ensureStandardCategory(target);
    // Si des liens surs (ancres) sont deja ranges ensemble dans UNE
    // categorie, la serie les rejoint : on ne contredit pas un lien sur.
    final anchorCats = {
      for (final it in group)
        if (it.anchor && it.categoryAtStart != null) it.categoryAtStart!,
    };
    if (anchorCats.length == 1) {
      final anchorCat = _categories
          .where((c) => c.id == anchorCats.first)
          .firstOrNull;
      if (anchorCat != null) cat = anchorCat;
    }
    if (cat == null) {
      debugPrint('[lot] categorie $target introuvable, $kind ignore');
      return false;
    }
    var moved = 0;
    for (final it in group) {
      if (it.anchor) continue;
      final fresh = _clips.where((c) => c.id == it.clip.id).firstOrNull;
      if (fresh == null) continue;
      // Rangé à la main pendant l'analyse : on n'y touche pas.
      if (fresh.categoryId != it.categoryAtStart) continue;
      if (fresh.categoryId == cat.id) continue;
      await updateClip(fresh.copyWith(categoryId: cat.id));
      await DatabaseHelper.instance.updateClipClassification(
        clipId: fresh.id,
        category: anchorCats.length == 1 ? cat.id : target,
        confidence: result.confiance,
        reason: '[lot] ${group.length} liens partagés ensemble, sujet '
            'commun : ${result.raison}',
        tags: it.tags,
      );
      moved++;
    }
    debugPrint('[lot] $moved lien(s) range(s) dans ${cat.name}');
    if (moved > 0) {
      _newlyClassifiedCategoryIds.add(cat.id);
      _categories = await DatabaseHelper.instance.getAllCategories();
      _clips = await DatabaseHelper.instance.getAllClips();
      notifyListeners();
    }
    return true;
  }

  /// Vignette d'un lien pour la lecture groupee : https uniquement, pas la
  /// capture du proxy, pas une image de mur de connexion.
  String? _lotImage(Clip clip) {
    final hints = _googleImagesHints(clip.url);
    final raw = (hints['image'] ?? clip.thumbnailUrl)?.trim();
    if (raw == null || !raw.startsWith('https://')) return null;
    if (raw.contains('reelr-proxy')) return null;
    if (RegExp(r'login_static|Take_A_Break|login_wall', caseSensitive: false)
        .hasMatch(raw)) {
      return null;
    }
    return raw;
  }

  /// Lecture groupee d'un lot (2026-10-08) : UN appel qui separe les liens
  /// en groupes de meme sujet. Chaque groupe d'au moins 2 liens, avec une
  /// confiance >= [_batchMinConfidence], est range dans une meme categorie.
  /// Un lien ancre (>= 90) ne bouge pas mais sa categorie guide le groupe.
  /// Renvoie false si l'appel a echoue (les anciennes passes s'executent),
  /// true sinon (le lot a ete lu, meme si rien n'a bouge).
  Future<bool> _partitionAndMove(List<_BatchItem> items) async {
    List<LotGroup>? groups;
    await _ClassifyLimiter.acquire();
    try {
      groups = await ClaudeClassifier.classifyLot(
          [for (final it in items) it.line],
          _customCategoryNames(),
          [for (final it in items) it.image]);
    } catch (e) {
      debugPrint('[lot] lecture groupee echouee: $e');
      return false;
    } finally {
      _ClassifyLimiter.release();
    }
    if (groups == null || groups.isEmpty) return false;
    debugPrint('[lot] lecture groupee de ${items.length} liens -> '
        '${groups.length} groupe(s)');
    const noResult = {'à trier', 'a trier', 'non classé', 'non classe'};
    _categories = await DatabaseHelper.instance.getAllCategories();
    var movedTotal = 0;
    for (final g in groups) {
      final members = [for (final n in g.links) items[n - 1]];
      if (members.length < _batchMinGroup) continue;
      if (members.every((it) => it.anchor)) continue;
      final target = g.category;
      debugPrint('[lot] groupe de ${members.length} -> $target '
          '(confiance ${g.confidence}) : ${g.reason}');
      if (target == null ||
          target.trim().isEmpty ||
          noResult.contains(target.trim().toLowerCase()) ||
          g.confidence < _batchMinConfidence) {
        continue;
      }
      var cat = findBestCategoryMatch(target) ??
          await _ensureStandardCategory(target);
      // Si des liens surs (ancres) sont deja ranges ensemble dans UNE
      // categorie, la serie les rejoint : on ne contredit pas un lien sur.
      final anchorCats = {
        for (final it in members)
          if (it.anchor && it.categoryAtStart != null) it.categoryAtStart!,
      };
      if (anchorCats.length == 1) {
        final anchorCat =
            _categories.where((c) => c.id == anchorCats.first).firstOrNull;
        if (anchorCat != null) cat = anchorCat;
      }
      if (cat == null) {
        debugPrint('[lot] categorie $target introuvable, groupe ignore');
        continue;
      }
      var moved = 0;
      for (final it in members) {
        if (it.anchor) continue;
        final fresh = _clips.where((c) => c.id == it.clip.id).firstOrNull;
        if (fresh == null) continue;
        // Range a la main pendant l'analyse : on n'y touche pas.
        if (fresh.categoryId != it.categoryAtStart) continue;
        if (fresh.categoryId == cat.id) continue;
        await updateClip(fresh.copyWith(categoryId: cat.id));
        await DatabaseHelper.instance.updateClipClassification(
          clipId: fresh.id,
          category: anchorCats.length == 1 ? cat.id : target,
          confidence: g.confidence,
          reason: '[lot] ${members.length} liens partagés ensemble, sujet '
              'commun : ${g.reason}',
          tags: it.tags,
        );
        moved++;
      }
      debugPrint('[lot] $moved lien(s) range(s) dans ${cat.name}');
      if (moved > 0) {
        _newlyClassifiedCategoryIds.add(cat.id);
        movedTotal += moved;
      }
    }
    if (movedTotal > 0) {
      _categories = await DatabaseHelper.instance.getAllCategories();
      _clips = await DatabaseHelper.instance.getAllClips();
      notifyListeners();
    }
    return true;
  }

  /// Cree la categorie standard [rawId] (ex. cat_design) si elle n'existe
  /// pas encore chez l'utilisatrice.
  Future<ClipCategory?> _ensureStandardCategory(String rawId) async {
    final id = AppL10n.canonicalCategoryId(rawId);
    if (id == null) return null;
    final name = AppL10n.standardCategoryName(id);
    if (name == null) return null;
    return addCategory(ClipCategory(
      id: id,
      name: name,
      color: AppL10n.categoryColors[id] ?? const Color(0xFF7C3AED),
      icon: AppL10n.categoryIcons[id] ?? Icons.folder_rounded,
    ));
  }

  Future<void> updateClip(Clip clip) async {
    await DatabaseHelper.instance.upsertClip(clip);
    final idx = _clips.indexWhere((c) => c.id == clip.id);
    if (idx != -1) _clips[idx] = clip;
    notifyListeners();
  }

  /// Compare la categorie choisie a la main par l'utilisateur au verdict que
  /// le classifieur avait journalise. Si les deux different, le geste est une
  /// correction : on l'enregistre.
  ///
  /// Le signal est deduit, jamais demande. Aucun bouton, aucune interface :
  /// deplacer un clip suffit. C'est la lecture du journal, restee sans
  /// appelant depuis son ecriture, qui rend cette deduction possible.
  ///
  /// Echoue en silence et sans rien enregistrer dans tous les cas douteux --
  /// un faux positif apprendrait a l'envers, ce qui coute plus cher que de
  /// rater une correction.
  Future<void> recordUserCategoryChoice(Clip clip, String? newCategoryId) async {
    try {
      if (newCategoryId == null || newCategoryId.isEmpty) return;

      await _recordInNotebook(clip, newCategoryId);

      // Lien de site web range dans une tuile creee par l'utilisatrice :
      // on retient le site (independamment de ce que Claude avait predit).
      await _learnSiteFromUserChoice(clip, newCategoryId);

      final journal =
          await DatabaseHelper.instance.getClassificationDiagnostic(clip.id);
      final predictedRaw =
          (journal?['classification_category'] as String?)?.trim() ?? '';
      // Vide = la machine n'a jamais tranche : soit le clip est anterieur au
      // journal, soit elle s'est abstenue sous le seuil de confiance. Ranger
      // un clip depuis « A trier » enseigne bien quelque chose, mais ce n'est
      // pas une correction -- il n'y a pas d'erreur a corriger. Cas laisse de
      // cote volontairement, a traiter separement.
      if (predictedRaw.isEmpty) {
        // La machine n'a jamais tranche : abstention sous le seuil, ou
        // aucun signal exploitable. Ce n'est pas une correction — il n'y
        // a pas d'erreur a corriger — mais l'utilisateur vient malgre
        // tout d'enseigner quelque chose de precis.
        //
        // On l'enregistre la ou c'est exploitable et sans risque : la
        // chaine. `channelVocabulary` est relu par la couche 2 de la
        // classification, donc la prochaine video du meme createur sera
        // rangee localement, gratuitement et instantanement.
        //
        // Volontairement PAS d'apprentissage mot par mot : c'est
        // `personalVocabulary`, desactive le 2026-08-09 parce qu'il
        // retenait des mots generiques (« vie », « affaire »). Le
        // createur est un signal autrement plus precis.
        await _learnChannelFromUserChoice(clip, newCategoryId);
        return;
      }

      final predicted = findBestCategoryMatch(predictedRaw);
      if (predicted == null) {
        debugPrint('[correction] ignore "${clip.title}" : categorie predite '
            '"$predictedRaw" introuvable dans la taxonomie actuelle');
        return;
      }
      // L'utilisateur confirme le verdict : rien a apprendre.
      if (predicted.id == newCategoryId) {
        debugPrint('[correction] ignore "${clip.title}" : le choix confirme '
            'le verdict (${predicted.name})');
        return;
      }

      ClipCategory? chosen;
      for (final c in _categories) {
        if (c.id == newCategoryId) {
          chosen = c;
          break;
        }
      }
      if (chosen == null) {
        debugPrint('[correction] ignore "${clip.title}" : categorie choisie '
            '$newCategoryId introuvable');
        return;
      }

      // GARDE-FOU. La taxonomie envoyee a Haiku est figee dans le prompt
      // systeme : il ne connait que les identifiants `cat_*`. Une categorie
      // creee a la main (identifiant UUID) lui est donc inatteignable.
      //
      // Enregistrer « Religion -> Messe du dimanche » reviendrait a lui dire
      // « ne reponds pas Religion ici » sans lui laisser de reponse possible.
      // Il choisirait une autre categorie fausse, ou perdrait confiance et
      // s'abstiendrait : strictement pire que de ne rien apprendre.
      //
      // Ce geste-la n'est d'ailleurs pas une correction. Haiku n'avait pas
      // tort : c'est la taxonomie de l'utilisateur qui s'affine sous lui. La
      // leçon est reelle mais releve d'un routage local applique APRES sa
      // reponse, pas d'un enseignement dans le prompt. Faute de conteneur
      // adapte, on la laisse tomber pour l'instant, en le disant.
      if (!chosen.id.startsWith('cat_')) {
        debugPrint('[correction] ignore "${clip.title}" : '
            '"${chosen.name}" est une categorie personnelle, hors de la '
            'taxonomie connue de Haiku — affinage, pas correction');
        return;
      }

      debugPrint('[correction] "${clip.title}" : '
          '${predicted.name} -> ${chosen.name}');
      await ProfileService().correctClassification(
        videoTitle: clip.title,
        wrongCategory: predicted.name,
        correctCategory: chosen.name,
      );
    } catch (e) {
      // Une correction manquee n'est pas une raison de faire echouer le
      // deplacement que l'utilisateur vient de demander.
      debugPrint('[correction] echec silencieux: $e');
    }
  }

  /// Carnet des rangements manuels (voir SortingNotebook) : retient
  /// « ce lien -> cette categorie » pour classer les liens du meme sujet.
  Future<void> _recordInNotebook(Clip clip, String newCategoryId) async {
    ClipCategory? chosen;
    for (final c in _categories) {
      if (c.id == newCategoryId) {
        chosen = c;
        break;
      }
    }
    // Les categories `ai_` sont inventees par la machine : Claude ne peut
    // pas y repondre, un exemple vers elles ne servirait a rien.
    if (chosen == null || chosen.id.startsWith('ai_')) return;
    final hints = _googleImagesHints(clip.url);
    final desc = clip.description?.trim() ?? '';
    final text = [
      clip.title,
      hints['words'] ?? '',
      clip.channel ?? '',
      desc.length > 200 ? desc.substring(0, 200) : desc,
      _linkHost(clip.url),
    ].join(' ');
    final refWords = hints['ref_words'];
    final title = (!clip.title.contains(' ') && refWords != null)
        ? '${clip.title} ($refWords)'
        : clip.title;
    await SortingNotebook().record(NotebookEntry(
      id: clip.id,
      title: title,
      text: text,
      categoryRef: chosen.id.startsWith('cat_') ? chosen.id : chosen.name,
      categoryLabel: chosen.name,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Noms des tuiles creees a la main (identifiant UUID) : inconnues du
  /// prompt systeme de Claude, donc envoyees avec chaque requete.
  List<String> _customCategoryNames() {
    final names = _categories
        .where((c) => !c.id.startsWith('cat_') && !c.id.startsWith('ai_'))
        .map((c) => c.name)
        .where((n) => n.trim().isNotEmpty)
        .toList();
    debugPrint('[classify] tuiles personnelles envoyees a Claude : $names '
        '(sur ${_categories.length} categories)');
    return names;
  }

  static String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Tuile personnelle dont le nom est celui du site du lien : un mot du
  /// nom de domaine (hors extension) ou la chaine (og:site_name) vaut le
  /// nom de la tuile, tel quel. Une seule tuile doit correspondre.
  ClipCategory? _customCategoryMatchingSite(String url, String? channel) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return null;
    final labels = host.split('.');
    // Retire l'extension (fr, com, net...) et « www ».
    final words = <String>{
      for (final l in labels.take(labels.length > 1 ? labels.length - 1 : 1))
        if (l != 'www') _norm(l),
    };
    final ch = _norm(channel ?? '');
    final chBase = ch;
    final matches = _categories.where((c) {
      if (c.id.startsWith('cat_') || c.id.startsWith('ai_')) return false;
      final n = _norm(c.name);
      if (n.length < 3) return false;
      return words.contains(n) || n == chBase ||
          // « Carrefour.fr » -> « carrefourfr »
          (ch.isNotEmpty && ch.startsWith(n) && ch.length - n.length <= 3);
    }).toList();
    return matches.length == 1 ? matches.first : null;
  }

  /// Cle de site (« vinted.fr ») pour un lien web, ou null.
  static String? _siteKey(String url) {
    var uri = Uri.tryParse(url.trim());
    var host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return null;
    if (host.startsWith('www.')) host = host.substring(4);
    // Lien Google Images : le « site » est la page d'origine (imgrefurl),
    // pas google.com.
    if (host.startsWith('google.') && uri!.path.contains('/imgres')) {
      final ref = uri.queryParameters['imgrefurl'];
      final refHost = (ref == null ? null : Uri.tryParse(ref)?.host.toLowerCase());
      if (refHost == null || refHost.isEmpty) return null;
      host = refHost.startsWith('www.') ? refHost.substring(4) : refHost;
    }
    // Moteurs de recherche et reseaux : un meme domaine melange tous les
    // sujets, il ne dit rien sur le contenu (jamais appris, jamais applique).
    const hubs = [
      'google.', 'bing.com', 'duckduckgo.com', 'ecosia.org', 'qwant.com',
      'pinterest.', 'facebook.com', 'instagram.com', 'reddit.com',
      'youtube.com', 'youtu.be', 'tiktok.com', 'x.com', 'twitter.com',
    ];
    if (hubs.any((h) => host.startsWith(h) || host.contains('.$h') ||
        host.endsWith(h))) {
      return null;
    }
    return 'site:$host';
  }

  /// Tuile personnelle apprise pour le site de [url] : le meilleur score
  /// doit atteindre 3 ET devancer strictement les autres.
  ClipCategory? _learnedSiteCategory(ClientProfile profile, String url) {
    final key = _siteKey(url);
    if (key == null) return null;
    // Enseigne commerciale (Amazon, Aldi, ManoMano...) : un meme site
    // vend de tout (cadeaux, courses). Jamais deduit d'un rangement.
    if (_retailBrandOf(_linkHost(url)) != null) return null;
    final scores = profile.channelVocabulary[key];
    if (scores == null || scores.isEmpty) return null;
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.first.value < 3) return null;
    if (sorted.length > 1 && sorted[1].value >= sorted.first.value) return null;
    return findBestCategoryMatch(sorted.first.key);
  }

  /// Un lien de site web range a la main dans une tuile personnelle :
  /// « ce site -> cette tuile ». Un seul geste suffit (poids 3), et un
  /// nouveau geste vers une autre tuile prend la place du precedent.
  /// Les categories de base ne sont pas concernees (un site comme Amazon
  /// vend de tout).
  Future<void> _learnSiteFromUserChoice(Clip clip, String newCategoryId) async {
    if (SocialPlatform.detect(clip.url).id != 'other') return;
    final key = _siteKey(clip.url);
    if (key == null) return;
    // Enseigne commerciale : voir _learnedSiteCategory.
    if (_retailBrandOf(_linkHost(clip.url)) != null) return;
    ClipCategory? chosen;
    for (final c in _categories) {
      if (c.id == newCategoryId) {
        chosen = c;
        break;
      }
    }
    if (chosen == null ||
        chosen.id.startsWith('cat_') ||
        chosen.id.startsWith('ai_')) {
      return;
    }
    final service = ProfileService();
    final profile = await service.loadProfile();
    final scores = profile.channelVocabulary[key] ?? const <String, int>{};
    var maxOther = 0;
    scores.forEach((name, v) {
      if (name != chosen!.name && v > maxOther) maxOther = v;
    });
    final own = scores[chosen.name] ?? 0;
    final increment = (maxOther - own + 1) > 3 ? (maxOther - own + 1) : 3;
    final updated =
        profile.withLearnedChannel(key, chosen.name, increment: increment);
    await service.saveProfile(updated);
    debugPrint('[apprentissage] site $key -> ${chosen.name}');
  }

  /// Enseigne « ce créateur → cette catégorie » à partir d'un rangement
  /// manuel, quand la machine s'était abstenue.
  ///
  /// Poids 3, soit exactement le seuil de `learnedCategoryForChannel` :
  /// **un seul geste de l'utilisateur suffit**, là où il faut trois
  /// prédictions automatiques concordantes. C'est délibéré — un choix
  /// humain vaut mieux que trois devinettes de la machine.
  ///
  /// Effet concret : la prochaine vidéo du même créateur est rangée par
  /// la couche 2, localement, sans appel à Claude. C'est ce qui manquait
  /// pour les vidéos sans légende, où le créateur est le seul signal.
  ///
  /// Pas d'apprentissage mot par mot : `personalVocabulary` a été
  /// désactivé le 2026-08-09 parce qu'il retenait des mots génériques.
  /// Les noms de plateformes (« Twitch », « Pinterest »…) sont déjà
  /// écartés par `withLearnedChannel` lui-même.
  Future<void> _learnChannelFromUserChoice(
    Clip clip,
    String newCategoryId,
  ) async {
    final channel = clip.channel?.trim() ?? '';
    if (channel.isEmpty) {
      debugPrint('[apprentissage] "${clip.title}" : aucun créateur connu, '
          'rien à retenir');
      return;
    }
    ClipCategory? chosen;
    for (final c in _categories) {
      if (c.id == newCategoryId) {
        chosen = c;
        break;
      }
    }
    if (chosen == null) return;

    final service = ProfileService();
    final profile = await service.loadProfile();
    final updated =
        profile.withLearnedChannel(channel, chosen.name, increment: 3);
    if (identical(updated, profile)) {
      debugPrint('[apprentissage] "$channel" écarté (nom de plateforme)');
      return;
    }
    await service.saveProfile(updated);
    debugPrint('[apprentissage] créateur « $channel » → ${chosen.name} '
        '(rangement manuel, poids 3)');
  }

  /// Fusion des doublons deja enregistres (avant le renforcement de la
  /// deduplication : meme hotel Booking avec d'autres parametres, meme
  /// article via deux liens Google Images...). Par adresse normalisee, on
  /// garde le clip le plus range (categorie, puis tags), a egalite le plus
  /// ancien ; les autres sont supprimes avec leur vignette. Ne touche
  /// jamais au compteur a vie.
  Future<void> _mergeDuplicateClips() async {
    int score(Clip c) =>
        (c.categoryId != null ? 2 : 0) + (c.tags.isNotEmpty ? 1 : 0);
    final keepers = <String, Clip>{};
    final toRemove = <Clip>[];
    for (final c in _clips) {
      final key = _normalizeUrl(c.url);
      final kept = keepers[key];
      if (kept == null) {
        keepers[key] = c;
        continue;
      }
      final cBetter = score(c) > score(kept) ||
          (score(c) == score(kept) && c.addedAt.isBefore(kept.addedAt));
      if (cBetter) {
        keepers[key] = c;
        toRemove.add(kept);
      } else {
        toRemove.add(c);
      }
    }
    if (toRemove.isEmpty) return;
    final ids = toRemove.map((c) => c.id).toSet();
    _clips.removeWhere((c) => ids.contains(c.id));
    for (final c in toRemove) {
      debugPrint('[dedup] doublon fusionne au chargement : "${c.title}" (${c.id})');
      await DatabaseHelper.instance.deleteClip(c.id);
      unawaited(ThumbnailStore.instance.delete(c.id));
    }
  }

  Future<void> removeClip(String id) async {
    // Retrait de la liste en memoire AVANT d'attendre la base : une carte
    // supprimee par glissement (Dismissible) doit disparaitre de l'arbre
    // immediatement, sinon un redessin pendant l'attente leve « A dismissed
    // Dismissible widget is still part of the tree ».
    _clips.removeWhere((c) => c.id == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteClip(id);
    unawaited(ThumbnailStore.instance.delete(id));
  }

  /// Insert idempotent par nom (case-insensitive). Renvoie la cat\u00e9gorie
  /// utilis\u00e9e (existante ou nouvellement cr\u00e9\u00e9e).
  Future<ClipCategory> addCategory(ClipCategory category) async {
    // Idempotent : une categorie equivalente existante est renvoyee au lieu
    // d'en creer une seconde. Equivalente = meme nom a l'accent, la casse
    // et au pluriel pres, ou meme categorie standard (« Food » et
    // « Recette », « Workout » et « Fitness »).
    final target = AppL10n.normalizeCategoryLabel(category.name);
    final targetCanonical = AppL10n.canonicalCategoryId(category.name);
    for (final c in _categories) {
      if (AppL10n.normalizeCategoryLabel(c.name) == target) return c;
      if (targetCanonical != null &&
          (c.id == targetCanonical ||
              AppL10n.canonicalCategoryId(c.name) == targetCanonical)) {
        return c;
      }
    }
    await DatabaseHelper.instance.insertCategory(category);
    _categories.add(category);
    notifyListeners();
    return category;
  }

  Future<void> updateCategory(ClipCategory category) async {
    await DatabaseHelper.instance.insertCategory(category);
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx != -1) _categories[idx] = category;
    notifyListeners();
  }
  /// Réordonne les catégories après un drag & drop sur l'accueil.
  ///
  /// Travaille exclusivement par identifiants (jamais par index de
  /// position) : [draggedId] prend exactement la place de [targetId] dans
  /// la liste des catégories visibles (celles ayant au moins un clip). La
  /// position finale est recalculée en une seule fois, à partir de la
  /// liste actuellement persistée — jamais à partir d'un état de
  /// prévisualisation local — ce qui élimine les décalages d'index
  /// observés précédemment (déplacement qui « ratait » sa cible selon la
  /// direction du glisser).
  /// Déplace la catégorie [draggedId] pour qu'elle occupe l'index
  /// [targetIndex] (0-based, parmi les catégories visibles) une fois
  /// retirée de sa position actuelle. [targetIndex] est calculé
  /// géométriquement côté UI (ligne/colonne sous le doigt), et non plus
  /// déduit de l'identité d'une tuile survolée — élimine toute ambiguïté
  /// quand l'ordre affiché change en cours de geste.
  Future<void> reorderCategoryToIndex(String draggedId, int targetIndex) async {
    final visible = _categories.where((c) => countForCategory(c.id) > 0).toList();
    final oldIndex = visible.indexWhere((c) => c.id == draggedId);
    if (oldIndex == -1) return;
    // Échange de deux tuiles : les autres ne bougent pas.
    final swapWith = targetIndex.clamp(0, visible.length - 1);
    final moved = visible[oldIndex];
    visible[oldIndex] = visible[swapWith];
    visible[swapWith] = moved;

    // 1) Mise à jour immédiate en mémoire + notify pour un rendu instantané,
    //    avant toute écriture en base (évite le "rebond" visuel).
    final updatedList = <ClipCategory>[];
    for (var i = 0; i < visible.length; i++) {
      final updated = visible[i].copyWith(position: i);
      updatedList.add(updated);
    }
    _categories = [...updatedList, ..._categories.where((c) => countForCategory(c.id) <= 0)];
    notifyListeners();

    // 2) Persistance en base, en arrière-plan.
    for (final updated in updatedList) {
      await DatabaseHelper.instance.insertCategory(updated);
    }
  }

  Future<void> removeCategory(String id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    _clips = _clips
        .map((c) => c.categoryId == id ? c.copyWith(categoryId: null) : c)
        .toList();
    final subIds = _subcategories
        .where((s) => s.categoryId == id)
        .map((s) => s.id)
        .toList();
    _subcategories.removeWhere((s) => s.categoryId == id);
    _clipSubcategoryMap.removeWhere((_, v) => subIds.contains(v));
    final subSubIds = _subsubcategories
        .where((ss) => subIds.contains(ss.subCategoryId))
        .map((ss) => ss.id)
        .toList();
    _subsubcategories.removeWhere((ss) => subIds.contains(ss.subCategoryId));
    _clipSubSubcategoryMap.removeWhere((_, v) => subSubIds.contains(v));
    notifyListeners();
  }

  ClipCategory? categoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Clip> get allClips => List.unmodifiable(_clips);

  /// Total number of clips saved (used for the free-tier limit).
  int get totalClipsCount => _clips.length;

  // ─────────────────────────────────────────────
  // SUBCATEGORIES
  // ─────────────────────────────────────────────

  List<SubCategory> getSubCategoriesFor(String? categoryId) {
    if (categoryId == null) return [];
    return _subcategories.where((s) => s.categoryId == categoryId).toList();
  }

  String? subcategoryIdForClip(String clipId) => _clipSubcategoryMap[clipId];

  List<SubSubCategory> getSubSubCategoriesFor(String? subCategoryId) {
    if (subCategoryId == null) return [];
    return _subsubcategories
        .where((ss) => ss.subCategoryId == subCategoryId)
        .toList();
  }

  String? subsubcategoryIdForClip(String clipId) =>
      _clipSubSubcategoryMap[clipId];

  Future<void> addSubSubCategory(SubSubCategory subSub) async {
    await DatabaseHelper.instance.insertSubSubCategory(subSub.toMap());
    _subsubcategories.add(subSub);
    notifyListeners();
  }

  Future<void> updateSubSubCategory(SubSubCategory subSub) async {
    await DatabaseHelper.instance.insertSubSubCategory(subSub.toMap());
    final idx = _subsubcategories.indexWhere((ss) => ss.id == subSub.id);
    if (idx != -1) _subsubcategories[idx] = subSub;
    notifyListeners();
  }

  Future<void> deleteSubSubCategory(String id) async {
    await DatabaseHelper.instance.deleteSubSubCategory(id);
    _subsubcategories.removeWhere((ss) => ss.id == id);
    _clipSubSubcategoryMap.removeWhere((_, v) => v == id);
    notifyListeners();
  }

  Future<void> setClipSubSubcategory(String clipId, String? subSubcategoryId) async {
    await DatabaseHelper.instance.setClipSubSubcategory(clipId, subSubcategoryId);
    if (subSubcategoryId == null) {
      _clipSubSubcategoryMap.remove(clipId);
    } else {
      _clipSubSubcategoryMap[clipId] = subSubcategoryId;
    }
    notifyListeners();
  }

  Future<void> addSubCategory(SubCategory sub) async {
    await DatabaseHelper.instance.insertSubCategory(sub.toMap());
    _subcategories.add(sub);
    notifyListeners();
  }

  Future<void> updateSubCategory(SubCategory sub) async {
    await DatabaseHelper.instance.insertSubCategory(sub.toMap());
    final idx = _subcategories.indexWhere((s) => s.id == sub.id);
    if (idx != -1) _subcategories[idx] = sub;
    notifyListeners();
  }

  Future<void> deleteSubCategory(String id) async {
    await DatabaseHelper.instance.deleteSubCategory(id);
    _subcategories.removeWhere((s) => s.id == id);
    _clipSubcategoryMap.removeWhere((_, v) => v == id);
    final subSubIds = _subsubcategories
        .where((ss) => ss.subCategoryId == id)
        .map((ss) => ss.id)
        .toList();
    _subsubcategories.removeWhere((ss) => ss.subCategoryId == id);
    _clipSubSubcategoryMap.removeWhere((_, v) => subSubIds.contains(v));
    notifyListeners();
  }

  Future<void> setClipSubcategory(String clipId, String? subcategoryId) async {
    await DatabaseHelper.instance.setClipSubcategory(clipId, subcategoryId);
    if (subcategoryId == null) {
      _clipSubcategoryMap.remove(clipId);
    } else {
      _clipSubcategoryMap[clipId] = subcategoryId;
    }
    notifyListeners();
  }

  int countForCategory(String? categoryId) =>
      _clips.where((c) => c.categoryId == categoryId).length;

  int get totalCount => _clips.length;

  bool get hasPendingClassification => _clips.any(isClassificationPending);

  /// Point d'entrée public pour normaliser une URL de déduplication —
  /// utilisé aussi par app.dart pour éviter de dupliquer cette logique
  /// (une duplication passée avait fini par diverger silencieusement).
  static String normalizeUrlForDedup(String url) => _normalizeUrl(url);

  /// Normalise une URL pour la déduplication : canonise d'abord les
  /// plateformes vidéo connues (en extrayant l'identifiant réel de la
  /// vidéo depuis le chemin/la query), et ne retombe sur un simple
  /// nettoyage générique des paramètres de tracking que si la plateforme
  /// n'est pas reconnue. Cette approche résiste aux changements de nom
  /// de paramètre de tracking (ex. Instagram igshid -> igsh) puisqu'elle
  /// ne dépend pas d'une liste figée pour les plateformes couvertes.
  static String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      // Google Images (google.*/imgres) : la page reelle est dans
      // imgrefurl ; les autres parametres (kgs, vet...) changent a
      // chaque partage du meme resultat.
      if (uri.path == '/imgres' &&
          RegExp(r'(^|\.)google\.[a-z.]+$')
              .hasMatch(uri.host.toLowerCase())) {
        final page = uri.queryParameters['imgrefurl'] ?? '';
        if (page.startsWith('http')) return _normalizeUrl(page);
      }
      final lowerHost = uri.host.toLowerCase();
      // Recherche Google : seule la requete compte (ved, sxsrf, client,
      // #sv... changent a chaque recherche).
      if (uri.path == '/search' &&
          RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(lowerHost)) {
        final q = (uri.queryParameters['q'] ?? '').trim().toLowerCase();
        if (q.isNotEmpty) return 'google-search:$q';
      }
      // Sites de reservation : l'etablissement est dans le chemin ; les
      // parametres (dates, voyageurs, nad_*, srpvid, label...) changent a
      // chaque recherche. Booking : la langue (.fr.html, .en-gb.html)
      // est retiree.
      if (RegExp(r'(^|\.)(booking\.com|hotels\.com|airbnb\.[a-z.]+|'
              r'expedia\.[a-z.]+|trivago\.[a-z.]+|tripadvisor\.[a-z.]+)$')
          .hasMatch(lowerHost)) {
        var path = uri.pathSegments.where((s) => s.isNotEmpty).join('/');
        if (path.isEmpty) {
          final hid = uri.queryParameters['app_hotel_id'] ??
              uri.queryParameters['hotel_id'] ??
              '';
          if (RegExp(r'^\d+$').hasMatch(hid)) {
            return 'travel:${lowerHost.replaceFirst(RegExp(r'^www\.'), '')}/hotel_id=$hid';
          }
        }
        path = path.replaceFirst(RegExp(r'\.[a-z]{2}(-[a-z]{2})?\.html$'), '.html');
        return 'travel:${lowerHost.replaceFirst(RegExp(r'^www\.'), '')}/$path';
      }
      final canonical = _canonicalVideoUrl(uri);
      if (canonical != null) return canonical;

      final cleanParams = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((key, _) =>
            key.startsWith('utm_') ||
            {
              'si',
              'fbclid',
              'gclid',
              'igshid',
              'igsh',
              'feature',
              'pp',
              'ref',
              'ref_src',
              '_r',
              '_t',
              'u_code',
              // Publicite et suivi (Google Ads, Bing, Mailchimp, Shopping)
              'gbraid',
              'wbraid',
              'gad_source',
              'gad_campaignid',
              'msclkid',
              'srsltid',
              'mc_cid',
              'mc_eid',
              'yclid',
              'dclid',
              'ttclid',
              'twclid',
              'li_fat_id',
              '_ga',
              '_gl',
              's_kwcid',
              'ef_id',
            }.contains(key));

      final normalizedHost =
          uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      final normalizedPath =
          uri.pathSegments.where((segment) => segment.isNotEmpty).join('/');
      final sortedEntries = cleanParams.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final sortedParams = <String, String>{
        for (final entry in sortedEntries) entry.key: entry.value,
      };

      // Seuls le schema et l'hote sont insensibles a la casse. Le
      // chemin et la query ne le sont pas : abaisser toute l'URL faisait
      // passer deux liens courts differents (codes base62) pour un
      // doublon, et le second partage etait refuse a tort.
      return Uri(
        scheme: uri.scheme.toLowerCase(),
        host: normalizedHost,
        path: normalizedPath.isEmpty ? '' : '/$normalizedPath',
        queryParameters: sortedParams.isEmpty ? null : sortedParams,
      ).toString();
    } catch (_) {
      return url.trim();
    }
  }

  /// Reconnaît les plateformes vidéo connues et retourne un identifiant
  /// canonique stable (ex. "youtube:dQw4w9WgXcQ") indépendant de tout
  /// paramètre de tracking ajouté par le partage.
  static String? _canonicalVideoUrl(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

    if (host == 'youtube.com' || host == 'm.youtube.com' || host == 'youtu.be') {
      final videoId = _youtubeVideoId(uri);
      if (videoId != null && videoId.isNotEmpty) {
        return 'youtube:$videoId';
      }
    }

    if (host == 'tiktok.com' || host == 'vm.tiktok.com' || host == 'm.tiktok.com') {
      final videoId = _tiktokVideoId(segments);
      if (videoId != null && videoId.isNotEmpty) {
        return 'tiktok:$videoId';
      }
    }

    if (host == 'instagram.com' || host == 'm.instagram.com') {
      final mediaCode = _instagramMediaCode(segments);
      if (mediaCode != null && mediaCode.isNotEmpty) {
        return 'instagram:$mediaCode';
      }
    }

    if (host.endsWith('pinterest.com')) {
      final pinId = _pinterestPinId(segments);
      if (pinId != null && pinId.isNotEmpty) {
        return 'pinterest:$pinId';
      }
    }

    // Reddit : l'identifiant du post suit « comments ». Le share_id,
    // different a chaque partage, faisait rater le doublon.
    if (host == 'reddit.com' || host.endsWith('.reddit.com')) {
      final index = segments.indexOf('comments');
      if (index != -1 && index + 1 < segments.length) {
        return 'reddit:${segments[index + 1].toLowerCase()}';
      }
    }
    if (host == 'redd.it' && segments.isNotEmpty) {
      return 'reddit:${segments.first.toLowerCase()}';
    }

    // Facebook : reel/<id>, watch?v=<id>, <page>/videos/<id>.
    if (host == 'facebook.com' ||
        host == 'm.facebook.com' ||
        host == 'web.facebook.com') {
      final fbId = _facebookVideoId(uri, segments);
      if (fbId != null && fbId.isNotEmpty) return 'facebook:$fbId';
    }

    // Twitch : clips.twitch.tv/<slug> == twitch.tv/<chaine>/clip/<slug>.
    if (host == 'clips.twitch.tv' && segments.isNotEmpty) {
      return 'twitch-clip:${segments.first}';
    }
    if (host == 'twitch.tv' || host == 'm.twitch.tv') {
      final clipIndex = segments.indexOf('clip');
      if (clipIndex != -1 && clipIndex + 1 < segments.length) {
        return 'twitch-clip:${segments[clipIndex + 1]}';
      }
      final videoIndex = segments.indexOf('videos');
      if (videoIndex != -1 && videoIndex + 1 < segments.length) {
        return 'twitch-video:${segments[videoIndex + 1]}';
      }
    }

    // X / Twitter : meme publication sur les deux domaines.
    if (host == 'x.com' ||
        host == 'twitter.com' ||
        host == 'mobile.twitter.com' ||
        host == 'mobile.x.com') {
      final index = segments.indexOf('status');
      if (index != -1 && index + 1 < segments.length) {
        return 'x:${segments[index + 1]}';
      }
    }

    return null;
  }

  static String? _youtubeVideoId(Uri uri) {
    if (uri.host.toLowerCase().contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    final segments = uri.pathSegments;
    for (final marker in const ['shorts', 'live']) {
      final index = segments.indexOf(marker);
      if (index != -1 && index + 1 < segments.length) {
        return segments[index + 1];
      }
    }
    if (segments.contains('embed')) {
      final index = segments.indexOf('embed');
      if (index + 1 < segments.length) return segments[index + 1];
    }
    return uri.queryParameters['v'];
  }

  static String? _tiktokVideoId(List<String> segments) {
    final index = segments.indexOf('video');
    if (index != -1 && index + 1 < segments.length) {
      return segments[index + 1];
    }
    return null;
  }

  static String? _instagramMediaCode(List<String> segments) {
    // `share` exclu : /share/reel/<code> porte un code aleatoire propre
    // au partage, resolu en amont par redirection.
    if (segments.isNotEmpty && segments.first == 'share') return null;
    for (final marker in const ['reel', 'reels', 'p', 'tv']) {
      final index = segments.indexOf(marker);
      if (index != -1 && index + 1 < segments.length) {
        return segments[index + 1];
      }
    }
    return null;
  }

  static String? _facebookVideoId(Uri uri, List<String> segments) {
    // Liens de partage (/share/r/<code>) : code aleatoire, resolu en amont.
    if (segments.isNotEmpty && segments.first == 'share') return null;
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    for (final marker in const ['reel', 'videos']) {
      final index = segments.indexOf(marker);
      if (index != -1 && index + 1 < segments.length) {
        return segments[index + 1];
      }
    }
    return null;
  }

  static String? _pinterestPinId(List<String> segments) {
    final index = segments.indexOf('pin');
    if (index != -1 && index + 1 < segments.length) {
      return segments[index + 1];
    }
    return null;
  }

  bool isDuplicate(String url) {
    final normalized = _normalizeUrl(url);
    return _clips.any((c) => _normalizeUrl(c.url) == normalized);
  }

  /// Retourne le clip existant dont l'URL normalisée correspond, ou null.
  Clip? findDuplicate(String url) {
    final normalized = _normalizeUrl(url);
    try {
      return _clips.firstWhere((c) => _normalizeUrl(c.url) == normalized);
    } catch (_) {
      return null;
    }
  }

  List<Clip> clipsForCategory(String? categoryId) =>
      _clips.where((c) => c.categoryId == categoryId).toList();

  SortOrder sortOrderFor(String? categoryId) =>
      _categorySortOrders[categoryId ?? '__all__'] ?? SortOrder.chronological;

  void setSortOrderFor(String? categoryId, SortOrder order) {
    _categorySortOrders[categoryId ?? '__all__'] = order;
    notifyListeners();
  }

  bool gridViewFor(String? categoryId) =>
      _categoryGridViews[categoryId ?? '__all__'] ?? false;

  void setGridViewFor(String? categoryId, bool value) {
    _categoryGridViews[categoryId ?? '__all__'] = value;
    notifyListeners();
  }

  /// Réordonne les clips d'une catégorie (drag & drop manuel), à partir de
  /// la liste [currentOrder] telle qu'affichée à l'écran (déjà filtrée par
  /// catégorie/sous-catégorie et triée). On repart de cette liste plutôt que
  /// de la recalculer depuis toute la catégorie : [oldIndex]/[newIndex]
  /// correspondent ainsi toujours à la vidéo réellement glissée, y compris
  /// quand une sous-catégorie est sélectionnée (sinon un autre clip que
  /// celui déplacé par l'utilisateur se retrouvait réordonné, d'où l'ordre
  /// qui semblait « revenir en arrière »).
  Future<void> reorderClips(
      List<Clip> currentOrder, int oldIndex, int newIndex) async {
    final sorted = List<Clip>.from(currentOrder);

    // newIndex est déjà ajusté par onReorderItem
    final moved = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, moved);

    // Assigner des positions séquentielles et persister
    final updates = <Map<String, dynamic>>[];
    for (int i = 0; i < sorted.length; i++) {
      sorted[i] = sorted[i].copyWith(position: i);
      updates.add({'id': sorted[i].id, 'position': i});
    }
    await DatabaseHelper.instance.updateClipPositions(updates);

    // Recharger depuis la DB — garantit que _clips reflète exactement
    // les positions persistées, sans risque de mise à jour partielle en mémoire.
    _clips = await DatabaseHelper.instance.getAllClips();
    notifyListeners();
  }
}

/// Lien Google Images (google.*/imgres) : l'adresse contient l'image touchee
/// (`imgurl`) et la page d'origine (`imgrefurl`). Renvoie `image` (adresse
/// https directe, lisible par Claude) et `words` (mots tires des adresses :
/// ex. « ui design gradient »), ou une table vide pour tout autre lien.
Map<String, String> _googleImagesHints(String url) {
  final lower = url.toLowerCase();
  if (!lower.contains('google.') || !lower.contains('/imgres')) {
    return const {};
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return const {};
  final imgUrl = uri.queryParameters['imgurl'] ?? '';
  final refUrl = uri.queryParameters['imgrefurl'] ?? '';

  String words(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null) return '';
    final segs = u.pathSegments.where((x) => x.isNotEmpty).toList();
    final tail = segs.length > 3 ? segs.sublist(segs.length - 3) : segs;
    final cleaned = tail
        .join(' ')
        .replaceAll(
          RegExp(r'\.(jpe?g|png|webp|gif|avif|html?)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[-_+.%]'), ' ');
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => RegExp(r'^[A-Za-z\u00C0-\u017F]{2,}$').hasMatch(t))
        .take(25);
    return tokens.join(' ');
  }

  final out = <String, String>{};
  if (imgUrl.startsWith('https://')) out['image'] = imgUrl;
  final refWords = words(refUrl);
  final imgWords = words(imgUrl);
  if (refWords.isNotEmpty) out['ref_words'] = refWords;
  final parts = <String>[
    if (refWords.isNotEmpty) "Mots de l'adresse de la page : $refWords.",
    if (imgWords.isNotEmpty) "Mots du nom de l'image : $imgWords.",
  ];
  if (parts.isNotEmpty) out['words'] = parts.join(' ');
  return out;
}

/// Nom de domaine du site d'un lien. Pour un lien Google Images, c'est celui
/// de la page d'origine (`imgrefurl`), pas google.com.
/// Enseignes commerciales (FR et EN) : mot du nom de domaine, sans accents ni
/// tirets, vers nom de la tuile. Complete la liste ici pour en ajouter.
const Map<String, String> _retailBrands = {
  // France
  'auchan': 'Auchan', 'lidl': 'Lidl', 'aldi': 'Aldi', 'carrefour': 'Carrefour',
  'casino': 'Casino', 'casinodrive': 'Casino', 'geantcasino': 'Casino',
  'casinomax': 'Casino', 'grandfrais': 'Grand Frais', 'biocoop': 'Biocoop',
  'netto': 'Netto', 'chronodrive': 'Chronodrive', 'superu': 'Super U',
  'magasinsu': 'Super U', 'bricomarche': 'Bricomarché',
  'mrbricolage': 'Mr Bricolage', 'cultura': 'Cultura', 'hema': 'HEMA',
  'primark': 'Primark', 'kingjouet': 'King Jouet', 'lafoirfouille': 'La Foir\'Fouille',
  'leclerc': 'Leclerc', 'intermarche': 'Intermarché', 'monoprix': 'Monoprix',
  'franprix': 'Franprix', 'picard': 'Picard', 'cora': 'Cora',
  'cdiscount': 'Cdiscount', 'fnac': 'Fnac', 'darty': 'Darty',
  'boulanger': 'Boulanger', 'leroymerlin': 'Leroy Merlin',
  'castorama': 'Castorama', 'bricodepot': 'Brico Dépôt', 'ikea': 'IKEA',
  'decathlon': 'Decathlon', 'kiabi': 'Kiabi', 'zara': 'Zara',
  'maisonsdumonde': 'Maisons du Monde', 'gifi': 'Gifi', 'sephora': 'Sephora',
  'nocibe': 'Nocibé', 'yvesrocher': 'Yves Rocher', 'marionnaud': 'Marionnaud',
  'douglas': 'Douglas', 'rakuten': 'Rakuten', 'leboncoin': 'Leboncoin',
  'manomano': 'ManoMano', 'jardiland': 'Jardiland', 'truffaut': 'Truffaut',
  'botanic': 'Botanic', 'conforama': 'Conforama', 'electrodepot': 'Electro Dépôt',
  'laredoute': 'La Redoute', 'veepee': 'Veepee', 'showroomprive': 'Showroomprivé',
  'shein': 'Shein', 'temu': 'Temu', 'aliexpress': 'AliExpress', 'ebay': 'eBay',
  'etsy': 'Etsy', 'amazon': 'Amazon', 'amzn': 'Amazon', 'vinted': 'Vinted',
  // Pays anglophones
  'walmart': 'Walmart', 'target': 'Target', 'costco': 'Costco',
  'kroger': 'Kroger', 'tesco': 'Tesco', 'sainsburys': "Sainsbury's",
  'asda': 'Asda', 'morrisons': 'Morrisons', 'waitrose': 'Waitrose',
  'argos': 'Argos', 'boots': 'Boots', 'bestbuy': 'Best Buy',
  'homedepot': 'Home Depot', 'lowes': "Lowe's", 'wayfair': 'Wayfair',
  'macys': "Macy's", 'nordstrom': 'Nordstrom', 'kohls': "Kohl's",
  'ulta': 'Ulta', 'cvs': 'CVS', 'walgreens': 'Walgreens',
  'samsclub': "Sam's Club", 'wholefoodsmarket': 'Whole Foods',
  'traderjoes': "Trader Joe's", 'safeway': 'Safeway', 'publix': 'Publix',
  'currys': 'Currys', 'johnlewis': 'John Lewis', 'asos': 'ASOS',
  'marksandspencer': 'Marks & Spencer', 'overstock': 'Overstock',
  'newegg': 'Newegg', 'chewy': 'Chewy', 'petsmart': 'PetSmart',
};

/// Nom d'enseigne pour un nom d'hote (www.auchan.fr, smile.amazon.co.uk,
/// shop.walmart.com...), ou null. Un mot du domaine doit valoir
/// exactement le nom d'une enseigne.
String? _retailBrandOf(String host) {
  if (host.isEmpty) return null;
  for (final label in host.toLowerCase().split('.')) {
    final key = label.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final brand = _retailBrands[key];
    if (brand != null) return brand;
  }
  return null;
}

/// Enseigne connue nommee dans le titre d'un produit (mot entier), ou null.
/// Mots trop courants en francais ou en anglais ecartes.
const Set<String> _ambiguousBrandWords = {
  'target', 'boots', 'argos', 'douglas', 'cora', 'cvs', 'asda', 'action',
  'zara', 'etsy', 'ebay', 'ulta',
};

String? _brandInTitle(String title) {
  final words = normalizeForSearch(title)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length >= 4);
  for (final w in words) {
    if (_ambiguousBrandWords.contains(w)) continue;
    final brand = _retailBrands[w];
    if (brand != null) return brand;
  }
  return null;
}

/// Nom de tuile pour une boutique detectee par la regle (hors liste) :
/// d'abord og:site_name (1er segment avant « : », « | » ou « - », s'il est
/// court), sinon le nom de domaine (mescourses.fr -> Mescourses).
String _shopNameFor(Clip clip, String host) {
  final site = clip.channel?.trim() ?? '';
  if (site.isNotEmpty) {
    final first = site.split(RegExp(r'\s*[:|]\s*|\s+[-–—]\s+')).first.trim();
    if (first.length >= 2 && first.length <= 25) return first;
  }
  final labels = host.toLowerCase().split('.')
    ..removeWhere((l) => l.isEmpty || l == 'www');
  if (labels.isEmpty) return host;
  var i = labels.length >= 2 ? labels.length - 2 : 0;
  if (labels.length >= 3 && labels[labels.length - 2].length <= 3) {
    i = labels.length - 3;
  }
  final name = labels[i];
  return name[0].toUpperCase() + name.substring(1);
}

/// Couleur stable d'une tuile d'enseigne (meme nom, meme couleur).
Color _brandColor(String name) {
  const palette = [
    Color(0xFF0EA5E9), Color(0xFFF97316), Color(0xFF10B981),
    Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFFEAB308),
    Color(0xFF14B8A6), Color(0xFFEF4444),
  ];
  var h = 0;
  for (final u in name.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

String _linkHost(String url) {
  final ref = Uri.tryParse(url)?.queryParameters['imgrefurl'];
  return Uri.tryParse(ref != null && ref.isNotEmpty ? ref : url)?.host ?? '';
}

/// Un lien du lot en cours d'analyse (voir ClipsState._reviewBatch).
class _BatchItem {
  final Clip clip;
  final String line;
  final List<String> tags;

  /// Categorie du clip au debut de l'analyse : permet de detecter un
  /// rangement manuel survenu pendant l'appel.
  final String? categoryAtStart;

  /// Mots (racines) du lien, pour le rapprocher des autres du lot.
  final Set<String> tokens;

  /// Lien deja range avec une confiance >= 90 : il ne bouge pas, mais sa
  /// categorie sert de reference aux autres liens de la meme serie.
  final bool anchor;

  /// Vignette https du lien (jointe a la lecture groupee du lot), ou null.
  final String? image;

  _BatchItem(this.clip, this.line, this.tags, this.categoryAtStart, this.tokens,
      {this.anchor = false, this.image});
}
