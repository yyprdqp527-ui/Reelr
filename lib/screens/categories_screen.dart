import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/l10n.dart';
import '../models/category.dart';
import '../state/clips_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/sheet_field.dart';

// ─────────────────────────────────────────────
// ICON SUGGESTION BY NAME
// ─────────────────────────────────────────────

const categoryColorChoices = <Color>[
  Color(0xFF4F8EF7), Color(0xFF2563EB), Color(0xFF0EA5E9), Color(0xFF06B6D4),
  Color(0xFF2ECC71), Color(0xFF10B981), Color(0xFF84CC16), Color(0xFF4ADE80),
  Color(0xFFFF5252), Color(0xFFE91E63), Color(0xFFF43F5E), Color(0xFFFF6B9D),
  Color(0xFFFF9800), Color(0xFFFFB300), Color(0xFFF97316), Color(0xFFEAB308),
];

const categoryIconChoices = <IconData>[
  Icons.folder_rounded,
  Icons.star_rounded,
  Icons.bookmark_rounded,
  Icons.favorite_rounded,
  Icons.work_rounded,
  Icons.school_rounded,
  Icons.sports_esports_rounded,
  Icons.music_note_rounded,
  Icons.movie_rounded,
  Icons.restaurant_rounded,
  Icons.travel_explore_rounded,
  Icons.science_rounded,
  Icons.dry_cleaning_rounded,
  Icons.checkroom_rounded,
  Icons.face_retouching_natural,
  Icons.fitness_center_rounded,
  Icons.business_center_rounded,
  Icons.account_balance_rounded,
  Icons.health_and_safety_rounded,
  Icons.palette_rounded,
  Icons.home_rounded,
  Icons.eco_rounded,
  Icons.pets_rounded,
  Icons.child_care_rounded,
  Icons.shopping_bag_rounded,
  Icons.self_improvement_rounded,
  Icons.computer_rounded,
  Icons.camera_alt_rounded,
  Icons.auto_stories_rounded,
  Icons.menu_book_rounded,
  Icons.theater_comedy_rounded,
  Icons.celebration_rounded,
  Icons.spa_rounded,
  Icons.local_hospital_rounded,
  Icons.psychology_rounded,
  Icons.church_rounded,
  Icons.volunteer_activism_rounded,
  Icons.auto_awesome_rounded,
  Icons.outdoor_grill_rounded,
  Icons.policy_rounded,
  Icons.diamond_rounded,
  Icons.wb_sunny_rounded,
  Icons.nightlight_round,
  Icons.directions_car_rounded,
  Icons.flight_takeoff_rounded,
  Icons.public_rounded,
  Icons.coffee_rounded,
  Icons.local_bar_rounded,
  Icons.fastfood_rounded,
  Icons.icecream_rounded,
  Icons.cake_rounded,
  Icons.laptop_mac_rounded,
  Icons.smartphone_rounded,
  Icons.podcasts_rounded,
  Icons.mic_rounded,
  Icons.headphones_rounded,
  Icons.video_library_rounded,
  Icons.ondemand_video_rounded,
  Icons.brush_rounded,
  Icons.architecture_rounded,
  Icons.handyman_rounded,
  Icons.park_rounded,
  Icons.landscape_rounded,
  Icons.sailing_rounded,
  Icons.hiking_rounded,
  Icons.attach_money_rounded,
  Icons.currency_bitcoin_rounded,
  Icons.storefront_rounded,
  Icons.sell_rounded,
  Icons.groups_rounded,
  Icons.family_restroom_rounded,
];

