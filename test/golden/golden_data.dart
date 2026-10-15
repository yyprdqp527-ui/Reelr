// Jeu de test "golden" pour la classification.
// Ne contient aucune logique de production : uniquement le chargement du CSV
// et la table de correspondance nom affiché <-> identifiant de categorie.
//
// Le CSV fait foi. Pour corriger une attente, editer
// test/golden/classification_golden.csv, pas ce fichier.

import 'dart:io';

class GoldenCase {
  final String id;
  final String title;
  final String? channel;
  final String platform;
  final String expectedCatId;
  final String note;

  const GoldenCase({
    required this.id,
    required this.title,
    required this.channel,
    required this.platform,
    required this.expectedCatId,
    required this.note,
  });

  /// Cas ou la bonne reponse est de ne PAS repondre.
  bool get expectsAbstention => expectedCatId == 'cat_unclear';

  /// Cas volontairement impossible a trancher depuis le titre seul.
  bool get isUnwinnableFromTitle => note.contains('Non gagnable');
}

/// Identifiant -> nom affiche. Copie de la table de `clips_state.dart`.
/// Si tu ajoutes une categorie dans l'app, ajoute-la ici aussi.
const Map<String, String> kCategoryNames = {
  'cat_food': 'Food', 'cat_fitness': 'Fitness', 'cat_gaming': 'Gaming',
  'cat_beauty': 'Beauté', 'cat_mode': 'Mode', 'cat_travel': 'Voyage',
  'cat_humour': 'Humour', 'cat_musique': 'Musique', 'cat_wellness': 'Bien-être',
  'cat_podcast': 'Podcast', 'cat_famille': 'Famille', 'cat_finance': 'Finance',
  'cat_business': 'Business', 'cat_actu': 'Actualités', 'cat_societe': 'Société',
  'cat_diy': 'DIY', 'cat_deco': 'Déco', 'cat_auto': 'Auto', 'cat_moto': 'Moto',
  'cat_culture': 'Culture', 'cat_cinema': 'Cinéma',
  'cat_growth': 'Dév. Personnel', 'cat_pets': 'Animaux', 'cat_nature': 'Nature',
  'cat_truecrime': 'True Crime', 'cat_astro': 'Astrologie', 'cat_sport': 'Sport',
  'cat_sante': 'Santé', 'cat_science': 'Science', 'cat_bebe': 'Bébé',
  'cat_tricot': 'Couture', 'cat_tricotage': 'Tricot', 'cat_crochet': 'Crochet', 'cat_broderie': 'Broderie',
  'cat_doc': 'Documentaire', 'cat_religion': 'Religion',
  'cat_immo': 'Immobilier', 'cat_manga': 'Anime & Manga',
  'cat_politique': 'Politique', 'cat_crypto': 'Crypto', 'cat_lang': 'Langues',
  'cat_histoire': 'Histoire', 'cat_art': 'Art', 'cat_photo': 'Photo',
  'cat_outdoor': 'Outdoor', 'cat_psycho': 'Psychologie', 'cat_luxe': 'Luxe',
  'cat_entrepreneuriat': 'Entrepreneuriat', 'cat_education': 'Éducation',
  'cat_cosplay': 'Cosplay', 'cat_dance': 'Danse', 'cat_comedy': 'Stand-up',
  'cat_jardin': 'Jardinage', 'cat_sport_extreme': 'Extrême',
  'cat_nutrition': 'Nutrition', 'cat_vintage': 'Vintage', 'cat_fail': 'Fails',
  'cat_tech': 'Tech', 'cat_vibes': 'Vibes',
  'cat_shopping': 'Shopping',
  'cat_restaurant': 'Restaurant',
  'cat_menage': 'Ménage',
  'cat_travaux': 'Travaux',
  'cat_rangement': 'Rangement',
  'cat_coiffure': 'Coiffure',
  'cat_patisserie': 'Pâtisserie',
  'cat_boissons': 'Boissons',
  'cat_livres': 'Livres',
  'cat_design': 'Design & UX',
};

/// Nom affiche (minuscule) -> identifiant. Construit a partir de la table
/// ci-dessus. Sert a convertir ce que renvoient les couches locales
/// (qui renvoient des NOMS) vers l'espace des identifiants du CSV.
final Map<String, String> kCategoryIdByName = {
  for (final e in kCategoryNames.entries) e.value.toLowerCase().trim(): e.key,
};

/// Tous les noms de categories, tels que les verrait un utilisateur actif.
final List<String> kAllCategoryNames = kCategoryNames.values.toList();

/// Convertit un nom renvoye par une couche locale en identifiant `cat_*`.
/// Renvoie `unknown:<nom>` si la couche a invente un nom qui ne correspond
/// a aucune categorie -- c'est un echec en soi (creation de doublon).
String toCatId(String name) {
  final key = name.toLowerCase().trim();
  if (key.startsWith('cat_')) return key;
  return kCategoryIdByName[key] ?? 'unknown:$name';
}

/// Charge le CSV. Parseur minimal mais correct sur les champs entre guillemets.
List<GoldenCase> loadGoldenCases([
  String path = 'test/golden/classification_golden.csv',
]) {
  final lines = File(path).readAsLinesSync();
  final cases = <GoldenCase>[];
  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    final f = _splitCsvLine(raw);
    if (f.length < 5) continue;
    cases.add(GoldenCase(
      id: f[0],
      title: f[1],
      channel: f[2].trim().isEmpty ? null : f[2],
      platform: f[3],
      expectedCatId: f[4],
      note: f.length > 5 ? f[5] : '',
    ));
  }
  return cases;
}

List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}
