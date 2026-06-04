class ClassificationResult {
  final String categoriePrincipale;
  final List<String> sousCategories;
  final String? influenceurDetecte;
  final String? marqueDetectee;
  final String? styleDeVie;
  final String? ambiance;
  final String? audienceCible;
  final int confiance;
  final String raison;
  final List<String> tagsSuggeres;

  const ClassificationResult({
    required this.categoriePrincipale,
    required this.sousCategories,
    this.influenceurDetecte,
    this.marqueDetectee,
    this.styleDeVie,
    this.ambiance,
    this.audienceCible,
    required this.confiance,
    required this.raison,
    required this.tagsSuggeres,
  });

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    final influenceur = json['influenceur_detecte'];
    final marque = json['marque_detectee'];
    return ClassificationResult(
      categoriePrincipale:
          json['categorie_principale'] as String? ?? 'Non classé',
      sousCategories: (json['sous_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      influenceurDetecte: (influenceur == null || influenceur == 'null')
          ? null
          : influenceur as String,
      marqueDetectee: (marque == null || marque == 'null')
          ? null
          : marque as String,
      styleDeVie: json['style_de_vie'] as String?,
      ambiance: json['ambiance'] as String?,
      audienceCible: json['audience_cible'] as String?,
      confiance: (json['confiance'] as num?)?.toInt() ?? 0,
      raison: json['raison'] as String? ?? '',
      tagsSuggeres: (json['tags_suggeres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
        'categorie_principale': categoriePrincipale,
        'sous_categories': sousCategories,
        'influenceur_detecte': influenceurDetecte,
        'marque_detectee': marqueDetectee,
        'style_de_vie': styleDeVie,
        'ambiance': ambiance,
        'audience_cible': audienceCible,
        'confiance': confiance,
        'raison': raison,
        'tags_suggeres': tagsSuggeres,
      };
}
