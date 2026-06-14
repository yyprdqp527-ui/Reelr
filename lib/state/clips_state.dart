import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/clip.dart';
import '../services/classifier.dart';
import '../services/database.dart';
import '../services/profile_service.dart';

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

  List<Clip> get clips {
    var result = _clips;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.url.toLowerCase().contains(q) ||
              c.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    return result;
  }

  List<String> get searchSuggestions {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    final set = <String>{};
    for (final c in _clips) {
      if (c.title.toLowerCase().contains(q)) set.add(c.title);
      for (final t in c.tags) {
        if (t.toLowerCase().contains(q)) set.add('#$t');
      }
    }
    return set.take(5).toList();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    _clips = await DatabaseHelper.instance.getAllClips();
    _categories = await DatabaseHelper.instance.getAllCategories();
    final subMaps = await DatabaseHelper.instance.getAllSubCategories();
    _subcategories = subMaps.map(SubCategory.fromMap).toList();
    _clipSubcategoryMap = await DatabaseHelper.instance.getClipSubcategoryMapAll();
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
  }

  // Mapping explicite : noms retournés par Claude → cat_id stable
  static const Map<String, String> _claudeCatMap = {
    'food': 'cat_food', 'cuisine': 'cat_food', 'recette': 'cat_food', 'cooking': 'cat_food',
    'fitness': 'cat_fitness', 'sport': 'cat_fitness', 'workout': 'cat_fitness', 'sante': 'cat_fitness',
    'gaming': 'cat_gaming', 'jeu': 'cat_gaming', 'jeux video': 'cat_gaming', 'streaming': 'cat_gaming',
    'beauty': 'cat_beauty', 'beaute': 'cat_beauty', 'makeup': 'cat_beauty', 'skincare': 'cat_beauty',
    'mode': 'cat_mode', 'fashion': 'cat_mode', 'style': 'cat_mode', 'vetements': 'cat_mode',
    'travel': 'cat_travel', 'voyage': 'cat_travel', 'aventure': 'cat_travel',
    'tech': 'cat_tech', 'technologie': 'cat_tech', 'science': 'cat_tech',
    'humour': 'cat_humour', 'humor': 'cat_humour', 'comedie': 'cat_humour', 'funny': 'cat_humour',
    'musique': 'cat_musique', 'music': 'cat_musique', 'concert': 'cat_musique',
    'wellness': 'cat_wellness', 'bien-etre': 'cat_wellness', 'meditation': 'cat_wellness', 'yoga': 'cat_wellness',
    'podcast': 'cat_podcast',
    'famille': 'cat_famille', 'family': 'cat_famille', 'enfants': 'cat_famille', 'bebe': 'cat_famille',
    'finance & business': 'cat_finance', 'finance': 'cat_finance', 'business': 'cat_finance', 'entrepreneuriat': 'cat_finance',
    'actu & societe': 'cat_actu', 'actu': 'cat_actu', 'societe': 'cat_actu', 'actualite': 'cat_actu', 'news': 'cat_actu',
    'diy & crea': 'cat_diy', 'diy': 'cat_diy', 'crea': 'cat_diy', 'creation': 'cat_diy', 'art': 'cat_diy',
    'deco & home': 'cat_deco', 'deco': 'cat_deco', 'maison': 'cat_deco', 'interieur': 'cat_deco',
    'auto & moto': 'cat_auto', 'auto': 'cat_auto', 'moto': 'cat_auto', 'voiture': 'cat_auto',
    'culture': 'cat_culture', 'litterature': 'cat_culture', 'histoire': 'cat_culture',
    'cinema & series': 'cat_cinema', 'cinema': 'cat_cinema', 'series': 'cat_cinema', 'film': 'cat_cinema',
    'growth': 'cat_growth', 'developpement personnel': 'cat_growth', 'motivation': 'cat_growth',
    'pets & nature': 'cat_pets', 'pets': 'cat_pets', 'animaux': 'cat_pets', 'nature': 'cat_pets',
    'true crime': 'cat_truecrime', 'crime': 'cat_truecrime', 'enquete': 'cat_truecrime',
    'astro & spirituel': 'cat_astro', 'astro': 'cat_astro', 'spiritualite': 'cat_astro',
    'vibes': 'cat_vibes', 'lifestyle': 'cat_vibes', 'inspo': 'cat_vibes',
  };

  ClipCategory? findBestCategoryMatch(String name) {
    final normalized = name.trim().toLowerCase()
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
        .replaceAll('à', 'a').replaceAll('â', 'a')
        .replaceAll('ô', 'o').replaceAll('û', 'u').replaceAll('ç', 'c');
    if (normalized.isEmpty) return null;

    // 1. Mapping explicite Claude → cat_id
    final mappedId = _claudeCatMap[normalized];
    if (mappedId != null) {
      final cat = _categories.where((c) => c.id == mappedId).firstOrNull;
      if (cat != null) return cat;
    }

    // 2. Match exact sur le nom de catégorie
    for (final cat in _categories) {
      if (cat.name.trim().toLowerCase() == normalized) return cat;
    }

    // 3. Match partiel strict (le nom de cat est contenu dans ce que Claude retourne)
    for (final cat in _categories) {
      final catNorm = cat.name.trim().toLowerCase()
          .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
          .replaceAll('à', 'a').replaceAll('â', 'a')
          .replaceAll('ô', 'o').replaceAll('û', 'u').replaceAll('ç', 'c');
      if (normalized == catNorm) return cat;
    }

    return null;
  }

  Future<void> classifyClipInBackground(Clip clip) async {
    try {
      debugPrint('[classify] starting for: \${clip.title}');
      final profile = await ProfileService().loadProfile();
      final result = await ClaudeClassifier.classify(
        video: VideoData(
          title: clip.title.isEmpty || clip.title == "Twitch" || clip.title == "Instagram" || clip.title == "Facebook" ? "gaming streaming ${clip.url}" : clip.title,
          platform: clip.platform,
          thumbnailUrl: clip.thumbnailUrl,
        ),
        profile: profile,
      );
      final catName = result.categoriePrincipale;
      debugPrint('[classify] result: $catName | confiance: ${result.confiance}');
      _categories = await DatabaseHelper.instance.getAllCategories();
      var matchedCat = findBestCategoryMatch(catName);
      if (matchedCat == null) {
        final newCat = ClipCategory(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          name: catName,
          color: const Color(0xFF7C3AED),
          icon: Icons.folder_rounded,
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
      _newlyClassifiedCategoryIds.add(matchedCat.id);
      _categories = await DatabaseHelper.instance.getAllCategories();
      _clips = await DatabaseHelper.instance.getAllClips();
      notifyListeners();
    } catch (e) {
      debugPrint('[classify] error: $e');
    }
  }

  Future<void> updateClip(Clip clip) async {
    await DatabaseHelper.instance.insertClip(clip);
    final idx = _clips.indexWhere((c) => c.id == clip.id);
    if (idx != -1) _clips[idx] = clip;
    notifyListeners();
  }

  Future<void> removeClip(String id) async {
    await DatabaseHelper.instance.deleteClip(id);
    _clips.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Insert idempotent par nom (case-insensitive). Renvoie la cat\u00e9gorie
  /// utilis\u00e9e (existante ou nouvellement cr\u00e9\u00e9e).
  Future<ClipCategory> addCategory(ClipCategory category) async {
    final target = category.name.toLowerCase().trim();
    for (final c in _categories) {
      if (c.name.toLowerCase().trim() == target) return c;
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

  /// Normalise une URL pour la déduplication :
  /// retire les paramètres de tracking (si, utm_*, fbclid)
  /// tout en conservant l'identifiant vidéo (v=, etc.).
  static String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final cleanParams = Map<String, String>.from(
          uri.queryParameters)
        ..removeWhere((k, _) =>
          ['si', 'utm_source', 'utm_medium',
           'utm_campaign', 'fbclid', 'igshid',
           'feature', 'pp'].contains(k));
      return uri.replace(
        queryParameters: cleanParams.isEmpty
          ? null : cleanParams,
        fragment: '',
      ).toString().toLowerCase();
    } catch (_) {
      return url.trim().toLowerCase();
    }
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

  /// Réordonne les clips d'une catégorie (drag & drop manuel).
  /// [oldIndex] et [newIndex] sont les indices dans la liste triée par position.
  Future<void> reorderClips(
      String? categoryId, int oldIndex, int newIndex) async {
    // Liste filtrée triée par position (tiebreaker : addedAt DESC)
    final sorted = (categoryId == null
            ? List<Clip>.from(_clips)
            : _clips.where((c) => c.categoryId == categoryId).toList())
        ..sort((a, b) {
          final cmp = a.position.compareTo(b.position);
          return cmp != 0 ? cmp : b.addedAt.compareTo(a.addedAt);
        });

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