IconData suggestIconForCategoryName(String name) {
  final n = name.toLowerCase().trim();
  bool has(List<String> kw) => kw.any((k) => n.contains(k));

  if (has(['photo', 'photographie', 'camera', 'caméra', 'shoot'])) {
    return Icons.photo_camera_rounded;
  }
  if (has(['vidéo', 'video', 'reel', 'montage', 'editing'])) {
    return Icons.video_library_rounded;
  }
  if (has(['podcast', 'interview', 'audio', 'voix'])) {
    return Icons.podcasts_rounded;
  }
  if (has(['livre', 'book', 'lecture', 'roman', 'bibliothèque'])) {
    return Icons.auto_stories_rounded;
  }
  if (has(['humour', 'comédie', 'comedie', 'drôle', 'drole'])) {
    return Icons.theater_comedy_rounded;
  }
  if (has(['événement', 'evenement', 'event', 'fête', 'fete'])) {
    return Icons.celebration_rounded;
  }
  if (has(['mode', 'fashion', 'style', 'vêtement', 'vetement', 'robe',
      'outfit', 'luxe', 'bijou', 'accessoire'])) {
    return Icons.checkroom_rounded;
  }
  if (has(['beauté', 'beaute', 'beauty', 'makeup', 'maquillage', 'skincare',
      'soin', 'cosmétique', 'cosmetique'])) {
    return Icons.face_retouching_natural;
  }
  if (has(['cuisine', 'recette', 'food', 'repas', 'gastro', 'manger',
      'chef', 'cooking', 'pâtisserie', 'patisserie', 'boulangerie'])) {
    return Icons.restaurant_rounded;
  }
  if (has(['café', 'cafe', 'coffee', 'barista'])) {
    return Icons.coffee_rounded;
  }
  if (has(['cocktail', 'vin', 'wine', 'alcool', 'bar'])) {
    return Icons.local_bar_rounded;
  }
  if (has(['dessert', 'glace', 'ice cream', 'gâteau', 'gateau'])) {
    return Icons.icecream_rounded;
  }
  if (has(['sport', 'fitness', 'gym', 'musculation', 'running', 'yoga',
      'entrainement', 'entraînement', 'pilates', 'crossfit', 'natation'])) {
    return Icons.fitness_center_rounded;
  }
  if (has(['randonnée', 'randonnee', 'hiking', 'trek'])) {
    return Icons.hiking_rounded;
  }
  if (has(['voiture', 'car', 'auto', 'moto', 'motor'])) {
    return Icons.directions_car_rounded;
  }
  if (has(['voyage', 'travel', 'trip', 'vacances', 'aventure', 'destination',
      'roadtrip', 'expatrié', 'expatrie'])) {
    return Icons.travel_explore_rounded;
  }
  if (has(['avion', 'flight', 'aéroport', 'aeroport'])) {
    return Icons.flight_takeoff_rounded;
  }
  if (has(['musique', 'music', 'son', 'concert', 'playlist', 'chanson',
      'rap', 'pop', 'jazz', 'dj'])) {
    return Icons.music_note_rounded;
  }
  if (has(['micro', 'chant', 'voice', 'voix'])) {
    return Icons.mic_rounded;
  }
  if (has(['cinéma', 'cinema', 'film', 'série', 'serie', 'movie',
      'streaming', 'netflix', 'documentaire'])) {
    return Icons.movie_rounded;
  }
  if (has(['gaming', 'jeu', 'game', 'esport', 'gamer',
      'playstation', 'xbox', 'nintendo', 'twitch'])) {
    return Icons.sports_esports_rounded;
  }
  if (has(['tech', 'technologie', 'informatique', 'code', 'développeur',
      'developer', 'digital', 'intelligence artificielle'])) {
    return Icons.computer_rounded;
  }
  if (has(['mobile', 'iphone', 'android', 'smartphone'])) {
    return Icons.smartphone_rounded;
  }
  if (has(['business', 'entreprise', 'startup', 'entrepreneuriat',
      'marketing', 'entrepreneur', 'management', 'leadership'])) {
    return Icons.business_center_rounded;
  }
  if (has(['vente', 'sales', 'crm', 'prospection'])) {
    return Icons.sell_rounded;
  }
  if (has(['finance', 'argent', 'money', 'budget', 'investissement',
      'bourse', 'crypto', 'épargne', 'epargne'])) {
    return Icons.account_balance_rounded;
  }
  if (has(['bitcoin', 'blockchain', 'web3'])) {
    return Icons.currency_bitcoin_rounded;
  }
  if (has(['santé', 'sante', 'health', 'médical', 'medical', 'bien-être',
      'bienetre', 'médecine', 'medecine', 'mental', 'psycho'])) {
    return Icons.health_and_safety_rounded;
  }
  if (has(['spa', 'relax', 'méditation', 'meditation'])) {
    return Icons.spa_rounded;
  }
  if (has(['art', 'dessin', 'peinture', 'créatif', 'creatif', 'artiste',
      'illustration', 'photographie', 'photo', 'graphisme'])) {
    return Icons.palette_rounded;
  }
  if (has(['design', 'architecture', 'archi', 'interior'])) {
    return Icons.architecture_rounded;
  }
  if (has(['maison', 'home', 'déco', 'deco', 'intérieur', 'interieur',
      'immobilier', 'architecture', 'renovation', 'rénovation'])) {
    return Icons.home_rounded;
  }
  if (has(['bricolage', 'diy', 'outil', 'repair', 'réparation'])) {
    return Icons.handyman_rounded;
  }
  if (has(['nature', 'outdoor', 'jardin', 'garden', 'environnement',
      'plante', 'écologie', 'ecologie', 'montagne', 'randonnée'])) {
    return Icons.eco_rounded;
  }
  if (has(['mer', 'boat', 'voilier', 'sailing'])) {
    return Icons.sailing_rounded;
  }
  if (has(['animal', 'animaux', 'pet', 'chien', 'chat', 'dog', 'cat',
      'ferme', 'zoo'])) {
    return Icons.pets_rounded;
  }
  if (has(['bébé', 'bebe', 'baby', 'enfant', 'kid', 'nourrisson',
      'puériculture', 'puericulture', 'maternité', 'maternite'])) {
    return Icons.child_care_rounded;
  }
  if (has(['famille', 'family', 'parentalité', 'parentalite'])) {
    return Icons.family_restroom_rounded;
  }
  if (has(['éducation', 'education', 'cours', 'formation', 'apprendre',
      'étude', 'etude', 'scolaire', 'université', 'universite'])) {
    return Icons.school_rounded;
  }
  if (has(['shopping', 'achat', 'boutique', 'shop', 'consommation',
      'haul', 'unboxing'])) {
    return Icons.shopping_bag_rounded;
  }
  if (has(['ecommerce', 'e-commerce', 'store', 'magasin'])) {
    return Icons.storefront_rounded;
  }
  if (has(['lifestyle', 'routine', 'quotidien', 'well-being',
      'développement personnel', 'developpement personnel', 'motivation'])) {
    return Icons.self_improvement_rounded;
  }
  if (has(['relation', 'communauté', 'communaute', 'social'])) {
    return Icons.groups_rounded;
  }
  if (has(['science', 'physique', 'chimie', 'biologie', 'recherche',
      'astronomie', 'espace', 'space'])) {
    return Icons.science_rounded;
  }
  if (has(['sun', 'soleil', 'été', 'ete'])) {
    return Icons.wb_sunny_rounded;
  }
  if (has(['nuit', 'night', 'moon', 'sommeil'])) {
    return Icons.nightlight_round;
  }

  return Icons.folder_rounded;
}

