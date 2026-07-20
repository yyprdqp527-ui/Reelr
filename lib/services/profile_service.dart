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
      return ClientProfile.fromMap(
          jsonDecode(json) as Map<String, dynamic>);
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
    var updated = profile
        .withConfirmedClassification(
          result.categoriePrincipale,
          lifestyle: result.styleDeVie,
          influencer: result.influenceurDetecte,
        )
        .withLearnedWords(videoTitle, result.categoriePrincipale, increment: 1);
    if (channel != null && channel.isNotEmpty) {
      updated = updated.withLearnedChannel(
          channel, result.categoriePrincipale,
          increment: 1);
    }
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
    final updated = profile
        .withCorrection(correction)
        // Les mots du titre pointent vers la bonne catégorie avec score fort
        .withLearnedWords(videoTitle, correctCategory, increment: 2)
        // Et on pénalise légèrement pour la mauvaise
        .withLearnedWords(videoTitle, wrongCategory, increment: -1);
    await saveProfile(updated);
    return updated;
  }

  Future<void> resetProfile([String userId = 'default']) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$userId');
  }
}
