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

  /// Le lien montre un produit qu'on peut acheter (etiquette « a acheter »).
  final bool aAcheter;

  /// Deuxieme hypothese (ID cat_xxx), quand Claude hesite. Sert a proposer
  /// « X ou Y ? » sur un lien laisse a trier.
  final String? alternative;

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
    this.aAcheter = false,
    this.alternative,
  });

  ClassificationResult withAlternative(String? alt) => ClassificationResult(
        categoriePrincipale: categoriePrincipale,
        sousCategories: sousCategories,
        influenceurDetecte: influenceurDetecte,
        marqueDetectee: marqueDetectee,
        styleDeVie: styleDeVie,
        ambiance: ambiance,
        audienceCible: audienceCible,
        confiance: confiance,
        raison: raison,
        tagsSuggeres: tagsSuggeres,
        aAcheter: aAcheter,
        alternative: alt,
      );

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    final influenceur = json['influenceur_detecte'];
    final marque = json['marque_detectee'];
    return ClassificationResult(
      categoriePrincipale:
          json['categorie_principale'] as String? ?? 'À trier',
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
      aAcheter: json['a_acheter'] == true || json['a_acheter'] == 'true',
      alternative: json['categorie_alternative'] as String?,
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
        'a_acheter': aAcheter,
        'categorie_alternative': alternative,
      };
}
