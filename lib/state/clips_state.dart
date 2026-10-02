import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/clip.dart';
import '../services/classifier.dart';
import '../models/classification_result.dart';
import '../services/database.dart';
import '../core/l10n.dart';
import 'dart:async';
import '../services/oembed.dart';
import '../services/thumbnail_store.dart';
import '../services/profile_service.dart';

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

  Future<void> addClip(Clip clip) async {
    await DatabaseHelper.instance.insertClip(clip);
    _clips.insert(0, clip);
    notifyListeners();
    if (clip.categoryId == null) _schedulePendingClassificationRefresh(clip);
  }

  /// Durée pendant laquelle un clip sans catégorie est considéré « en
  /// cours de classement » par l'interface.
  static const Duration pendingClassificationWindow = Duration(seconds: 20);

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
      final sw = Stopwatch()..start();
      final profile = await ProfileService().loadProfile();
      final effectiveTitle = clip.title.isEmpty || clip.title == "Twitch" ? "gaming streaming ${clip.url}" : clip.title;
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

      if (catName == null) {
        try {
          await _ClassifyLimiter.acquire();
          final ClassificationResult result;
          try {
            result = await ClaudeClassifier.classify(
              video: VideoData(
                title: effectiveTitle,
                platform: clip.platform,
                thumbnailUrl: clip.thumbnailUrl,
                channel: clip.channel,
                description: clip.description,
              ),
              profile: profile,
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
                  thumbnailUrl: clip.thumbnailUrl,
                  channel: clip.channel,
                  description: clip.description,
                ),
                profile: profile,
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
          'cat_bebe': 'Bébé', 'cat_tricot': 'Couture', 'cat_tricotage': 'Tricot', 'cat_crochet': 'Crochet',
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
    }
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

  Future<void> removeClip(String id) async {
    await DatabaseHelper.instance.deleteClip(id);
    _clips.removeWhere((c) => c.id == id);
    notifyListeners();
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
    final moved = visible.removeAt(oldIndex);
    final insertAt = targetIndex.clamp(0, visible.length);
    visible.insert(insertAt, moved);

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

  bool get hasPendingClassification => _clips.any((c) =>
      c.categoryId == null &&
      DateTime.now().difference(c.addedAt) < pendingClassificationWindow);

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
