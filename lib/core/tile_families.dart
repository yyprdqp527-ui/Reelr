/// Regroupement des sujets du catalogue en tuiles meres (decision d'Anne,
/// 12 nov. 2026, voir technical-notes/plan-regroupement-tuiles).
///
/// Claude continue de choisir un sujet parmi le catalogue. Cette table dit
/// seulement dans quelle tuile mere ce sujet est range, comme THEME (sous-tuile
/// portant le nom du sujet). Un sujet absent de la table garde sa propre tuile.
class TileFamilies {
  TileFamilies._();

  /// Tuiles meres qui ne sont pas un sujet du catalogue de Claude.
  static const Set<String> extraParents = {'cat_maison', 'cat_spiritualite'};

  /// sujet (cat_xxx) -> tuile mere (cat_xxx).
  static const Map<String, String> parentOf = {
    // Recette
    'cat_patisserie': 'cat_food',
    'cat_boissons': 'cat_food',
    // Maison
    'cat_menage': 'cat_maison',
    'cat_rangement': 'cat_maison',
    'cat_travaux': 'cat_maison',
    // Beauté
    'cat_coiffure': 'cat_beauty',
    // Mode
    'cat_luxe': 'cat_mode',
    'cat_vintage': 'cat_mode',
    // DIY
    'cat_tricot': 'cat_diy',
    'cat_tricotage': 'cat_diy',
    'cat_crochet': 'cat_diy',
    'cat_broderie': 'cat_diy',
    // Spiritualité
    'cat_wellness': 'cat_spiritualite',
    'cat_astro': 'cat_spiritualite',
    // Santé
    'cat_nutrition': 'cat_sante',
    'cat_psycho': 'cat_sante',
    // Sport
    'cat_fitness': 'cat_sport',
    'cat_dance': 'cat_sport',
    // Famille
    'cat_bebe': 'cat_famille',
    // Business
    'cat_finance': 'cat_business',
    'cat_crypto': 'cat_business',
    // Auto
    'cat_moto': 'cat_auto',
    // Manga
    'cat_cosplay': 'cat_manga',
    // Culture
    'cat_cinema': 'cat_culture',
    'cat_livres': 'cat_culture',
    // Art
    'cat_design': 'cat_art',
    // Documentaire
    'cat_podcast': 'cat_doc',
    'cat_truecrime': 'cat_doc',
    // Actualité
    'cat_politique': 'cat_actu',
    'cat_societe': 'cat_actu',
    // Éducation
    'cat_lang': 'cat_education',
    'cat_science': 'cat_education',
    'cat_histoire': 'cat_education',
  };

  /// Tuile mere du sujet [subjectId], ou null s'il garde sa propre tuile.
  static String? parentIdOf(String? subjectId) =>
      subjectId == null ? null : parentOf[subjectId];

  /// Sujets rangés comme thèmes dans la tuile mère [parentId].
  static List<String> themesOf(String parentId) => [
        for (final e in parentOf.entries)
          if (e.value == parentId) e.key
      ];
}
