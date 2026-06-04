import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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

class ClipsState extends ChangeNotifier {
  /// Sentinel categoryId used to represent "unclassified" clips in navigation.
  /// Clips with `categoryId == null` are the actual unclassified clips.
  static const String unclassifiedSentinel = '__unclassified__';

  List<Clip> _clips = [];
  List<ClipCategory> _categories = [];
  List<SubCategory> _subcategories = [];
  Map<String, String> _clipSubcategoryMap = {};
  String _searchQuery = '';
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  List<ClipCategory> get categories => _categories;

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

  Future<void> loadClips() async {
    _clips = await DatabaseHelper.instance.getAllClips();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addClip(Clip clip) async {
    if (isDuplicate(clip.url)) return;
    await DatabaseHelper.instance.insertClip(clip);
    // Classification automatique en arrière-plan
    Future(() => classifyClipInBackground(clip));
    _clips.insert(0, clip);
    notifyListeners();
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

  static final RegExp _spacesRegex = RegExp(r'\s+');
  static final RegExp _nonWordRegex = RegExp(r'[^a-z0-9\s]');

  static String _stripAccents(String input) {
    const map = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
    };
    final sb = StringBuffer();
    for (final ch in input.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static String _normalizeCategoryName(String input) {
    var s = input.toLowerCase().trim();
    s = _stripAccents(s);
    s = s.replaceAll("'", ' ');
    s = s.replaceAll(_nonWordRegex, ' ');
    s = s.replaceAll(_spacesRegex, ' ').trim();
    return s;
  }

  static Set<String> _categoryTokens(String input) {
    const stopWords = {
      'l',
      'le',
      'la',
      'les',
      'de',
      'du',
      'des',
      'd',
      'the',
      'a',
      'an',
      'et',
      'and',
    };
    return _normalizeCategoryName(input)
        .split(' ')
        .where((t) => t.isNotEmpty && !stopWords.contains(t))
        .toSet();
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  static double _categorySimilarityScore(String rawA, String rawB) {
    final a = _normalizeCategoryName(rawA);
    final b = _normalizeCategoryName(rawB);
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    final aTokens = _categoryTokens(a);
    final bTokens = _categoryTokens(b);
    if (aTokens.isNotEmpty && bTokens.isNotEmpty) {
      if (aTokens.length >= 2 && aTokens.every(bTokens.contains)) {
        return 0.93;
      }
      if (bTokens.length >= 2 && bTokens.every(aTokens.contains)) {
        return 0.93;
      }
    }

    if (a.length >= 5 && b.length >= 5 && (a.contains(b) || b.contains(a))) {
      return 0.90;
    }

    final inter = aTokens.intersection(bTokens).length.toDouble();
    final union = aTokens.union(bTokens).length.toDouble();
    final jaccard = union == 0 ? 0 : inter / union;

    final dist = _levenshteinDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    final levScore = maxLen == 0 ? 0 : 1 - (dist / maxLen);

    return (levScore * 0.7) + (jaccard * 0.3);
  }

  ClipCategory? findBestCategoryMatch(
    String input, {
    double minScore = 0.82,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    ClipCategory? best;
    var bestScore = minScore;
    for (final cat in _categories) {
      final score = _categorySimilarityScore(trimmed, cat.name);
      if (score > bestScore) {
        bestScore = score;
        best = cat;
      }
    }
    return best;
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

  Future<int> moveAllClipsToCategory({
    required String fromCategoryId,
    required String toCategoryId,
    String? createSubcategoryName,
  }) async {
    if (fromCategoryId == toCategoryId) return 0;

    String? targetSubcategoryId;
    final subName = createSubcategoryName?.trim();
    final sourceCategory = categoryById(fromCategoryId);
    final targetCategory = categoryById(toCategoryId);

    if (subName != null && subName.isNotEmpty) {
      final existingSub = _subcategories.where((s) =>
          s.categoryId == toCategoryId &&
          s.name.toLowerCase().trim() == subName.toLowerCase()).firstOrNull;
      if (existingSub != null) {
        targetSubcategoryId = existingSub.id;
      } else {
        final sub = SubCategory(
          id: const Uuid().v4(),
          name: subName,
          categoryId: toCategoryId,
          color: sourceCategory?.color ??
              targetCategory?.color ??
              const Color(0xFF7C3AED),
          icon: sourceCategory?.icon ?? Icons.folder_rounded,
        );
        await DatabaseHelper.instance.insertSubCategory(sub.toMap());
        _subcategories.add(sub);
        targetSubcategoryId = sub.id;
      }
    }

    final toMove = _clips.where((c) => c.categoryId == fromCategoryId).toList();
    if (toMove.isEmpty) return 0;

    final clipIds = toMove.map((c) => c.id).toList();
    await DatabaseHelper.instance.moveClipsToCategoryBatch(
      clipIds: clipIds,
      toCategoryId: toCategoryId,
      toSubcategoryId: targetSubcategoryId,
    );

    for (final clip in toMove) {
      final updated = clip.copyWith(categoryId: toCategoryId);

      final idx = _clips.indexWhere((c) => c.id == clip.id);
      if (idx != -1) {
        _clips[idx] = updated;
      }

      if (targetSubcategoryId == null) {
        _clipSubcategoryMap.remove(clip.id);
      } else {
        _clipSubcategoryMap[clip.id] = targetSubcategoryId;
      }
    }

    notifyListeners();
    return toMove.length;
  }

  int countForCategory(String? categoryId) =>
      _clips.where((c) => c.categoryId == categoryId).length;

  int get totalCount => _clips.length;

  // ── Newly-classified tracking ─────────────────────────────────────────────

  final Set<String> _newlyClassifiedClipIds = {};

  Set<String> get newlyClassifiedClipIds =>
      Set.unmodifiable(_newlyClassifiedClipIds);

  int newlyClassifiedCountForCategory(String? categoryId) {
    return _newlyClassifiedClipIds
        .where((id) {
          final clip = _clips.where((c) => c.id == id).firstOrNull;
          return clip != null && clip.categoryId == categoryId;
        })
        .length;
  }

  void markCategoryViewed(String categoryId) {
    final toRemove = _newlyClassifiedClipIds.where((id) {
      final clip = _clips.where((c) => c.id == id).firstOrNull;
      return clip != null && clip.categoryId == categoryId;
    }).toList();
    if (toRemove.isEmpty) return;
    for (final id in toRemove) {
      _newlyClassifiedClipIds.remove(id);
    }
    notifyListeners();
  }

  Future<void> classifyClipInBackground(Clip clip) async {
    try {
      final profile = await ProfileService().loadProfile();
      final result = await ClaudeClassifier.classify(
        video: VideoData(
          title: clip.title,
          platform: clip.platform,
          thumbnailUrl: clip.thumbnailUrl,
        ),
        profile: profile,
      );
      final catName = result.categoriePrincipale;
      var matchedCat = findBestCategoryMatch(catName);
      if (matchedCat == null) {
        final suggestion = CategoryClassifier.suggestDetailed(clip.title);
        final newCat = ClipCategory(
          id: suggestion.isUnclassified
              ? const Uuid().v4()
              : 'ai_${suggestion.key}',
          name: catName,
          color: suggestion.isUnclassified ? Colors.grey : suggestion.color,
          icon: suggestion.isUnclassified
              ? Icons.help_outline_rounded
              : suggestion.icon,
        );
        matchedCat = await addCategory(newCat);
      }
      final current =
          _clips.where((c) => c.id == clip.id).firstOrNull ?? clip;
      // Respect manual classification: only set if still unclassified
      if (current.categoryId != null) return;
      final updated = current.copyWith(categoryId: matchedCat.id);
      await updateClip(updated);
      _newlyClassifiedClipIds.add(clip.id);
      notifyListeners();
    } catch (_) {
      // Fail silently — clip stays unclassified
    }
  }

  static String normalizeUrlForDedup(String url) => _normalizeUrl(url);

  /// Normalise une URL pour la déduplication :
  /// canonise les plateformes vidéo connues puis retire le tracking générique.
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
              'feature',
              'pp',
              'ref',
              'ref_src',
            }.contains(key));

      final normalizedHost = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      final normalizedPath = uri.pathSegments.where((segment) => segment.isNotEmpty).join('/');
      final sortedEntries = cleanParams.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final sortedParams = <String, String>{
        for (final entry in sortedEntries) entry.key: entry.value,
      };

      return Uri(
        scheme: uri.scheme.toLowerCase(),
        host: normalizedHost,
        path: normalizedPath.isEmpty ? '' : '/$normalizedPath',
        queryParameters: sortedParams.isEmpty ? null : sortedParams,
      ).toString().toLowerCase();
    } catch (_) {
      return url.trim().toLowerCase();
    }
  }

  static String? _canonicalVideoUrl(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

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

    return null;
  }

  static String? _youtubeVideoId(Uri uri) {
    if (uri.host.toLowerCase().contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    final segments = uri.pathSegments;
    if (segments.contains('shorts')) {
      final index = segments.indexOf('shorts');
      if (index + 1 < segments.length) return segments[index + 1];
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
    for (final marker in const ['reel', 'p']) {
      final index = segments.indexOf(marker);
      if (index != -1 && index + 1 < segments.length) {
        return segments[index + 1];
      }
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

    // Mettre à jour la liste en mémoire
    for (final updated in sorted) {
      final idx = _clips.indexWhere((c) => c.id == updated.id);
      if (idx != -1) _clips[idx] = updated;
    }
    notifyListeners();
  }
}
