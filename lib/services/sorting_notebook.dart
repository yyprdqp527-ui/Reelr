import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un rangement fait a la main par l'utilisatrice : ce qu'etait le lien,
/// et la categorie qu'elle a choisie.
class NotebookEntry {
  /// Identifiant du clip : ranger deux fois le meme clip remplace l'entree.
  final String id;

  /// Titre tel qu'affiche (pour l'ecran et pour le prompt).
  final String title;

  /// Texte servant a la comparaison : titre, mots de l'adresse, createur.
  final String text;

  /// Ce qui est envoye a Claude : un `cat_xxx`, ou le nom exact d'une tuile
  /// personnelle.
  final String categoryRef;

  /// Nom de la categorie au moment du rangement (affichage).
  final String categoryLabel;

  final int addedAtMs;

  const NotebookEntry({
    required this.id,
    required this.title,
    required this.text,
    required this.categoryRef,
    required this.categoryLabel,
    required this.addedAtMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'text': text,
        'ref': categoryRef,
        'label': categoryLabel,
        'at': addedAtMs,
      };

  static NotebookEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final text = raw['text'];
    final ref = raw['ref'];
    final label = raw['label'];
    final at = raw['at'];
    if (id is! String ||
        title is! String ||
        text is! String ||
        ref is! String ||
        label is! String ||
        at is! int) {
      return null;
    }
    return NotebookEntry(
      id: id,
      title: title,
      text: text,
      categoryRef: ref,
      categoryLabel: label,
      addedAtMs: at,
    );
  }
}

/// Carnet des rangements manuels (2026-10-07).
///
/// Chaque fois que l'utilisatrice range un lien elle-meme, on retient
/// « ce lien -> cette categorie ». Pour un nouveau lien, on retrouve les
/// exemples qui parlent du meme sujet (mots communs) et on les donne a
/// Claude. Le signal vient d'un geste humain, jamais d'une prediction de la
/// machine : pas de boucle fermee.
class SortingNotebook {
  /// [key] : un carnet par usage (categories par defaut, sous-tuiles a part).
  // ignore: prefer_initializing_formals
  SortingNotebook({String key = 'sorting_notebook_v1'}) : _key = key;

  final String _key;
  static const int _maxEntries = 300;

  /// Nombre de mots (hors mots vides) qu'un exemple doit partager avec le
  /// nouveau lien pour etre retenu.
  static const int _minSharedWords = 2;

  /// Nombre maximal d'exemples envoyes a Claude.
  static const int _maxExamples = 4;

  static const Set<String> _stopWords = {
    'www', 'com', 'net', 'org', 'http', 'https', 'html', 'the', 'and', 'for',
    'with', 'from', 'you', 'your', 'are', 'this', 'that', 'free', 'best',
    'les', 'des', 'une', 'pour', 'avec', 'dans', 'sur', 'par', 'est', 'que',
    'qui', 'pas', 'plus', 'aux', 'mots', 'adresse', 'page', 'nom', 'image',
    'instagram', 'youtube', 'tiktok', 'facebook', 'pinterest', 'google',
    'play', 'applis', 'applications', 'application',
  };

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };

  /// Mots significatifs d'un texte : minuscules, sans accents, 3 lettres ou
  /// plus, ni chiffres seuls ni mots vides.
  static Set<String> tokens(String text) {
    final buf = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      buf.write(_accents[ch] ?? ch);
    }
    return buf
        .toString()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) =>
            t.length >= 3 &&
            !RegExp(r'^[0-9]+$').hasMatch(t) &&
            !_stopWords.contains(t))
        .toSet();
  }

  Future<List<NotebookEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (NotebookEntry.fromMap(e) != null) NotebookEntry.fromMap(e)!,
      ];
    } catch (e) {
      debugPrint('[carnet] lecture impossible: $e');
      return [];
    }
  }

  Future<void> _save(List<NotebookEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final e in entries) e.toMap()]));
    } catch (e) {
      debugPrint('[carnet] ecriture impossible: $e');
    }
  }

  /// Retient un rangement. Remplace l'entree existante du meme clip.
  /// Ne retient rien si le texte n'a pas assez de mots pour etre comparable.
  Future<void> record(NotebookEntry entry) async {
    if (tokens(entry.text).length < _minSharedWords) {
      debugPrint('[carnet] "${entry.title}" : trop peu de mots, non retenu');
      return;
    }
    final entries = await load();
    entries.removeWhere((e) => e.id == entry.id);
    entries.add(entry);
    entries.sort((a, b) => a.addedAtMs.compareTo(b.addedAtMs));
    final kept = entries.length > _maxEntries
        ? entries.sublist(entries.length - _maxEntries)
        : entries;
    await _save(kept);
    debugPrint('[carnet] retenu : "${entry.title}" -> ${entry.categoryLabel}');
  }

  Future<void> remove(String id) async {
    final entries = await load();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[carnet] effacement impossible: $e');
    }
  }

  /// Exemples proches de [text], deja formates pour le prompt
  /// (`"titre" -> categorie`). [excludeId] ecarte le clip lui-meme.
  Future<List<String>> promptExamples(String text, {String? excludeId}) async {
    final query = tokens(text);
    if (query.length < _minSharedWords) return const [];
    final entries = await load();
    final scored = <MapEntry<NotebookEntry, int>>[];
    for (final e in entries) {
      if (e.id == excludeId) continue;
      final shared = tokens(e.text).intersection(query).length;
      if (shared >= _minSharedWords) scored.add(MapEntry(e, shared));
    }
    scored.sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : b.key.addedAtMs.compareTo(a.key.addedAtMs);
    });
    return [
      for (final s in scored.take(_maxExamples))
        '"${_oneLine(s.key.title, 100)}" → ${s.key.categoryRef}',
    ];
  }

  static String _oneLine(String s, int max) {
    final flat = s.replaceAll(RegExp(r'\s+'), ' ').replaceAll('"', "'").trim();
    return flat.length > max ? '${flat.substring(0, max)}…' : flat;
  }
}
