class CategoryCorrection {
  final String videoTitle;
  final String wrongCategory;
  final String correctCategory;
  final DateTime correctedAt;

  const CategoryCorrection({
    required this.videoTitle,
    required this.wrongCategory,
    required this.correctCategory,
    required this.correctedAt,
  });

  Map<String, dynamic> toMap() => {
        'videoTitle': videoTitle,
        'wrongCategory': wrongCategory,
        'correctCategory': correctCategory,
        'correctedAt': correctedAt.toIso8601String(),
      };

  factory CategoryCorrection.fromMap(Map<String, dynamic> map) =>
      CategoryCorrection(
        videoTitle: map['videoTitle'] as String,
        wrongCategory: map['wrongCategory'] as String,
        correctCategory: map['correctCategory'] as String,
        correctedAt: DateTime.parse(map['correctedAt'] as String),
      );
}

class ClientProfile {
  final String userId;
  final Map<String, int> categoryCount;
  final List<String> knownInfluencers;
  final Map<String, int> lifestyleCount;
  final List<CategoryCorrection> corrections;
  final int totalVideosClassified;

  /// Vocabulaire personnel appris par confirmation/correction.
  /// Structure : { mot → { catégorie → score } }
  /// Un mot avec score ≥ 3 dans une catégorie devient un signal fort.
  final Map<String, Map<String, int>> personalVocabulary;

  const ClientProfile({
    required this.userId,
    required this.categoryCount,
    required this.knownInfluencers,
    required this.lifestyleCount,
    required this.corrections,
    required this.totalVideosClassified,
    this.personalVocabulary = const {},
  });

  factory ClientProfile.empty({String userId = 'default'}) => ClientProfile(
        userId: userId,
        categoryCount: {},
        knownInfluencers: [],
        lifestyleCount: {},
        corrections: [],
        totalVideosClassified: 0,
        personalVocabulary: {},
      );