// ─────────────────────────────────────────────
// EDIT CATEGORY SHEET
// ─────────────────────────────────────────────

class EditCategorySheet extends StatefulWidget {
  final ClipCategory category;
  final ClipsState state;

  const EditCategorySheet({
    super.key,
    required this.category,
    required this.state,
  });

  @override
  State<EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<EditCategorySheet> {
  late final TextEditingController _nameCtrl;
  late Color _color;
  late IconData _icon;

  static const _colors = categoryColorChoices;

  static const _icons = categoryIconChoices;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category.name);
    _color = widget.category.color;
    _icon = widget.category.icon;
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final updated = ClipCategory(
      id: widget.category.id,
      name: _nameCtrl.text.trim(),
      color: _color,
      icon: _icon,
    );
    await widget.state.updateCategory(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      l.t('edit_category'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    SheetField(
                      controller: _nameCtrl,
                      hint: l.t('category_name'),
                      icon: Icons.label_rounded,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 18),
                    Text(l.t('color'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: _colors
                          .map((c) => GestureDetector(
                                onTap: () => setState(() => _color = c),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _color == c
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: _color == c
                                        ? [
                                            BoxShadow(
                                                color: c.withValues(alpha: 0.5),
                                                blurRadius: 8)
                                          ]
                                        : [],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(l.t('icon'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 160,
                      child: SingleChildScrollView(
                        child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _icons
                          .map((ic) => GestureDetector(
                                onTap: () => setState(() => _icon = ic),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _icon == ic
                                        ? _color.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _icon == ic
                                          ? _color
                                          : Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    ic,
                                    size: 20,
                                    color: _icon == ic ? _color : Colors.grey,
                                  ),
                                ),
                              ))
                          .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l.t('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l.t('save')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORIES SCREEN
// ─────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  final ClipsState state;

  const CategoriesScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              l.t('categories'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Ajouter une catégorie',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AddCategoryDialog(state: state),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (state.categories.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  l.t('no_category'),
                  style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.5), fontSize: 16),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final cat = state.categories[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(cat.icon,
                                  color: cat.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  ),
                                  Builder(builder: (bctx) {
                                    final subs =
                                        state.getSubCategoriesFor(cat.id);
                                    if (subs.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        '${subs.length} sous-cat.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cat.color
                                              .withValues(alpha: 0.75),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _showEditSheet(context, cat),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline_rounded),
                              color: Colors.red.withValues(alpha: 0.75),
                              onPressed: () =>
                                  _confirmDelete(context, cat.id, l),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: state.categories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, ClipCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCategorySheet(category: cat, state: state),
    );
  }

  void _confirmDelete(BuildContext context, String id, AppL10n l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.t('confirm_delete')),
        content: Text(l.t('confirm_delete_sub')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              state.removeCategory(id);
              Navigator.pop(ctx);
            },
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD CATEGORY DIALOG
// ─────────────────────────────────────────────

class AddCategoryDialog extends StatefulWidget {
  final ClipsState state;

  const AddCategoryDialog({super.key, required this.state});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameCtrl = TextEditingController();
  Color _color = const Color(0xFF4F8EF7);
  IconData _icon = Icons.folder_rounded;
  bool _userPickedIcon = false;

  static const _colors = categoryColorChoices;

  static const _icons = categoryIconChoices;

  Future<bool?> _confirmSimilarCategory(
    String typedName,
    ClipCategory suggested,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Catégorie similaire détectée'),
        content: Text(
          'Vous voulez dire "${suggested.name}" au lieu de "$typedName" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Garder mon nom'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Utiliser ${suggested.name}'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategory() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final near = widget.state.findBestCategoryMatch(name);
    if (near != null && near.name.toLowerCase().trim() != name.toLowerCase()) {
      final useExisting = await _confirmSimilarCategory(name, near);
      if (!mounted || useExisting == null) return;
      if (useExisting) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    await widget.state.addCategory(ClipCategory(
      id: const Uuid().v4(),
      name: name,
      color: _color,
      icon: _icon,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      if (!_userPickedIcon) {
        final suggested = suggestIconForCategoryName(_nameCtrl.text);
        if (suggested != _icon) setState(() => _icon = suggested);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.t('new_category')),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.t('category_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Text(l.t('color'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _colors
                    .map((c) => GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: _color == c
                                  ? [
                                      BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(l.t('icon'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons
                    .map((ic) => GestureDetector(
                          onTap: () => setState(() {
                            _icon = ic;
                            _userPickedIcon = true;
                          }),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _icon == ic
                                  ? _color.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _icon == ic
                                    ? _color
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              ic,
                              size: 20,
                              color: _icon == ic ? _color : Colors.grey,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.t('cancel'))),
        FilledButton(
          onPressed: _saveCategory,
          child: Text(l.t('save')),
        ),
      ],
    );
  }
}

