import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../services/profile_service.dart';

class ClassificationResultCard extends StatefulWidget {
  final ClassificationResult result;
  final String videoTitle;
  final VoidCallback? onProfileUpdated;

  const ClassificationResultCard({
    super.key,
    required this.result,
    required this.videoTitle,
    this.onProfileUpdated,
  });

  @override
  State<ClassificationResultCard> createState() =>
      _ClassificationResultCardState();
}

class _ClassificationResultCardState extends State<ClassificationResultCard> {
  final ProfileService _profileService = ProfileService();
  bool _feedbackGiven = false;
  String? _feedbackMessage;
  bool _loading = false;

  static const List<String> _allCategories = [
    'Beauty',
    'Style',
    'Food',
    'Fitness',
    'Tech & Gaming',
    'Travel',
    'Finance & Business',
    'Famille',
    'Humour',
    'Musique',
    'Wellness',
    'Growth',
    'Actu & Société',
    'DIY & Créa',
    'Pets & Nature',
    'Déco & Home',
    'Auto & Moto',
    'Culture',
    'Podcast',
    'True Crime',
    'Documentaire',
    'Cinéma & Séries',
    'Astro & Spirituel',
    'Tricot/Couture',
  ];

  Color _colorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('beauté') || lower.contains('make-up')) {
      return const Color(0xFFF48FB1);
    } else if (lower.contains('mode') || lower.contains('style')) {
      return const Color(0xFFCE93D8);
    } else if (lower.contains('food') || lower.contains('cuisine')) {
      return const Color(0xFFFFCC80);
    } else if (lower.contains('fitness') || lower.contains('sport')) {
      return const Color(0xFFEF9A9A);
    } else if (lower.contains('tech') || lower.contains('gaming')) {
      return const Color(0xFF90CAF9);
    } else if (lower.contains('voyage') || lower.contains('aventure')) {
      return const Color(0xFF80CBC4);
    } else if (lower.contains('finance') || lower.contains('business')) {
      return const Color(0xFFA5D6A7);
    } else if (lower.contains('famille') || lower.contains('parentalité')) {
      return const Color(0xFFFFAB91);
    } else if (lower.contains('humour') || lower.contains('divertissement')) {
      return const Color(0xFFFFF176);
    } else if (lower.contains('musique') || lower.contains('danse')) {
      return const Color(0xFFE6EE9C);
    } else if (lower.contains('développement')) {
      return const Color(0xFF9FA8DA);
    } else if (lower.contains('bien-être') || lower.contains('santé')) {
      return const Color(0xFF80DEEA);
    } else if (lower.contains('actualité') || lower.contains('société')) {
      return const Color(0xFFB0BEC5);
    } else if (lower.contains('diy') || lower.contains('créativité')) {
      return const Color(0xFFFFE082);
    } else if (lower.contains('animaux') || lower.contains('nature')) {
      return const Color(0xFFC5E1A5);
    } else if (lower.contains('immobilier') || lower.contains('déco')) {
      return const Color(0xFFBCAAA4);
    } else if (lower.contains('automobile') || lower.contains('mobilité')) {
      return const Color(0xFFFFCC80);
    } else if (lower.contains('education') || lower.contains('culture')) {
      return const Color(0xFF80DEEA);
    }
    return const Color(0xFFE0E0E0);
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await _profileService.confirmClassification(
          result: widget.result, videoTitle: widget.videoTitle);
      if (!mounted) return;
      setState(() {
        _feedbackGiven = true;
        _feedbackMessage = 'Merci !';
        _loading = false;
      });
      widget.onProfileUpdated?.call();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _correct(String correctCategory) async {
    setState(() => _loading = true);
    try {
      await _profileService.correctClassification(
        videoTitle: widget.videoTitle,
        wrongCategory: widget.result.categoriePrincipale,
        correctCategory: correctCategory,
      );
      if (!mounted) return;
      setState(() {
        _feedbackGiven = true;
        _feedbackMessage = 'Correction enregistrée';
        _loading = false;
      });
      widget.onProfileUpdated?.call();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCorrectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Localizations.localeOf(context).languageCode == 'fr' ? 'Quelle est la bonne catégorie ?' : 'What is the right category?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _allCategories.length,
                itemBuilder: (_, i) {
                  final cat = _allCategories[i];
                  final isCurrent =
                      cat == widget.result.categoriePrincipale;
                  return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _colorForCategory(cat),
                        radius: 10,
                      ),
                      title: Text(cat),
                      trailing: isCurrent
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: isCurrent
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _correct(cat);
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final categoryColor = _colorForCategory(result.categoriePrincipale);
    final headerTextColor =
        ThemeData.estimateBrightnessForColor(categoryColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête coloré ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.categoriePrincipale,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                ),
                if (result.influenceurDetecte != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          result.influenceurDetecte!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Corps de la carte ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sous-catégories
                if (result.sousCategories.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: result.sousCategories
                        .map((s) => Chip(
                              label: Text(s,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor:
                                  categoryColor.withValues(alpha: 0.2),
                              side: BorderSide(
                                  color: categoryColor.withValues(alpha: 0.4)),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Lifestyle & Ambiance
                if (result.styleDeVie != null ||
                    result.ambiance != null) ...[
                  Row(
                    children: [
                      if (result.styleDeVie != null) ...[
                        const Icon(Icons.person_outline,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            result.styleDeVie!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                      if (result.styleDeVie != null &&
                          result.ambiance != null)
                        const Text('  •  ',
                            style: TextStyle(color: Colors.grey)),
                      if (result.ambiance != null) ...[
                        const Icon(Icons.mood_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            result.ambiance!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Audience cible
                if (result.audienceCible != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          result.audienceCible!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Barre de confiance
                Row(
                  children: [
                    Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Confiance' : 'Confidence',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: result.confiance / 100.0,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              categoryColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${result.confiance}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Raison
                Text(
                  result.raison,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black54),
                ),

                // Tags suggérés
                if (result.tagsSuggeres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: result.tagsSuggeres
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                '#$t',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54),
                              ),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Zone de feedback ─────────────────────────────────
                if (_feedbackGiven)
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _feedbackMessage!,
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cette classification est-elle correcte ?',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      else ...[
                        TextButton.icon(
                          onPressed: _confirm,
                          icon: const Text('✅'),
                          label: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Oui' : 'Yes'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showCorrectionSheet,
                          icon: const Text('✏️'),
                          label: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Corriger' : 'Fix'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