  /// Top 3 catégories les plus regardées.
  List<String> get topCategories {
    if (categoryCount.isEmpty) return [];
    final sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  /// Style de vie dominant.
  String? get dominantLifestyle {
    if (lifestyleCount.isEmpty) return null;
    return lifestyleCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Renvoie la catégorie apprise pour [word] si son score ≥ [minScore],
  /// ou null si pas encore assez de signal.
  String? learnedCategoryFor(String word, {int minScore = 3}) {
    final scores = personalVocabulary[word.toLowerCase()];
    if (scores == null || scores.isEmpty) return null;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value >= minScore ? best.key : null;
  }

  /// Cherche dans [title] les mots connus avec signal fort (score ≥ [minScore]).
  /// Retourne la catégorie la plus votée par les mots du titre, ou null.
  String? detectByPersonalVocabulary(String title, {int minScore = 3}) {
    final words = _extractWords(title);
    final votes = <String, int>{};
    for (final word in words) {
      final cat = learnedCategoryFor(word, minScore: minScore);
      if (cat != null) votes[cat] = (votes[cat] ?? 0) + 1;
    }
    if (votes.isEmpty) return null;
    return votes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Crée un profil mis à jour en apprenant les mots du titre.
  /// Appelé à chaque confirmation OU correction.
  ClientProfile withLearnedWords(String title, String category,
      {int increment = 1}) {
    final words = _extractWords(title);
    final newVocab =
        Map<String, Map<String, int>>.from(personalVocabulary.map(
      (k, v) => MapEntry(k, Map<String, int>.from(v)),
    ));
    for (final word in words) {
      newVocab.putIfAbsent(word, () => {});
      newVocab[word]![category] =
          (newVocab[word]![category] ?? 0) + increment;
    }
    return ClientProfile(
      userId: userId,
      categoryCount: categoryCount,
      knownInfluencers: knownInfluencers,
      lifestyleCount: lifestyleCount,
      corrections: corrections,
      totalVideosClassified: totalVideosClassified,
      personalVocabulary: newVocab,
    );
  }

  /// Extrait les mots significatifs d'un titre (≥ 3 chars, pas de mots vides).
  static List<String> _extractWords(String title) {
    const stopWords = {
      'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'et', 'en',
      'au', 'aux', 'ce', 'se', 'sa', 'son', 'ses', 'mon', 'ma', 'mes',
      'ton', 'ta', 'tes', 'on', 'il', 'elle', 'ils', 'elles', 'je',
      'tu', 'nous', 'vous', 'que', 'qui', 'quoi', 'ou', 'où', 'par',
      'sur', 'sous', 'dans', 'avec', 'for', 'the', 'and', 'but', 'or',
      'of', 'in', 'at', 'to', 'a', 'is', 'it', 'my', 'me',
      'this', 'that', 'how', 'why', 'what', 'when', 'pas', 'ne',
    };
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9àâäéèêëîïôöùûüç\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toSet() // déduplique
        .toList();
  }

  /// Crée un profil mis à jour après confirmation d'une classification.
  ClientProfile withConfirmedClassification(
    String category, {
    String? lifestyle,
    String? influencer,
  }) {
    final newCategoryCount = Map<String, int>.from(categoryCount);
    newCategoryCount[category] = (newCategoryCount[category] ?? 0) + 1;

    final newLifestyleCount = Map<String, int>.from(lifestyleCount);
    if (lifestyle != null) {
      newLifestyleCount[lifestyle] = (newLifestyleCount[lifestyle] ?? 0) + 1;
    }

    final newInfluencers = List<String>.from(knownInfluencers);
    if (influencer != null && !newInfluencers.contains(influencer)) {
      newInfluencers.add(influencer);
    }

    return ClientProfile(
      userId: userId,
      categoryCount: newCategoryCount,
      knownInfluencers: newInfluencers,
      lifestyleCount: newLifestyleCount,
      corrections: corrections,
      totalVideosClassified: totalVideosClassified + 1,
      personalVocabulary: personalVocabulary,
    );
  }

  /// Crée un profil mis à jour après correction.
  /// La catégorie correcte gagne +2 (bonus) et la mauvaise perd 1.
  ClientProfile withCorrection(CategoryCorrection correction) {
    final newCategoryCount = Map<String, int>.from(categoryCount);
    if (newCategoryCount.containsKey(correction.wrongCategory)) {
      newCategoryCount[correction.wrongCategory] =
          (newCategoryCount[correction.wrongCategory]! - 1).clamp(0, 999999);
    }
    newCategoryCount[correction.correctCategory] =
        (newCategoryCount[correction.correctCategory] ?? 0) + 2;

    return ClientProfile(
      userId: userId,
      categoryCount: newCategoryCount,
      knownInfluencers: knownInfluencers,
      lifestyleCount: lifestyleCount,
      corrections: [...corrections, correction],
      totalVideosClassified: totalVideosClassified,
      personalVocabulary: personalVocabulary,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'categoryCount': categoryCount,
        'knownInfluencers': knownInfluencers,
        'lifestyleCount': lifestyleCount,
        'corrections': corrections.map((c) => c.toMap()).toList(),
        'totalVideosClassified': totalVideosClassified,
        'personalVocabulary': personalVocabulary.map(
          (word, scores) => MapEntry(word, scores),
        ),
      };

  factory ClientProfile.fromMap(Map<String, dynamic> map) => ClientProfile(
        userId: map['userId'] as String,
        categoryCount: Map<String, int>.from(
            (map['categoryCount'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, v as int))),
        knownInfluencers:
            List<String>.from(map['knownInfluencers'] as List<dynamic>? ?? []),
        lifestyleCount: Map<String, int>.from(
            (map['lifestyleCount'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, v as int))),
        corrections: (map['corrections'] as List<dynamic>? ?? [])
            .map((c) =>
                CategoryCorrection.fromMap(c as Map<String, dynamic>))
            .toList(),
        totalVideosClassified:
            map['totalVideosClassified'] as int? ?? 0,
        personalVocabulary: (map['personalVocabulary']
                    as Map<String, dynamic>? ??
                {})
            .map((word, scores) => MapEntry(
                  word,
                  Map<String, int>.from(
                    (scores as Map<String, dynamic>)
                        .map((k, v) => MapEntry(k, v as int)),
                  ),
                )),
      );
}
