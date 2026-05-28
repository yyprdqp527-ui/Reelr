import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/clip.dart';
import '../services/database.dart';

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

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addClip(Clip clip) async {
    await DatabaseHelper.instance.insertClip(clip);
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

  Future<void> addCategory(ClipCategory category) async {
    await DatabaseHelper.instance.insertCategory(category);
    _categories.add(category);
    notifyListeners();
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

  int countForCategory(String? categoryId) =>
      _clips.where((c) => c.categoryId == categoryId).length;

  int get totalCount => _clips.length;

  bool isDuplicate(String url) =>
      _clips.any((c) => c.url.trim() == url.trim());

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
