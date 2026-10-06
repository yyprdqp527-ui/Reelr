import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classification_result.dart';
import '../models/client_profile.dart';

class ProfileService {
  static const String _prefix = 'client_profile_';

  Future<ClientProfile> loadProfile([String userId = 'default']) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_prefix$userId');
    if (json == null) return ClientProfile.empty(userId: userId);
    try {
      final loaded =
          ClientProfile.fromMap(jsonDecode(json) as Map<String, dynamic>);
      // Nettoyage rétroactif (une fois suffit, voir la doc de la méthode) :
      // purge un éventuel apprentissage erroné sur un nom générique de
      // plateforme (ex. "pinterest") datant d'avant ce correctif.
      final cleaned = loaded.withoutGenericPlatformChannels();
      if (!identical(cleaned, loaded)) {
        await saveProfile(cleaned);
      }
      return cleaned;
    } catch (e) {
      debugPrint('[profile] corrupted profile for $userId, resetting: $e');
      return ClientProfile.empty(userId: userId);
    }
  }

  Future<void> saveProfile(ClientProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_prefix${profile.userId}', jsonEncode(profile.toMap()));
  }

  /// Confirme une classification : met à jour les compteurs du profil
  /// ET apprend les mots du titre → catégorie confirmée.
  Future<ClientProfile> confirmClassification({
    required ClassificationResult result,
    required String videoTitle,
    String? channel,
    String userId = 'default',
  }) async {
    final profile = await loadProfile(userId);
    // `withLearnedWords` retire de cette chaine le 2026-08-09. Il alimentait
    // `personalVocabulary`, dont la lecture a ete desactivee le matin meme
    // (commit 4de62d4) : ce mecanisme apprenait mot par mot, y compris des
    // mots generiques comme « vie » ou « affaire ».
    //
    // On ecrivait donc dans un magasin que plus personne ne lisait — et pire,
    // on y ecrivait a partir des predictions du modele, pas de corrections
    // humaines. `videoTitle` reste dans la signature : il redeviendra utile
    // le jour ou l'apprentissage sera rebranche sur un vrai signal.
    final updated = profile.withConfirmedClassification(
      result.categoriePrincipale,
      lifestyle: result.styleDeVie,
      influencer: result.influenceurDetecte,
    );
    // L'apprentissage de la chaine a partir des reponses de Claude est
    // retire (2026-10-06) : apres 3 reponses identiques, la couche 2
    // classait toute la chaine sans appeler Claude, donc une erreur
    // repetee se figeait. La chaine n'est apprise que d'un geste de
    // l'utilisatrice (_learnChannelFromUserChoice, clips_state.dart).
    await saveProfile(updated);
    return updated;
  }

  /// Corrige une classification : pénalise la mauvaise catégorie (-1),
  /// booste la bonne (+2), ET apprend les mots du titre fortement (+2).
  Future<ClientProfile> correctClassification({
    required String videoTitle,
    required String wrongCategory,
    required String correctCategory,
    String userId = 'default',
  }) async {
    final profile = await loadProfile(userId);
    final correction = CategoryCorrection(
      videoTitle: videoTitle,
      wrongCategory: wrongCategory,
      correctCategory: correctCategory,
      correctedAt: DateTime.now(),
    );
    // Les deux `withLearnedWords` ont ete retires le 2026-08-09, pour la meme
    // raison que dans `confirmClassification` : `personalVocabulary` n'est
    // plus lu, et l'apprentissage mot par mot etait la source du probleme.
    //
    // Seule la correction elle-meme est conservee. C'est elle qui compte :
    // le prompt injecte les trois dernieres via `profile.corrections`.
    final updated = profile.withCorrection(correction);
    await saveProfile(updated);
    return updated;
  }

  Future<void> resetProfile([String userId = 'default']) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$userId');
  }
}
