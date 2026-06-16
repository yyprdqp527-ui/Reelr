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
  static const Map<String, Color> _catColors = {
    'cat_food': Color(0xFFFF7043), 'cat_fitness': Color(0xFF42A5F5),
    'cat_gaming': Color(0xFF7E57C2), 'cat_beauty': Color(0xFFEC407A),
    'cat_mode': Color(0xFFAB47BC), 'cat_travel': Color(0xFF26C6DA),
    'cat_humour': Color(0xFFFFE66D), 'cat_musique': Color(0xFFFF7675),
    'cat_wellness': Color(0xFFA8E6CF), 'cat_podcast': Color(0xFFB2BEC3),
    'cat_famille': Color(0xFFFD79A8), 'cat_finance': Color(0xFF00B894),
    'cat_actu': Color(0xFF90A4AE), 'cat_diy': Color(0xFFE17055),
    'cat_deco': Color(0xFFFAB1A0), 'cat_auto': Color(0xFFFFB347),
    'cat_culture': Color(0xFF8E44AD), 'cat_cinema': Color(0xFFEF9A9A),
    'cat_growth': Color(0xFF27AE60), 'cat_pets': Color(0xFF16A085),
    'cat_truecrime': Color(0xFFE57373), 'cat_astro': Color(0xFFCE93D8),
    'cat_business': Color(0xFF26A69A), 'cat_societe': Color(0xFF78909C),
    'cat_nature': Color(0xFF81C784), 'cat_sport': Color(0xFFFF5252),
    'cat_sante': Color(0xFFFF8A65), 'cat_science': Color(0xFF4FC3F7),
    'cat_bebe': Color(0xFFFFCC80), 'cat_tricot': Color(0xFFCE93D8),
    'cat_doc': Color(0xFF90A4AE), 'cat_religion': Color(0xFFB39DDB),
    'cat_immo': Color(0xFFBCAAA4), 'cat_manga': Color(0xFFFF8A80),
    'cat_politique': Color(0xFF80CBC4), 'cat_crypto': Color(0xFFF7DC6F),
    'cat_lang': Color(0xFF80DEEA), 'cat_histoire': Color(0xFFA5D6A7),
    'cat_art': Color(0xFFE040FB), 'cat_photo': Color(0xFF4DD0E1),
    'cat_outdoor': Color(0xFF69F0AE), 'cat_psycho': Color(0xFFFFAB91),
    'cat_luxe': Color(0xFFFFD700), 'cat_entrepreneuriat': Color(0xFF4CAF50),
    'cat_education': Color(0xFF29B6F6), 'cat_cosplay': Color(0xFFBA68C8),
    'cat_dance': Color(0xFFFF4081), 'cat_comedy': Color(0xFFFFEB3B),
    'cat_jardin': Color(0xFF8BC34A), 'cat_sport_extreme': Color(0xFFFF6D00),
    'cat_nutrition': Color(0xFF66BB6A), 'cat_vintage': Color(0xFFD7CCC8),
    'cat_fail': Color(0xFFFF5722),
  };
  static const Map<String, IconData> _catIcons = {
    'cat_food': Icons.restaurant_rounded, 'cat_fitness': Icons.fitness_center_rounded,
    'cat_gaming': Icons.sports_esports_rounded, 'cat_beauty': Icons.brush_rounded,
    'cat_mode': Icons.style_rounded, 'cat_travel': Icons.flight_takeoff_rounded,
    'cat_humour': Icons.sentiment_very_satisfied_rounded, 'cat_musique': Icons.music_note_rounded,
    'cat_wellness': Icons.self_improvement_rounded, 'cat_podcast': Icons.mic_rounded,
    'cat_famille': Icons.family_restroom_rounded, 'cat_finance': Icons.trending_up_rounded,
    'cat_actu': Icons.newspaper_rounded, 'cat_diy': Icons.handyman_rounded,
    'cat_deco': Icons.home_rounded, 'cat_auto': Icons.directions_car_rounded,
    'cat_culture': Icons.theater_comedy_rounded, 'cat_cinema': Icons.movie_rounded,
    'cat_growth': Icons.rocket_launch_rounded, 'cat_pets': Icons.pets_rounded,
    'cat_truecrime': Icons.gavel_rounded, 'cat_astro': Icons.auto_awesome_rounded,
    'cat_business': Icons.business_center_rounded, 'cat_societe': Icons.people_rounded,
    'cat_nature': Icons.park_rounded, 'cat_sport': Icons.sports_soccer_rounded,
    'cat_sante': Icons.favorite_rounded, 'cat_science': Icons.science_rounded,
    'cat_bebe': Icons.child_care_rounded, 'cat_tricot': Icons.content_cut_rounded,
    'cat_doc': Icons.video_library_rounded, 'cat_religion': Icons.church_rounded,
    'cat_immo': Icons.apartment_rounded, 'cat_manga': Icons.auto_stories_rounded,
    'cat_politique': Icons.account_balance_rounded, 'cat_crypto': Icons.currency_bitcoin_rounded,
    'cat_lang': Icons.translate_rounded, 'cat_histoire': Icons.history_edu_rounded,
    'cat_art': Icons.palette_rounded, 'cat_photo': Icons.camera_alt_rounded,
    'cat_outdoor': Icons.terrain_rounded, 'cat_psycho': Icons.psychology_rounded,
    'cat_luxe': Icons.diamond_rounded, 'cat_entrepreneuriat': Icons.rocket_rounded,
    'cat_education': Icons.school_rounded, 'cat_cosplay': Icons.star_rounded,
    'cat_dance': Icons.music_note_rounded, 'cat_comedy': Icons.sentiment_very_satisfied_rounded,
    'cat_jardin': Icons.yard_rounded, 'cat_sport_extreme': Icons.downhill_skiing_rounded,
    'cat_nutrition': Icons.local_dining_rounded, 'cat_vintage': Icons.watch_rounded,
    'cat_fail': Icons.videocam_rounded,
  };

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
    // Migration: resynchronise couleurs et icônes pour les cat_xxx existantes
    _categories = _categories.map((cat) {
      if (!cat.id.startsWith('cat_')) return cat;
      final color = _catColors[cat.id];
      final icon = _catIcons[cat.id];
      if (color == null && icon == null) return cat;
      return ClipCategory(
        id: cat.id,
        name: cat.name,
        color: color ?? cat.color,
        icon: icon ?? cat.icon,
        position: cat.position,
      );
    }).toList();
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

  ClipCategory? findBestCategoryMatch(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    // 1. Match exact par ID (cat_xxx)
    for (final cat in _categories) {
      if (cat.id == name.trim()) return cat;
    }
    // 2. Match exact par nom
    for (final cat in _categories) {
      if (cat.name.trim().toLowerCase() == normalized) return cat;
    }
    // 3. Match partiel par nom
    for (final cat in _categories) {
      final cName = cat.name.trim().toLowerCase();
      if (cName.contains(normalized) && normalized.length / cName.length > 0.6 ||
          normalized.contains(cName)) {
        return cat;
      }
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
        const catColors = <String, Color>{
          'cat_food': Color(0xFFFF6B6B), 'cat_fitness': Color(0xFF4ECDC4),
          'cat_gaming': Color(0xFF74B9FF), 'cat_beauty': Color(0xFFFF85B3),
          'cat_mode': Color(0xFFC77DFF), 'cat_travel': Color(0xFF81ECEC),
          'cat_humour': Color(0xFFFFE66D), 'cat_musique': Color(0xFFFF7675),
          'cat_wellness': Color(0xFFA8E6CF), 'cat_podcast': Color(0xFFB2BEC3),
          'cat_famille': Color(0xFFFD79A8), 'cat_finance': Color(0xFF00B894),
          'cat_actu': Color(0xFF90A4AE), 'cat_diy': Color(0xFFE17055),
          'cat_deco': Color(0xFFFAB1A0), 'cat_auto': Color(0xFFFFB347),
          'cat_culture': Color(0xFF8E44AD), 'cat_cinema': Color(0xFFEF9A9A),
          'cat_growth': Color(0xFF27AE60), 'cat_pets': Color(0xFF16A085),
          'cat_truecrime': Color(0xFFE57373), 'cat_astro': Color(0xFFCE93D8),
          'cat_business': Color(0xFF26A69A), 'cat_societe': Color(0xFF78909C),
          'cat_nature': Color(0xFF81C784), 'cat_sport': Color(0xFFFF5252),
          'cat_sante': Color(0xFFFF8A65), 'cat_science': Color(0xFF4FC3F7),
          'cat_bebe': Color(0xFFFFCC80), 'cat_tricot': Color(0xFFCE93D8),
          'cat_doc': Color(0xFF90A4AE), 'cat_religion': Color(0xFFB39DDB),
          'cat_immo': Color(0xFFBCAAA4), 'cat_manga': Color(0xFFFF8A80),
          'cat_politique': Color(0xFF80CBC4), 'cat_crypto': Color(0xFFF7DC6F),
          'cat_lang': Color(0xFF80DEEA), 'cat_histoire': Color(0xFFA5D6A7),
          'cat_art': Color(0xFFE040FB), 'cat_photo': Color(0xFF4DD0E1),
          'cat_outdoor': Color(0xFF69F0AE), 'cat_psycho': Color(0xFFFFAB91),
          'cat_luxe': Color(0xFFFFD700), 'cat_entrepreneuriat': Color(0xFF4CAF50),
          'cat_education': Color(0xFF29B6F6), 'cat_cosplay': Color(0xFFBA68C8),
          'cat_dance': Color(0xFFFF4081), 'cat_comedy': Color(0xFFFFEB3B),
          'cat_jardin': Color(0xFF8BC34A), 'cat_sport_extreme': Color(0xFFFF6D00),
          'cat_nutrition': Color(0xFF66BB6A), 'cat_vintage': Color(0xFFD7CCC8),
          'cat_fail': Color(0xFFFF5722),
        };
        const catIcons = <String, IconData>{
          'cat_food': Icons.restaurant_rounded, 'cat_fitness': Icons.fitness_center_rounded,
          'cat_gaming': Icons.sports_esports_rounded, 'cat_beauty': Icons.brush_rounded,
          'cat_mode': Icons.style_rounded, 'cat_travel': Icons.flight_takeoff_rounded,
          'cat_humour': Icons.sentiment_very_satisfied_rounded, 'cat_musique': Icons.music_note_rounded,
          'cat_wellness': Icons.self_improvement_rounded, 'cat_podcast': Icons.mic_rounded,
          'cat_famille': Icons.family_restroom_rounded, 'cat_finance': Icons.trending_up_rounded,
          'cat_actu': Icons.newspaper_rounded, 'cat_diy': Icons.handyman_rounded,
          'cat_deco': Icons.home_rounded, 'cat_auto': Icons.directions_car_rounded,
          'cat_culture': Icons.theater_comedy_rounded, 'cat_cinema': Icons.movie_rounded,
          'cat_growth': Icons.rocket_launch_rounded, 'cat_pets': Icons.pets_rounded,
          'cat_truecrime': Icons.gavel_rounded, 'cat_astro': Icons.auto_awesome_rounded,
          'cat_business': Icons.business_center_rounded, 'cat_societe': Icons.people_rounded,
          'cat_nature': Icons.park_rounded, 'cat_sport': Icons.sports_soccer_rounded,
          'cat_sante': Icons.favorite_rounded, 'cat_science': Icons.science_rounded,
          'cat_bebe': Icons.child_care_rounded, 'cat_tricot': Icons.content_cut_rounded,
          'cat_doc': Icons.video_library_rounded, 'cat_religion': Icons.church_rounded,
          'cat_immo': Icons.apartment_rounded, 'cat_manga': Icons.auto_stories_rounded,
          'cat_politique': Icons.account_balance_rounded, 'cat_crypto': Icons.currency_bitcoin_rounded,
          'cat_lang': Icons.translate_rounded, 'cat_histoire': Icons.history_edu_rounded,
          'cat_art': Icons.palette_rounded, 'cat_photo': Icons.camera_alt_rounded,
          'cat_outdoor': Icons.terrain_rounded, 'cat_psycho': Icons.psychology_rounded,
          'cat_luxe': Icons.diamond_rounded, 'cat_entrepreneuriat': Icons.lightbulb_rounded,
          'cat_education': Icons.school_rounded, 'cat_cosplay': Icons.masks_rounded,
          'cat_dance': Icons.music_video_rounded, 'cat_comedy': Icons.mic_external_on_rounded,
          'cat_jardin': Icons.yard_rounded, 'cat_sport_extreme': Icons.paragliding_rounded,
          'cat_nutrition': Icons.no_food_rounded, 'cat_vintage': Icons.watch_rounded,
          'cat_fail': Icons.sentiment_very_dissatisfied_rounded,
        };
        const catNames = <String, String>{
          'cat_food': 'Food', 'cat_fitness': 'Fitness',
          'cat_gaming': 'Gaming', 'cat_beauty': 'Beauté',
          'cat_mode': 'Mode', 'cat_travel': 'Voyage',
          'cat_humour': 'Humour', 'cat_musique': 'Musique',
          'cat_wellness': 'Bien-être', 'cat_podcast': 'Podcast',
          'cat_famille': 'Famille', 'cat_finance': 'Finance',
          'cat_business': 'Business', 'cat_actu': 'Actualités',
          'cat_societe': 'Société', 'cat_diy': 'DIY',
          'cat_deco': 'Déco & Home', 'cat_auto': 'Auto & Moto',
          'cat_culture': 'Culture', 'cat_cinema': 'Cinéma & Séries',
          'cat_growth': 'Dév. Personnel', 'cat_pets': 'Animaux',
          'cat_nature': 'Nature & Écologie', 'cat_truecrime': 'True Crime',
          'cat_astro': 'Astrologie', 'cat_sport': 'Sport',
          'cat_sante': 'Santé', 'cat_science': 'Science',
          'cat_bebe': 'Bébé', 'cat_tricot': 'Couture & Tricot',
          'cat_doc': 'Documentaire', 'cat_religion': 'Religion & Foi',
          'cat_immo': 'Immobilier', 'cat_manga': 'Anime & Manga',
          'cat_politique': 'Politique', 'cat_crypto': 'Crypto & Web3',
          'cat_lang': 'Langues', 'cat_histoire': 'Histoire',
          'cat_art': 'Art', 'cat_photo': 'Photo & Vidéo',
          'cat_outdoor': 'Outdoor & Aventure', 'cat_psycho': 'Psychologie',
          'cat_luxe': 'Luxe & Lifestyle', 'cat_entrepreneuriat': 'Entrepreneuriat',
          'cat_education': 'Éducation', 'cat_cosplay': 'Cosplay & Geek',
          'cat_dance': 'Danse', 'cat_comedy': 'Stand-up',
          'cat_jardin': 'Jardinage', 'cat_sport_extreme': 'Sports Extrêmes',
          'cat_nutrition': 'Nutrition & Diète', 'cat_vintage': 'Vintage & Rétro',
          'cat_fail': 'Fails & Compilations',
        };
        final isCatId = catName.startsWith('cat_');
        final newCat = ClipCategory(
          id: isCatId ? catName : 'ai_\${DateTime.now().millisecondsSinceEpoch}',
          name: catNames[catName] ?? catName,
          color: catColors[catName] ?? const Color(0xFF7C3AED),
          icon: catIcons[catName] ?? Icons.folder_rounded,
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
  /// Réordonne les catégories après un drag & drop sur l'accueil.
  /// oldIndex/newIndex sont relatifs à la liste affichée (sans la tuile "Tout").
  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final visible = _categories.where((c) => countForCategory(c.id) > 0).toList();
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    final moved = visible.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    visible.insert(target.clamp(0, visible.length), moved);

    // 1) Mise à jour immédiate en mémoire + notify pour un rendu instantané,
    //    avant toute écriture en base (évite le "rebond" visuel).
    final updatedList = <ClipCategory>[];
    for (var i = 0; i < visible.length; i++) {
      final updated = visible[i].copyWith(position: i);
      updatedList.add(updated);
      final idx = _categories.indexWhere((c) => c.id == updated.id);
      if (idx != -1) _categories[idx] = updated;
    }
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
