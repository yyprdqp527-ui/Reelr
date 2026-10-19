import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../app.dart';
import '../core/category_visuals.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/clip.dart';
import '../services/classifier.dart';
import '../services/database.dart';
import '../services/oembed.dart';
import '../services/playlist_link.dart';
import '../services/playlist_link_shortener.dart';
import '../services/claude_service.dart';
import '../state/clips_state.dart';
import '../widgets/background.dart';
import '../widgets/coach_mark.dart';
import '../widgets/glass_card.dart';
import '../widgets/offer_subcategory_move.dart';
import '../widgets/reelr_loader.dart';
import '../widgets/resilient_thumbnail.dart';
import '../widgets/search_query_card.dart';
import '../widgets/sheet_field.dart';
import '../widgets/site_logo.dart';
import '../widgets/thumbnail_fallback.dart';
import 'categories_screen.dart';
import 'onboarding_screen.dart';
import 'playlist_share_select_screen.dart';

// ─────────────────────────────────────────────
// ONBOARDING COACH MARKS — clés persistantes partagées
// ─────────────────────────────────────────────
//
// Mémorisation indépendante de la langue (clés techniques), persistante
// après fermeture de l'app, réutilisant le pattern SharedPreferences déjà
// en place ailleurs dans le projet (ex. reorder_hint_seen).

const String _kOnboardingReorderTilesKey = 'onboarding_reorder_category_tiles';
const String _kOnboardingAssignVideoKey =
    'onboarding_assign_video_to_subcategory';
const String _kOnboardingAssignVideoPendingKey =
    'onboarding_assign_video_to_subcategory_pending';
const String _kOnboardingSharePlaylistKey = 'onboarding_share_playlist';


/// Affiche (une seule fois) la bulle expliquant comment classer une vidéo
/// dans une sous-catégorie fraîchement créée, uniquement si un menu ⋯ de
/// vidéo est visible sur l'écran courant (anchorKey monté). Si aucun menu
/// n'est visible, ne fait rien : l'appel sera retenté automatiquement à la
/// prochaine ouverture d'un écran listant des vidéos, tant que le drapeau
/// "pending" reste actif (voir [_armAssignVideoHint]).
Future<void> _maybeShowAssignVideoHint(
    BuildContext context, AppL10n l, GlobalKey anchorKey) async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getBool(_kOnboardingAssignVideoPendingKey) ?? false;
  if (!pending) return;
  if (!context.mounted) return;
  // `pending` reste arme : la bulle peut disparaitre sans avoir ete vue
  // (changement de page) ; une fois vue, showOnce ne l'affiche plus.
  await CoachMark.showOnce(
    context: context,
    prefsKey: _kOnboardingAssignVideoKey,
    anchorKey: anchorKey,
    message: l.t('onboardingAssignVideoToSubcategory'),
    dismissLabel: l.t('onboardingGotIt'),
    preferredSide: CoachMarkSide.above,
  );
}

/// Arme l'affichage différé de la bulle ci-dessus — à appeler juste après
/// la création réussie d'une sous-catégorie (jamais si l'utilisateur annule).
/// N'a aucun effet si la bulle a déjà été vue, ce qui évite qu'elle ne soit
/// réarmée après chaque nouvelle création.
Future<void> _armAssignVideoHint() async {
  final prefs = await SharedPreferences.getInstance();
  final alreadySeen = prefs.getBool(_kOnboardingAssignVideoKey) ?? false;
  if (alreadySeen) return;
  await prefs.setBool(_kOnboardingAssignVideoPendingKey, true);
}

/// Première URL http(s) trouvée dans [text], ou `null` s'il n'y en a pas.
///
/// Le bouton « coller » exigeait auparavant que le lien soit au tout
/// début du presse-papier (`url.startsWith('http')`). Or TikTok,
/// Instagram et Facebook copient fréquemment une phrase avant l'URL :
/// le lien était bien présent, mais refusé.
String? firstHttpUrlIn(String text) {
  final match = RegExp(r'https?://\S+').firstMatch(text);
  if (match == null) return null;
  // Retire la ponctuation collée en fin de lien (fin de phrase,
  // parenthèse ou guillemet fermants).
  return match.group(0)!.replaceAll(RegExp(r'[)\]}>,.;!?"«»]+$'), '');
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final ClipsState state;

  final Future<void> Function(String url)? onPasteUrl;
  const HomeScreen({super.key, required this.state, this.onPasteUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final GlobalKey _categoryGridKey = GlobalKey();
  final GlobalKey _firstSearchClipMenuKey = GlobalKey();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Bulle "maintenez une tuile pour la réorganiser" — affichée une seule
  /// fois, uniquement lorsque la grille de catégories est visible et
  /// contient au moins 2 tuiles déplaçables (sans quoi le geste n'a pas
  /// de sens). Même filtre que celui utilisé par la grille elle-même pour
  /// déterminer les tuiles visibles (catégories non vides).
  Future<void> _maybeShowReorderTilesHint(AppL10n l) async {
    final visibleCategoryTiles = widget.state.categories.length;
    if (visibleCategoryTiles < 2) return;
    if (!mounted) return;
    await CoachMark.showOnce(
      context: context,
      prefsKey: _kOnboardingReorderTilesKey,
      anchorKey: _categoryGridKey,
      message: l.t('onboardingReorderCategoryTiles'),
      dismissLabel: l.t('onboardingGotIt'),
      preferredSide: CoachMarkSide.below,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final searching = widget.state.searchQuery.isNotEmpty;
        final suggestions = widget.state.searchSuggestions;
        final filtered = widget.state.clips;

        // Bulles d'aide contextuelles (une seule à la fois, une seule fois
        // chacune) : après le rendu de cette frame, tenter d'afficher la
        // bulle pertinente si son ancre est bien montée à l'écran.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!searching && widget.state.totalCount > 0) {
            _maybeShowReorderTilesHint(l);
          } else if (searching && filtered.isNotEmpty) {
            _maybeShowAssignVideoHint(context, l, _firstSearchClipMenuKey);
          }
        });

        final isDark = Theme.of(context).brightness == Brightness.dark;
        // Padding de fin de liste adapté à la SafeArea plutôt qu'une valeur
        // fixe pensée pour un seul iPhone — la barre de nav elle-même est
        // déjà entièrement dégagée par le padding du MainShell ; ceci ne
        // fait qu'ajouter une marge de respiration (échelle : 32) sous la
        // dernière rangée.
        final scrollBottomPad = 32 + MediaQuery.of(context).padding.bottom;
        return CustomScrollView(
          slivers: [
            _buildAppBar(l, widget.state.allClips),
            if (widget.state.totalCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  // Même marge gauche que la barre de recherche (16pt) pour
                  // un alignement constant sous le logo/les actions.
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    l.videosSaved(widget.state.totalCount),
                    style: AppTheme.homeCounterStyle.copyWith(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            if (widget.state.totalCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _searchCtrl,
                      hint: l.t('search'),
                      onChanged: widget.state.setSearch,
                    ),
                    if (searching && suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SuggestionsList(
                        suggestions: suggestions,
                        onTap: (s) {
                          _searchCtrl.text =
                              s.startsWith('#') ? s.substring(1) : s;
                          widget.state.setSearch(_searchCtrl.text);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.state.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.state.totalCount == 0)
              SliverFillRemaining(
                child: widget.state.isReceivingLinks
                    ? const _ArrivingState()
                    : _EmptyState(l: l, state: widget.state),
              )
            else if (searching)
              filtered.isEmpty
                  ? SliverFillRemaining(child: _EmptyState(l: l, state: widget.state))
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, scrollBottomPad),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipCard(
                                clip: filtered[i],
                                state: widget.state,
                                menuKey: i == 0 ? _firstSearchClipMenuKey : null),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    )
            else
              SliverPadding(
                // Même marge horizontale que la recherche/le compteur (20 → 16).
                padding: EdgeInsets.fromLTRB(16, 0, 16, scrollBottomPad),
                sliver: SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -16),
                    child: KeyedSubtree(
                      key: _categoryGridKey,
                      child: _ReorderableCategoryGrid(
                        state: widget.state,
                        l: l,
                        onOpenCategory: _openCategory,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openCategory(BuildContext context, String? categoryId, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryDetailScreen(
        state: widget.state,
        categoryId: categoryId,
        title: name,
      ),
    ));
  }

  SliverAppBar _buildAppBar(AppL10n l, List<Clip> clips) {
    // `backgroundColor: Colors.transparent` fait que Flutter estime la
    // luminosité de l'AppBar comme "sombre" (RGB à 0 malgré l'alpha nul) et
    // impose alors des icônes de barre de statut blanches par défaut, quel
    // que soit le thème — cet AppBar étant plus profond dans l'arbre que
    // l'AnnotatedRegion de MainShell, il l'emporte sur elle. On fixe donc
    // explicitement le style ici, aligné sur le thème actif.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      elevation: 0,
      // Réduit avec le logo (110 → 96) pour resserrer l'espace vertical
      // avant le compteur / la recherche.
      expandedHeight: 96,
      // Note : on n'utilise pas FlexibleSpaceBar.centerTitle ici — il centre
      // le titre entre `leading` et `actions`, et comme il n'y a qu'une icône
      // à droite (aucun leading), le résultat est visuellement décalé à
      // gauche. Un Stack pleine largeur centre le titre sur tout l'AppBar,
      // indépendamment de l'icône de droite.
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Logo net, sans glow ni flou derrière le texte — aucune
                  // décoration lumineuse localisée. Même dégradé qu'avant,
                  // taille agrandie (28 → 34pt) pour plus de présence.
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF2563EB), Color(0xFF22D3EE)],
                      stops: [0.0, 0.6, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      l.t('app_name'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                        letterSpacing: -1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: clips.isEmpty
          ? []
          : [
          if (widget.state.shoppingClips.isNotEmpty)
            HeaderActionButton(
              icon: Icons.shopping_bag_outlined,
              tooltip: Localizations.localeOf(context).languageCode == 'fr'
                  ? 'À acheter'
                  : 'To buy',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(
                  state: widget.state,
                  categoryId: null,
                  title: Localizations.localeOf(context).languageCode == 'fr'
                      ? 'À acheter'
                      : 'To buy',
                  toBuyOnly: true,
                ),
              )),
            ),
          HeaderActionButton(
            icon: Icons.add_link_rounded,
            tooltip: Localizations.localeOf(context).languageCode == 'fr'
                ? 'Coller un lien'
                : 'Paste a link',
            onPressed: () async {
              // UN SEUL acces au presse-papier, volontairement.
              //
              // Une version precedente appelait `Clipboard.hasStrings()`
              // avant `getData`, pour distinguer un presse-papier vide
              // d'un collage refuse. Mauvaise idee : cela produit deux
              // acces consecutifs, donc potentiellement deux demandes
              // d'autorisation iOS a la suite. L'utilisateur en accordait
              // une, la seconde echouait, et le collage devenait
              // impossible — signale en test.
              //
              // On ne peut donc pas distinguer les deux causes. Le
              // message les couvre toutes les deux.
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final raw = data?.text?.trim() ?? '';
              // Ce bouton affichait « aucun lien valide » quelle que soit
              // la cause : presse-papier vide, texte sans lien, ou
              // onPasteUrl absent. Impossible de diagnostiquer quoi que
              // ce soit, ni pour l'utilisateur ni dans les logs.
              debugPrint(
                '[coller] presse-papier: '
                '${raw.isEmpty ? "VIDE ou COLLAGE REFUSE" : "${raw.length} caracteres"}'
                '${raw.isEmpty ? "" : ' | debut: "${raw.length > 80 ? raw.substring(0, 80) : raw}"'}',
              );
              final url = firstHttpUrlIn(raw);
              if (url != null && widget.onPasteUrl != null) {
                debugPrint('[coller] lien extrait: $url');
                await widget.onPasteUrl!(url);
                return;
              }
              if (!mounted) return;
              final fr = Localizations.localeOf(context).languageCode == 'fr';
              final String message;
              if (raw.isEmpty) {
                message = fr
                    ? "Rien à coller. Copie le lien de la vidéo, puis appuie sur « Autoriser le collage » si iOS le demande."
                    : 'Nothing to paste. Copy the video link, then tap "Allow Paste" if iOS asks.';
              } else if (url == null) {
                message = fr
                    ? 'Aucun lien trouvé dans le texte copié.'
                    : 'No link found in the copied text.';
              } else {
                message = fr
                    ? "Impossible d'ajouter ce lien pour le moment."
                    : "Can't add this link right now.";
              }
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            },
          ),
          const SizedBox(width: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HEADER ACTION BUTTON — style uniforme pour les actions du header
// (taille tactile, poids d'icône et couleur identiques quel que soit le
// thème ; réutilisable si une deuxième action rejoint un jour le header).
// ─────────────────────────────────────────────

class HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 44,
      height: 44,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isDark
              ? AppTheme.surfaceElevated.withValues(alpha: 0.55)
              : AppTheme.lightActionButtonFill,
          shape: CircleBorder(
            side: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightActionButtonBorder,
              width: 1,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightActionButtonIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY TILE (iOS-style big rounded square)
// ─────────────────────────────────────────────

class _ReorderableCategoryGrid extends StatefulWidget {
  final ClipsState state;
  final AppL10n l;
  final void Function(BuildContext, String?, String) onOpenCategory;
  const _ReorderableCategoryGrid({
    required this.state,
    required this.l,
    required this.onOpenCategory,
  });
  @override
  State<_ReorderableCategoryGrid> createState() => _ReorderableCategoryGridState();
}

class _ReorderableCategoryGridState extends State<_ReorderableCategoryGrid> {
  // Un seul DragTarget couvre toute la grille (voir build()) : la case
  // visée est calculée géométriquement (ligne/colonne sous le doigt),
  // jamais déduite de l'identité de la tuile qui s'y affiche à l'instant
  // T — élimine l'ambiguïté qui survenait quand l'ordre changeait en
  // cours de geste (la case sous le doigt gardait la bonne position même
  // si son contenu changeait).
  final GlobalKey _gridBoxKey = GlobalKey();
  List<ClipCategory>? _previewOrder;
  int? _previewIndex;

  /// Vrai si le doigt a effectivement deplace la tuile pendant le
  /// glissement en cours.
  ///
  /// C'est ce qui distingue les deux intentions derriere le meme appui
  /// long : bouger, c'est reordonner ; ne pas bouger, c'est vouloir agir
  /// sur la tuile elle-meme. On ne propose donc la suppression qu'au
  /// second cas, sans rien retirer au premier.
  ///
  /// Remplace une zone de corbeille en bas de l'ecran : trop basse pour
  /// le pouce, et visuellement lourde par-dessus la barre de navigation.
  bool _didReorderDuringDrag = false;

  /// Propose la suppression apres un appui long immobile.
  ///
  /// Ouvre directement la boite de confirmation, sans SnackBar
  /// intermediaire. La version precedente en affichait une, portant une
  /// action « Supprimer » : `theme.dart` ne definit aucun
  /// `snackBarTheme`, donc Flutter lui appliquait son apparence par
  /// defaut — un bandeau blanc etranger a la charte de l'application.
  ///
  /// La supprimer ne retire aucune securite : la boite de confirmation
  /// demande deja l'accord de l'utilisateur et annonce ce qu'il advient
  /// des videos de la categorie.
  void _offerDeleteAfterStaticPress(String categoryId) {
    if (!mounted) return;
    _confirmDeleteCategory(categoryId);
  }

  Future<void> _confirmDeleteCategory(String categoryId) async {
    final cat = widget.state.categoryById(categoryId);
    if (cat == null || !mounted) return;
    final l = widget.l;
    final name = l.localizeCategoryDisplay(cat.id, cat.name);
    final count = widget.state.countForCategory(cat.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('delete_category_confirm').replaceAll('{name}', name)),
        // Les clips ne sont jamais supprimés : `removeCategory` les repasse
        // simplement en « À trier ». On le dit, sinon le geste paraît
        // beaucoup plus destructeur qu'il ne l'est.
        content: Text(
          count == 0
              ? l.t('delete_category_empty')
              : l.t('delete_category_keeps_clips').replaceAll('{n}', '$count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.state.removeCategory(categoryId);
  }

  static const int _crossAxisCount = 3;
  static const double _spacing = 16;

  List<ClipCategory> _baseOrder() => widget.state.categories;

  /// Convertit une position globale (celle du doigt) en index de la
  /// catégorie visée (0-based, parmi les catégories visibles, la tuile
  /// "Tout" étant hors de cet espace d'index). `null` si la position ne
  /// correspond à aucune case mesurable.
  int? _indexFromGlobalPosition(Offset globalPosition) {
    final box = _gridBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      // ignore: avoid_print
      return null;
    }
    final local = box.globalToLocal(globalPosition);
    if (local.dx < 0 || local.dy < 0) return null;
    final tileWidth =
        (box.size.width - _spacing * (_crossAxisCount - 1)) / _crossAxisCount;
    if (tileWidth <= 0) return null;
    const tileHeight = 0.0; // recalculé ci-dessous (childAspectRatio: 1)
    final resolvedTileHeight = tileHeight == 0 ? tileWidth : tileHeight;
    final col = (local.dx / (tileWidth + _spacing))
        .floor()
        .clamp(0, _crossAxisCount - 1);
    final row = (local.dy / (resolvedTileHeight + _spacing)).floor();
    if (row < 0) return null;
    // Index "tous emplacements confondus" (0 = case de la tuile "Tout").
    final flatIndex = row * _crossAxisCount + col;
    // Espace d'index des catégories visibles uniquement (sans "Tout").
    final visibleCount = _baseOrder().length;
    return (flatIndex - 1).clamp(0, visibleCount);
  }

  void _updatePreview(Offset globalPosition, String draggedId) {
    final targetIndex = _indexFromGlobalPosition(globalPosition);
    // ignore: avoid_print
    if (targetIndex == null || targetIndex == _previewIndex) return;
    final base = List<ClipCategory>.of(_baseOrder());
    final fromIdx = base.indexWhere((c) => c.id == draggedId);
    if (fromIdx == -1) return;
    // Échange : seules la tuile déplacée et la tuile visée changent de
    // place, toutes les autres restent où elles sont.
    final toIdx = targetIndex.clamp(0, base.length - 1);
    final tmp = base[fromIdx];
    base[fromIdx] = base[toIdx];
    base[toIdx] = tmp;
    _didReorderDuringDrag = true;
    setState(() {
      _previewIndex = targetIndex;
      _previewOrder = base;
    });
  }

  void _resetPreview() {
    setState(() {
      _previewOrder = null;
      _previewIndex = null;
    });
  }

  /// Nombre de vignettes de la mosaique de la tuile « Tout ».
  static const int _allTileMosaicSize = 4;

  /// Les vignettes des videos les plus recemment enregistrees, pour la
  /// mosaique de la tuile « Tout ». Liste vide si moins de 4 disponibles.
  List<({String clipId, String url, String linkUrl})> _allTileMosaic() {
    final withThumb = widget.state.allClips
        .where((c) =>
            c.thumbnailUrl != null &&
            c.thumbnailUrl!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    if (withThumb.length < _allTileMosaicSize) return const [];
    return withThumb
        .take(_allTileMosaicSize)
        .map((c) => (
              clipId: c.id,
              url: OEmbedService.bestThumbnailUrl(c.url, c.thumbnailUrl) ??
                  c.thumbnailUrl!,
              linkUrl: c.url,
            ))
        .toList();
  }

  /// Moins de 4 vignettes : la tuile « Tout » montre au moins la dernière
  /// vidéo enregistrée (même s'il n'y en a qu'une).
  ({String clipId, String url, String linkUrl})? _allTileLatest() {
    final withThumb = widget.state.allClips
        .where((c) =>
            c.thumbnailUrl != null &&
            c.thumbnailUrl!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    if (withThumb.isEmpty) return null;
    final c = withThumb.first;
    return (
      clipId: c.id,
      url: OEmbedService.bestThumbnailUrl(c.url, c.thumbnailUrl) ?? c.thumbnailUrl!,
      linkUrl: c.url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final visibleCats = _previewOrder ?? _baseOrder();
    // ignore: avoid_print
    final total = visibleCats.length + 1; // +1 pour la tuile "Tout"

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) => _updatePreview(details.offset, details.data),
      onLeave: (_) => _resetPreview(),
      onAcceptWithDetails: (details) {
        final targetIndex =
            _indexFromGlobalPosition(details.offset) ?? _previewIndex;
        // ignore: avoid_print
        _resetPreview();
        if (targetIndex != null) {
          widget.state.reorderCategoryToIndex(details.data, targetIndex);
        } else {
          // ignore: avoid_print
        }
      },
      builder: (ctx, candidate, rejected) {
        return GridView.builder(
          key: _gridBoxKey,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
            // Échelle d'espacement commune (4/8/12/16/20/24/32) : 14 → 16.
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: 1,
          ),
          itemCount: total,
          // Sans ce callback, GridView.builder ne retrouve ses enfants que
          // par index de position, pas par clé stable. Or l'ordre change
          // pendant le glisser (_previewOrder), donc la tuile en cours de
          // déplacement peut se retrouver à un autre index que celui
          // attendu : Flutter détruit/recrée alors le mauvais widget en
          // plein geste, ce qui corrompt l'état interne du
          // LongPressDraggable en cours.
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            if (key.value == 'cat_tile_all') return 0;
            final id = key.value.replaceFirst('cat_drag_source_', '');
            final idx = visibleCats.indexWhere((c) => c.id == id);
            return idx == -1 ? null : idx + 1;
          },
          itemBuilder: (ctx, i) {
            if (i == 0) {
              // Tuile "Tout" : fixe, non déplaçable.
              final latest = _allTileLatest();
              return _CategoryTile(
                key: const ValueKey('cat_tile_all'),
                name: l.t('all'),
                color: AppTheme.orange,
                icon: Icons.grid_view_rounded,
                count: widget.state.totalCount,
                isPending: widget.state.hasPendingClassification,
                isAllTile: true,
                mosaicThumbs: _allTileMosaic(),
                thumbnailUrl: latest?.url,
                thumbnailClipId: latest?.clipId,
                thumbnailLinkUrl: latest?.linkUrl,
                onTap: () => widget.onOpenCategory(context, null, l.t('all')),
              );
            }
            final catIndex = i - 1;
            final cat = visibleCats[catIndex];
            final catClips = widget.state.clipsForCategory(cat.id);
            final localizedName = l.localizeCategoryDisplay(cat.id, cat.name);
            // Clip dont la miniature illustre la tuile : le premier, dans
            // l'ordre de la categorie, qui possede une vignette.
            final thumbClip = catClips.isEmpty
                ? null
                : sortClipsByOrder(catClips, widget.state.sortOrderFor(cat.id))
                    .where((c) =>
                        c.thumbnailUrl != null &&
                        c.thumbnailUrl!.isNotEmpty)
                    .firstOrNull;
            final tile = _CategoryTile(
              name: localizedName,
              color: cat.color,
              icon: DatabaseHelper.iconFor(cat.id) ?? cat.icon,
              count: widget.state.countForCategory(cat.id),
              onTap: () {
                widget.state.markCategoryViewed(cat.id);
                widget.onOpenCategory(context, cat.id, localizedName);
              },
              thumbnailUrl: thumbClip == null
                  ? null
                  : OEmbedService.bestThumbnailUrl(
                      thumbClip.url, thumbClip.thumbnailUrl),
              thumbnailClipId: thumbClip?.id,
              thumbnailLinkUrl: thumbClip?.url,
              showBadge:
                  widget.state.newlyClassifiedCategoryIds.contains(cat.id),
            );

            return LongPressDraggable<String>(
              key: ValueKey('cat_drag_source_${cat.id}'),
              data: cat.id,
              delay: const Duration(milliseconds: 350),
              feedback: Opacity(
                  opacity: 0.85,
                  child: SizedBox(width: 100, height: 100, child: tile)),
              childWhenDragging: Opacity(opacity: 0.3, child: tile),
              onDragStarted: () => _didReorderDuringDrag = false,
              // `onDraggableCanceled` ne fait que remettre l'aperçu à
              // zéro. Elle NE doit pas proposer la suppression : Flutter
              // déclenche `onDraggableCanceled` PUIS `onDragEnd` quand un
              // glissement se termine sans être accepté par une cible —
              // c'est-à-dire exactement le cas de l'appui long relâché
              // sur place. Les deux rappels affichaient donc chacun leur
              // message. Une seule voie, `onDragEnd`, qui elle est
              // toujours appelée.
              onDraggableCanceled: (_, _) => _resetPreview(),
              onDragEnd: (_) {
                _resetPreview();
                // Appui long relache sans avoir bouge : l'utilisateur
                // visait la tuile, pas sa position.
                if (!_didReorderDuringDrag) {
                  _offerDeleteAfterStaticPress(cat.id);
                }
              },
              child: tile,
            );
          },
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final String name;
  final Color color;
  final IconData? icon;
  final int count;
  final VoidCallback onTap;
  final bool isAdd;

  final String? thumbnailUrl;

  /// Id du clip dont la miniature illustre la tuile (stockage permanent).
  final String? thumbnailClipId;

  /// Adresse du lien de ce clip : sert au logo de secours si l'image echoue.
  final String? thumbnailLinkUrl;

  /// Mosaique 2x2 (tuile « Tout »). Utilisee a la place de [thumbnailUrl]
  /// quand elle contient exactement 4 vignettes.
  final List<({String clipId, String url, String linkUrl})> mosaicThumbs;
  final bool showBadge;
  final bool isPending;
  final bool isAllTile;

  const _CategoryTile({
    super.key,
    required this.name,
    required this.color,
    required this.count,
    required this.onTap,
    this.icon,
    this.isAdd = false,
    this.thumbnailUrl,
    this.thumbnailClipId,
    this.thumbnailLinkUrl,
    this.mosaicThumbs = const [],
    this.showBadge = false,
    this.isPending = false,
    this.isAllTile = false,
  });

  // ignore: unused_element
  factory _CategoryTile.add({
    required String label,
    required VoidCallback onTap,
  }) =>
      _CategoryTile(
        name: label,
        color: AppTheme.orange,
        icon: Icons.add_circle_outline_rounded,
        count: 0,
        onTap: onTap,
        isAdd: true,
      );

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);
    final tintColor = widget.color;
    // Accent de la tuile "Tout" : bleu foncé du logo en clair, violet en
    // sombre (inchangé). N'affecte que cette tuile.
    final allTileAccent =
        isDark ? AppTheme.lightBlue : AppTheme.allTileAccentLight;
    // Icône réellement enregistrée pour la catégorie (reflète un éventuel
    // changement fait par l'utilisateur dans l'onglet Catégories). Le
    // lookup par nom ne sert plus que de filet de secours si aucune icône
    // n'est définie.
    // Badge de catégorie : même DA dans les deux thèmes — carré opaque
    // coloré + pictogramme contrasté (au lieu de l'ancienne pastille noire
    // translucide, réservée jusqu'ici au mode sombre). En clair, certaines
    // catégories (jaune pâle, gris, vert clair…) utilisent une paire
    // fond/pictogramme dédiée pour rester lisibles ; les autres retombent
    // sur la couleur de catégorie elle-même avec un pictogramme blanc — même
    // logique en sombre, où la couleur de catégorie est déjà assez soutenue.
    // Icône de la tuile "Tout" : violet en sombre (identité d'origine,
    // cohérente avec la teinte plate violette), bleu de marque en clair
    // (lisible sur le fond bleu pastel dense de la tuile).

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0.0, _hover ? -4.0 : 0.0, 0.0)
            ..scaleByDouble(_hover ? 1.03 : 1.0, _hover ? 1.03 : 1.0, 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.categoryCardBorder(isDark),
              width: AppTheme.categoryCardBorderWidth,
            ),
            boxShadow: widget.isAllTile
                ? (isDark
                    ? AppTheme.categoryCardSelectedGlow(allTileAccent)
                    : [
                        BoxShadow(
                          color: allTileAccent.withValues(alpha: 0.10),
                          blurRadius: 8,
                        ),
                      ])
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: (widget.thumbnailUrl != null ||
                    widget.mosaicThumbs.length == 4)
                // ── Mode thumbnail : pas de BackdropFilter ──
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.mosaicThumbs.length == 4)
                        _ThumbnailMosaic(
                          thumbs: widget.mosaicThumbs,
                          fallbackColor: tintColor.withValues(alpha: 0.12),
                        )
                      else
                      ResilientThumbnail(
                        key: ValueKey('cat_thumb_${widget.name}'),
                        url: widget.thumbnailUrl,
                        cacheKeyId: widget.name,
                        persistId: widget.thumbnailClipId,
                        platformId: 'category_tile',
                        fit: BoxFit.cover,
                        // Jamais de case vide : logo du site de ce clip.
                        fallbackBuilder: (_) => widget.thumbnailLinkUrl == null
                            ? Container(color: tintColor.withValues(alpha: 0.12))
                            : ThumbnailFallback(
                                url: widget.thumbnailLinkUrl!,
                                compact: true,
                              ),
                      ),
                      // Overlay gradient en bas : transparent jusqu'à 40% de
                      // la hauteur, puis assombrissement progressif (deux
                      // paliers pour une courbe douce, sans barre nette)
                      // jusqu'au bord inférieur — pour garder titre/compteur
                      // lisibles quelle que soit la miniature. Sombre : noir
                      // pur inchangé. Clair : dégradé bleu nuit (mêmes stops,
                      // seules les couleurs changent) au lieu du noir/gris
                      // neutre, pour rester cohérent avec la palette claire.
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? const [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Color(0x99000000),
                                      Color(0xE0000000),
                                    ]
                                  : const [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Color.fromRGBO(15, 17, 38, 0.56),
                                      AppTheme.lightThumbnailOverlay,
                                    ],
                              stops: const [0.0, 0.40, 0.70, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Classement en cours : meme loader qu'en mode glass.
                      // La tuile « Tout » passe desormais en mode image
                      // (mosaique) et perdait son loader.
                      if (widget.isPending)
                        const Positioned.fill(
                          child: Center(child: ReelrLoader(size: 32)),
                        ),
                      if (!widget.isPending) ...[
                        Positioned(
                          left: 14, right: 8, bottom: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!widget.isAdd) ...[
                                Text(l.videosCount(widget.count),
                                    style: AppTheme.categoryCounterStyle.copyWith(
                                        color: Colors.white.withValues(alpha: 0.75))),
                                const SizedBox(height: 4),
                              ],
                              Text(widget.name.toUpperCase(),
                                textAlign: TextAlign.left,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.categoryTitleStyle.copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                      // Badge rouge si nouvellement classifiée
                      if (widget.showBadge)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  )
                // ── Mode glass card : BackdropFilter intact ──
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Stack(
                      children: [
                        Container(
                          // Pas de bordure ici : la carte n'a qu'une seule
                          // bordure, portée par l'AnimatedContainer parent
                          // (évite la double bordure colorée).
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            // Tuile "Tout" en sombre : même teinte plate à
                            // 12% qu'avant (inchangé). En clair : dégradé
                            // bleu pastel dédié (AppTheme.allTileGradientLight)
                            // au lieu d'un simple aplat.
                            color: widget.isAllTile
                                ? (isDark
                                    ? allTileAccent.withValues(alpha: 0.12)
                                    : null)
                                : isDark
                                    ? tintColor.withValues(alpha: 0.12)
                                    // Mode clair : carte opaque gris-bleu,
                                    // légèrement teintée par la couleur de
                                    // catégorie — jamais transparente sur le
                                    // fond bleu pastel.
                                    : Color.alphaBlend(
                                        tintColor.withValues(alpha: 0.16),
                                        AppTheme.lightSurfaceBase,
                                      ),
                            gradient: widget.isAllTile && !isDark
                                ? AppTheme.allTileGradientLight
                                : null,
                            // Ombre allégée en sombre (faible élévation) —
                            // recolorée en bleu-gris doux en clair.
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(
                                        alpha: _hover ? 0.18 : 0.12)
                                    : AppTheme.lightSoftShadow.withValues(
                                        alpha: _hover ? 0.22 : 0.14),
                                blurRadius: isDark
                                    ? (_hover ? 20 : 14)
                                    : (_hover ? 36 : 28),
                                offset: Offset(
                                    0, isDark ? (_hover ? 6 : 4) : (_hover ? 12 : 8)),
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: RadialGradient(
                                  center: const Alignment(-0.7, -0.8),
                                  radius: 0.9,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.55),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.isPending)
                          const Positioned.fill(
                            child: Center(child: ReelrLoader(size: 32)),
                          )
                        else ...[
                        Padding(
                          // Même marge interne que le mode miniature (8pt)
                          // pour des cartes uniformes dans les deux modes.
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!widget.isAdd) ...[
                                Text(
                                  l.videosCount(widget.count),
                                  style: AppTheme.categoryCounterStyle.copyWith(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : widget.isAllTile
                                            ? AppTheme.allTileSubtitleLight
                                            : AppTheme.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                widget.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                style: AppTheme.categoryTitleStyle.copyWith(
                                  // Tuile "Tout" en clair : bleu foncé
                                  // dédié, lisible sur le dégradé pastel.
                                  color: isDark
                                      ? Colors.white
                                      : widget.isAllTile
                                          ? AppTheme.allTileTitleLight
                                          : AppTheme.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}


/// Grille 2x2 de vignettes, separees par un filet fin.
class _ThumbnailMosaic extends StatelessWidget {
  final List<({String clipId, String url, String linkUrl})> thumbs;
  final Color fallbackColor;

  const _ThumbnailMosaic({required this.thumbs, required this.fallbackColor});

  /// Filet entre les cases : tres fin et clair. Un filet sombre, place
  /// pile a mi-hauteur, se confondait avec le debut du degrade sombre du
  /// bas de la tuile et se lisait comme une bande noire.
  static const double _gap = 1.0;

  Widget _cell(int i) {
    final t = thumbs[i];
    // SizedBox.expand : dans une Row, la hauteur transmise a la case est
    // lache. Sans lui, l'image prenait sa hauteur naturelle (16:9) et se
    // centrait, laissant une bande vide au milieu de la tuile au lieu de
    // remplir la case (BoxFit.cover n'agit que dans une boite imposee).
    return Expanded(
      child: SizedBox.expand(
        child: ResilientThumbnail(
        key: ValueKey('all_mosaic_${i}_${t.clipId}'),
        url: t.url,
        cacheKeyId: t.clipId,
        persistId: t.clipId,
        platformId: 'all_tile_mosaic',
        fit: BoxFit.cover,
        fallbackBuilder: (_) => t.linkUrl.isEmpty
            ? ColoredBox(color: fallbackColor)
            : ThumbnailFallback(url: t.linkUrl, compact: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Couleur des filets entre les cases.
      color: const Color(0x33FFFFFF),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [_cell(0), const SizedBox(width: _gap), _cell(1)],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              children: [_cell(2), const SizedBox(width: _gap), _cell(3)],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY DETAIL SCREEN
// ─────────────────────────────────────────────

class CategoryDetailScreen extends StatefulWidget {
  final ClipsState state;
  final String? categoryId;
  final String title;

  /// Panier « a acheter » : liste uniquement les liens commerciaux
  /// (pages web de produits), tous sujets confondus. Pas de videos.
  final bool toBuyOnly;

  const CategoryDetailScreen({
    super.key,
    required this.state,
    required this.categoryId,
    required this.title,
    this.toBuyOnly = false,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  static const String _reorderHintPrefKey = 'reorder_hint_seen';

  SortOrder _sortOrder = SortOrder.chronological;
  bool _gridView = false;
  final GlobalKey _firstClipMenuKey = GlobalKey();
  final GlobalKey _sharePlaylistKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.state.sortOrderFor(widget.categoryId);
    _gridView = widget.state.gridViewFor(widget.categoryId);
  }
  String? _selectedSubcategoryId;
  String? _selectedSubSubcategoryId;

  /// Panier : ne montre que les liens commerciaux (pages web de produits,
  /// `Clip.isShoppingLink`) de la tuile ouverte. Jamais de videos.
  bool _toBuyOnly = false;

  /// Affiche l'aide de première utilisation du tri manuel, une seule fois
  /// (mémorisée via SharedPreferences) : les vidéos se réordonnent
  /// directement au doigt, sans mode ni poignée dédiés — le nouvel ordre est
  /// persisté à chaque déplacement (voir [ClipsState.reorderClips]).
  Future<void> _maybeShowManualSortHint(AppL10n l) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_reorderHintPrefKey) ?? false;
    if (alreadySeen || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('reorder_hint')),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await prefs.setBool(_reorderHintPrefKey, true);
  }

  /// Génère le lien de playlist (voir [PlaylistLink]) et le partage via le
  /// mécanisme natif déjà utilisé pour le partage d'une vidéo unique.
  /// Aucun backend : la playlist entière est encodée dans l'URL.
  Future<void> _sharePlaylist(
      BuildContext context, String name, List<Clip> allClips) async {
    // Ancrage de la feuille de partage, mesuré AVANT d'ouvrir l'écran de
    // choix : au retour, l'écran est encore en pleine animation (décalé
    // hors de l'écran) et iOS refuse une position hors de la vue.
    final box = context.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    final screenRect = Offset.zero & screenSize;
    final measured = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final origin = (measured != null &&
            !measured.isEmpty &&
            screenRect.intersect(measured) == measured)
        ? measured
        : Rect.fromLTWH(0, 0, screenSize.width, screenSize.height / 2);

    // Choix des liens à envoyer (tout coché au départ).
    final clips = await Navigator.of(context).push<List<Clip>>(
      MaterialPageRoute(
        builder: (_) => PlaylistShareSelectScreen(name: name, clips: allClips),
      ),
    );
    if (clips == null || clips.isEmpty || !context.mounted) return;
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    final playlistLink = PlaylistLink.fromClips(name, clips);
    final link = await PlaylistLinkShortener.shorten(playlistLink);
    if (!context.mounted) return;

    final message = isFr
        ? 'Je te fais découvrir ma playlist « $name » sur Reelr :\n\n$link'
        : 'Check out my playlist "$name" on Reelr:\n\n$link';
    try {
      await Share.share(message, sharePositionOrigin: origin);
    } catch (e) {
      // Avant : échec silencieux, on revenait sur la liste sans rien.
      debugPrint('[share] erreur feuille de partage: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isFr
            ? "Le partage n'a pas pu s'ouvrir. Réessaie."
            : "Sharing couldn't open. Try again."),
      ));
    }
  }

  List<Clip> _sorted(List<Clip> src) => sortClipsByOrder(src, _sortOrder);

  PopupMenuItem<SortOrder> _sortItem(
      SortOrder order, IconData icon, String label) {
    return PopupMenuItem<SortOrder>(
      value: order,
      child: Row(children: [
        Icon(icon,
            size: 18,
            color: _sortOrder == order ? AppTheme.orange : null),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontWeight: _sortOrder == order
                    ? FontWeight.w700
                    : FontWeight.normal)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final raw = widget.toBuyOnly
            ? widget.state.shoppingClips
            : widget.categoryId == null
            ? List<Clip>.from(widget.state.allClips)
            : widget.state.clipsForCategory(widget.categoryId);
        final subcats = widget.state.getSubCategoriesFor(widget.categoryId);
        final subId = _selectedSubcategoryId;
        final subsubcats = widget.state.getSubSubCategoriesFor(subId);
        final subSubId = _selectedSubSubcategoryId;
        final filtered = subId == null
            ? raw
            : raw
                .where((c) =>
                    widget.state.subcategoryIdForClip(c.id) == subId)
                .where((c) =>
                    subSubId == null ||
                    widget.state.subsubcategoryIdForClip(c.id) == subSubId)
                .toList();
        final hasToBuy = raw.any((c) => c.isShoppingLink);
        final clips = _sorted(_toBuyOnly
            ? filtered.where((c) => c.isShoppingLink).toList()
            : filtered);
        final topPad =
            MediaQuery.of(context).padding.top + kToolbarHeight + 8;

        // Bulle "classer une vidéo dans une sous-catégorie" — tente de
        // s'afficher près du premier menu ⋯ visible, uniquement si elle a
        // été armée par une création de sous-catégorie (voir
        // _armAssignVideoHint) et jamais plus d'une fois.
        if (clips.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _maybeShowAssignVideoHint(context, l, _firstClipMenuKey);
          });
        }

        // Bulle "partage ta playlist avec tes amis" — une seule fois, dès
        // que le bouton de partage de playlist est visible (catégorie non
        // vide).
        if (widget.categoryId != null && raw.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            CoachMark.showOnce(
              context: context,
              prefsKey: _kOnboardingSharePlaylistKey,
              anchorKey: _sharePlaylistKey,
              message: l.t('onboardingSharePlaylist'),
              dismissLabel: l.t('onboardingGotIt'),
              preferredSide: CoachMarkSide.below,
            );
          });
        }

        return PopScope(
          canPop: _selectedSubcategoryId == null,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // Dans une sous-categorie : retour a la liste des
            // sous-categories, pas a l'accueil.
            setState(() {
              _selectedSubcategoryId = null;
              _selectedSubSubcategoryId = null;
            });
          },
          child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {
                if (_selectedSubcategoryId != null) {
                  setState(() {
                    _selectedSubcategoryId = null;
                    _selectedSubSubcategoryId = null;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              widget.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5),
            ),
            actions: [
              if (!widget.toBuyOnly && (hasToBuy || _toBuyOnly))
                IconButton(
                  icon: Icon(_toBuyOnly
                      ? Icons.shopping_bag_rounded
                      : Icons.shopping_bag_outlined),
                  tooltip: Localizations.localeOf(context).languageCode == 'fr'
                      ? (_toBuyOnly ? 'Tout afficher' : 'À acheter')
                      : (_toBuyOnly ? 'Show all' : 'To buy'),
                  onPressed: () => setState(() => _toBuyOnly = !_toBuyOnly),
                ),
              IconButton(
                icon: Icon(_gridView ? Icons.list_rounded : Icons.grid_view_rounded),
                tooltip: Localizations.localeOf(context).languageCode == 'fr'
                    ? (_gridView ? 'Vue liste' : 'Vue grille')
                    : (_gridView ? 'List view' : 'Grid view'),
                onPressed: () => setState(() {
                  _gridView = !_gridView;
                  widget.state.setGridViewFor(widget.categoryId, _gridView);
                }),
              ),
              // Menu tri
              PopupMenuButton<SortOrder>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: l.t('sort'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (order) {
                  setState(() {
                    _sortOrder = order;
                    widget.state.setSortOrderFor(widget.categoryId, order);
                  });
                  if (order == SortOrder.manual && clips.length >= 2) {
                    unawaited(_maybeShowManualSortHint(l));
                  }
                },
                itemBuilder: (_) => [
                  _sortItem(SortOrder.chronological,
                      Icons.access_time_rounded, l.t('sort_date_added')),
                  _sortItem(SortOrder.alphabetical,
                      Icons.sort_by_alpha_rounded, l.t('sort_alphabetical')),
                  _sortItem(
                      SortOrder.manual, Icons.drag_handle_rounded, l.t('sort_manual')),
                ],
              ),
              if (widget.categoryId != null && _selectedSubcategoryId == null) ...[
                // Même aspect que les autres actions de cette barre (grille,
                // manuel) : icône simple sans fond ni bordure — fonction
                // inchangée : créer une sous-catégorie. Masqué dès qu'une
                // sous-catégorie est sélectionnée (le "+" de la barre de
                // chips prend le relais pour créer une sous-sous-catégorie).
                IconButton(
                  // Icône pleine (et non "_outline", plus fine) pour
                  // correspondre visuellement au poids des 3 autres icônes
                  // de cette barre (grille, tri, partager).
                  icon: const Icon(Icons.add_circle_rounded),
                  tooltip: l.t('add_subcategory_tooltip'),
                  onPressed: () => _showAddSubcategoryDialog(context),
                ),
              ],
              if (widget.categoryId != null && filtered.isNotEmpty)
                IconButton(
                  key: _sharePlaylistKey,
                  icon: const Icon(Icons.share_rounded),
                  tooltip: l.t('sharePlaylist'),
                  // Même ordre que l'affichage ; si une sous-catégorie (ou
                  // sous-sous-catégorie) est ouverte, on ne propose que ses
                  // liens, sous son nom, et non toute la catégorie.
                  onPressed: () {
                    var shareName = widget.title;
                    if (subId != null) {
                      for (final sc in subcats) {
                        if (sc.id == subId) shareName = sc.name;
                      }
                      if (subSubId != null) {
                        for (final ss in subsubcats) {
                          if (ss.id == subSubId) shareName = ss.name;
                        }
                      }
                    }
                    unawaited(_sharePlaylist(
                        context, shareName, _sorted(filtered)));
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              GradientBackground(isDark: isDark),
              Column(
                children: [
                  SizedBox(height: topPad),
                  if (subcats.isNotEmpty)
                    _SubcategoryBar(
                      subcategories: subcats,
                      selectedId: _selectedSubcategoryId,
                      categoryColor: widget.categoryId != null
                          ? (widget.state.categoryById(widget.categoryId)?.color ??
                              AppTheme.orange)
                          : AppTheme.orange,
                      onSelect: (id) => setState(() {
                        _selectedSubcategoryId = id;
                        _selectedSubSubcategoryId = null;
                      }),
                      onDelete: (id) =>
                          widget.state.deleteSubCategory(id),
                      subsubcategories: subsubcats,
                      selectedSubSubId: _selectedSubSubcategoryId,
                      onSelectSubSub: (id) =>
                          setState(() => _selectedSubSubcategoryId = id),
                      onDeleteSubSub: (id) =>
                          widget.state.deleteSubSubCategory(id),
                      onAddSubSub: () =>
                          _showAddSubSubcategoryDialog(context),
                    ),
                  Expanded(
                    child: clips.isEmpty
                        ? (_selectedSubcategoryId != null
                            ? _SubcategoryEmptyState(l: l)
                            : (widget.categoryId != null
                                ? _CategoryEmptyState(l: l)
                                : (widget.state.isReceivingLinks
                                    ? const _ArrivingState()
                                    : _EmptyState(l: l, state: widget.state))))
                        : _sortOrder == SortOrder.manual && clips.length >= 2
                            ? ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 32),
                                itemCount: clips.length,
                                // Poignées par défaut : sur mobile, Flutter
                                // enveloppe alors chaque tuile entière dans
                                // un long-press-and-drag — l'utilisateur
                                // réordonne directement au doigt, sans mode
                                // ni poignée dédiés à afficher/masquer.
                                proxyDecorator: (child, index, animation) =>
                                    AnimatedBuilder(
                                  animation: animation,
                                  builder: (ctx, child) {
                                    final t = Curves.easeInOut
                                        .transform(animation.value);
                                    return Transform.scale(
                                      scale: lerpDouble(1.0, 1.03, t)!,
                                      child: Material(
                                        elevation: lerpDouble(0, 10, t)!,
                                        color: Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        shadowColor: Colors.black26,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: child,
                                ),
                                itemBuilder: (ctx, i) => Padding(
                                  key: ValueKey(clips[i].id),
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: Semantics(
                                    customSemanticsActions: {
                                      if (i > 0)
                                        CustomSemanticsAction(
                                            label: l.t('reorder_move_up')): () =>
                                            widget.state.reorderClips(
                                                clips, i, i - 1),
                                      if (i < clips.length - 1)
                                        CustomSemanticsAction(
                                            label: l.t('reorder_move_down')): () =>
                                            widget.state.reorderClips(
                                                clips, i, i + 1),
                                    },
                                    child: ClipCard(
                                        clip: clips[i],
                                        state: widget.state,
                                        currentCategoryId: widget.categoryId),
                                  ),
                                ),
                                onReorderItem: (oldIndex, newIndex) =>
                                    widget.state.reorderClips(
                                        clips, oldIndex, newIndex),
                              )
                            : _gridView
                                ? GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: clips.length,
                                    itemBuilder: (ctx, i) {
                                      final c = clips[i];
                                      return GestureDetector(
                                        onTap: () async {
                                          final uri = Uri.tryParse(c.url);
                                          if (uri != null && await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } else if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  Localizations.localeOf(ctx)
                                                              .languageCode ==
                                                          'fr'
                                                      ? "Impossible d'ouvrir ce lien"
                                                      : 'Could not open this link',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              c.thumbnailUrl != null
                                                  ? ResilientThumbnail(
                                                      key: ValueKey('recent_thumb_${c.id}'),
                                                      url: OEmbedService.bestThumbnailUrl(
                                                          c.url, c.thumbnailUrl),
                                                      cacheKeyId: c.id,
                                                      persistId: c.id,
                                                      platformId: c.platform,
                                                      fit: BoxFit.cover,
                                                      fallbackBuilder: (_) =>
                                                          ThumbnailFallback(url: c.url, title: c.title),
                                                    )
                                                  : ThumbnailFallback(url: c.url, title: c.title),
                                              const IgnorePointer(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter,
                                                      colors: [Colors.transparent, Color(0xCC000000)],
                                                      stops: [0.4, 1.0],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 8, right: 8, bottom: 8,
                                                child: Text(
                                                  c.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 32),
                                itemCount: clips.length,
                                itemBuilder: (ctx, i) {
                                  final clip = clips[i];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: Dismissible(
                                      key: Key(clip.id),
                                      direction:
                                          DismissDirection.endToStart,
                                      background: Container(
                                        alignment:
                                            Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                            right: 20),
                                        decoration: BoxDecoration(
                                          color: Colors.red
                                              .withValues(alpha: 0.8),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  16),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 28),
                                      ),
                                      confirmDismiss: (_) async {
                                        return await showDialog<bool>(
                                          context: ctx,
                                          builder: (dlgCtx) =>
                                              AlertDialog(
                                            shape:
                                                RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            title: Text(Localizations.localeOf(dlgCtx).languageCode == 'fr' ? 'Supprimer ce clip ?' : 'Delete this clip?'),
                                            content: Text(Localizations.localeOf(dlgCtx).languageCode == 'fr' ? 'Cette action est irréversible.' : 'This action cannot be undone.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        dlgCtx, false),
                                                child: Text(Localizations.localeOf(dlgCtx).languageCode == 'fr' ? 'Annuler' : 'Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        dlgCtx, true),
                                                style: FilledButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                      Colors.red,
                                                ),
                                                child: Text(Localizations.localeOf(dlgCtx).languageCode == 'fr' ? 'Supprimer' : 'Delete'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                            false;
                                      },
                                      onDismissed: (_) =>
                                          widget.state
                                              .removeClip(clip.id),
                                      child: ClipCard(
                                          clip: clip,
                                          state: widget.state,
                                          currentCategoryId: widget.categoryId,
                                          menuKey: i == 0 ? _firstClipMenuKey : null),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _showAddSubcategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    Color pickedColor = AppTheme.orange;
    const colors = categoryColorChoices;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Nouvelle sous-catégorie' : 'New subfolder'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: Localizations.localeOf(ctx).languageCode == 'fr' ? 'Nom' : 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Couleur' : 'Color',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: colors
                        .map((c) => GestureDetector(
                              onTap: () => setDlgState(() => pickedColor = c),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: pickedColor == c
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Annuler' : 'Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final newSub = SubCategory(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  categoryId: widget.categoryId!,
                  color: pickedColor,
                  icon: Icons.label_rounded,
                );
                await widget.state.addSubCategory(newSub);
                // Création réussie (et non une annulation) : arme la bulle
                // d'aide "classer une vidéo dans une sous-catégorie", qui ne
                // s'affichera qu'une fois, dès qu'un menu ⋯ sera visible.
                _armAssignVideoHint();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (context.mounted) {
                  await offerMoveMatchingClips(context, widget.state, newSub);
                }
              },
              child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Créer' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubSubcategoryDialog(BuildContext context) {
    final parentSubId = _selectedSubcategoryId;
    if (parentSubId == null) return;
    final nameCtrl = TextEditingController();
    Color pickedColor = AppTheme.orange;
    const colors = categoryColorChoices;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Nouveau sous-dossier' : 'New subfolder'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: Localizations.localeOf(ctx).languageCode == 'fr' ? 'Nom' : 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Couleur' : 'Color',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: colors
                        .map((c) => GestureDetector(
                              onTap: () => setDlgState(() => pickedColor = c),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: pickedColor == c
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Annuler' : 'Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.state.addSubSubCategory(SubSubCategory(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  subCategoryId: parentSubId,
                  color: pickedColor,
                  icon: Icons.label_rounded,
                ));
                Navigator.pop(ctx);
              },
              child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Créer' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUBCATEGORY BAR
// ─────────────────────────────────────────────

class _SubcategoryBar extends StatelessWidget {
  final List<SubCategory> subcategories;
  final String? selectedId;
  final Color categoryColor;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onDelete;
  final List<SubSubCategory> subsubcategories;
  final String? selectedSubSubId;
  final ValueChanged<String?> onSelectSubSub;
  final ValueChanged<String> onDeleteSubSub;
  final VoidCallback onAddSubSub;

  const _SubcategoryBar({
    required this.subcategories,
    required this.selectedId,
    required this.categoryColor,
    required this.onSelect,
    required this.onDelete,
    required this.subsubcategories,
    required this.selectedSubSubId,
    required this.onSelectSubSub,
    required this.onDeleteSubSub,
    required this.onAddSubSub,
  });

  @override
  Widget build(BuildContext context) {
    // Une sous-catégorie est sélectionnée : la barre bascule pour ne
    // montrer que celle-ci (repliable en retapant dessus), suivie de ses
    // propres sous-sous-catégories et d'un bouton "+" dédié.
    if (selectedId != null) {
      final match = subcategories.where((s) => s.id == selectedId);
      final subName = match.isEmpty ? '' : match.first.name;
      final subColor = match.isEmpty ? categoryColor : match.first.color;
      return SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _SubChip(
              label: subName,
              color: subColor,
              selected: true,
              onTap: () => onSelect(null),
            ),
            ...subsubcategories.map((sub) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onLongPress: () => _confirmDeleteSubSub(context, sub),
                    child: _SubChip(
                      label: sub.name,
                      color: sub.color,
                      selected: selectedSubSubId == sub.id,
                      onTap: () => onSelectSubSub(
                          selectedSubSubId == sub.id ? null : sub.id),
                    ),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _AddSubSubChip(color: subColor, onTap: onAddSubSub),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _SubChip(
            label: AppL10n.of(context).t('all'),
            color: categoryColor,
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...subcategories.map((sub) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onLongPress: () => _confirmDelete(context, sub),
                  child: _SubChip(
                    label: sub.name,
                    color: sub.color,
                    selected: selectedId == sub.id,
                    onTap: () => onSelect(sub.id),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SubCategory sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Supprimer la sous-catégorie ?' : 'Delete subfolder?'),
        content: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? '"${sub.name}" sera supprimée.' : '"${sub.name}" will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Annuler' : 'Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              onDelete(sub.id);
              Navigator.pop(ctx);
            },
            child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Supprimer' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubSub(BuildContext context, SubSubCategory sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Supprimer ce sous-dossier ?' : 'Delete this subfolder?'),
        content: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? '"${sub.name}" sera supprimée.' : '"${sub.name}" will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Annuler' : 'Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              onDeleteSubSub(sub.id);
              Navigator.pop(ctx);
            },
            child: Text(Localizations.localeOf(ctx).languageCode == 'fr' ? 'Supprimer' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddSubSubChip extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _AddSubSubChip({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppL10n.of(context).t('add_subsubcategory_tooltip'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.add_rounded, color: _legibleAccent(color), size: 18),
        ),
      ),
    );
  }
}

/// Certaines couleurs de catégorie (ex. jaunes pâles) sont trop
/// claires pour servir de couleur de texte/icône sur leur propre
/// fond teinté à 10% — on les assombrit légèrement pour rester
/// lisible, tout en gardant la couleur d'origine pour le fond et
/// la bordure de la puce.
Color _legibleAccent(Color base) {
  return ThemeData.estimateBrightnessForColor(base) == Brightness.light
      ? Color.alphaBlend(Colors.black.withValues(alpha: 0.45), base)
      : base;
}

class _SubChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SubChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _legibleAccent(color),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 250);
  late final AnimationController _beamController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    // Faisceau animé en continu (pas seulement au focus) — coût
    // CPU/GPU jugé acceptable, accepté comme compromis batterie.
    _beamController.repeat();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightSearchText;
    final hintColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightPlaceholder;
    final iconColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightSearchIcon;
    final surfaceColor = isDark ? AppTheme.surface : AppTheme.lightSearchSurface();
    // Bordure légèrement plus visible au focus — sans lueur ajoutée.
    // En clair : reste dans la famille bleu glacier (pas de violet ici).
    // NB : la valeur "clair non focus" ci-dessous est une couleur figée
    // (identique à l'ancienne valeur de AppTheme.lightBorder), volontairement
    // recopiée en dur plutôt que référencée depuis AppTheme.lightBorder —
    // cette dernière a été repensée pour le reste de l'app (nav bar, bouton
    // rond, etc.) et la barre de recherche doit rester strictement inchangée.
    const searchBarUnfocusedBorderLight = Color(0x470A0E1F);
    final borderColor = _focused
        ? (isDark
            ? AppTheme.lightBlue.withValues(alpha: 0.45)
            : AppTheme.lightBorderActive.withValues(alpha: 0.55))
        : (isDark ? AppTheme.darkBorder : searchBarUnfocusedBorderLight.withValues(alpha: 0.12));

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: isDark ? 0.55 : 0.70),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: borderColor, width: _focused ? 1.3 : 1.0),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          // Valeur figée (ancienne AppTheme.lightTextPrimary) :
                          // la barre de recherche doit rester strictement
                          // inchangée, indépendamment de la nouvelle palette.
                          color: const Color(0xFF0A0E1F).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: (v) {
                // Le bouton "effacer" (visibilité) réagit tout de suite ;
                // la recherche elle-même est différée de ~250ms pour éviter
                // de rescanner toute la bibliothèque à chaque lettre tapée.
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(_debounceDuration, () {
                  widget.onChanged(v);
                });
              },
              style: AppTheme.searchTextStyle.copyWith(color: textColor),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                // Neutralise explicitement tous les états de bordure (pas
                // seulement `border`) : sinon `enabledBorder`/`focusedBorder`
                // du thème global (AppTheme.inputDecorationTheme) prennent
                // le dessus et dessinent un second cadre à l'intérieur de
                // celui du conteneur de la barre de recherche.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTheme.searchTextStyle.copyWith(color: hintColor),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, size: 20, color: hintColor),
              onPressed: () {
                // Effacement instantané : on court-circuite le délai.
                _debounce?.cancel();
                widget.controller.clear();
                widget.onChanged('');
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              splashRadius: 20,
            ),
            ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: 1.0,
                  child: AnimatedBuilder(
                    animation: _beamController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _SearchBeamPainter(progress: _beamController.value),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBeamPainter extends CustomPainter {
  final double progress;
  _SearchBeamPainter({required this.progress});

  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF22D3EE),
    Color(0xFF2563EB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        colors: _colors,
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(2 * math.pi * progress),
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SearchBeamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionsList({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: suggestions
            .map((s) => InkWell(
                  onTap: () => onTap(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          s.startsWith('#')
                              ? Icons.tag_rounded
                              : Icons.history_rounded,
                          size: 16,
                          color: isDark ? Colors.grey : AppTheme.lightIconSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Accueil pendant qu'un premier lien arrive : remplace l'état vide, qui
/// serait faux (et clignotait) avant l'apparition du clip. L'état vide ne
/// revient que si rien n'arrive (ou si l'ajout est refusé).
class _ArrivingState extends StatelessWidget {
  const _ArrivingState();

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppTheme.lightTextSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 14),
          Text(
            isFr ? 'Reelr range ton lien…' : 'Reelr is filing your link…',
            style: TextStyle(color: color, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// État vide de l'accueil : jamais d'écran vide. Invite à commencer et
/// réexplique en 3 étapes comment ajouter un lien, avec un accès direct
/// au tutoriel.
class _EmptyState extends StatelessWidget {
  final AppL10n l;
  final ClipsState state;
  const _EmptyState({required this.l, required this.state});

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : AppTheme.lightTextSecondary;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.lightBorder.withValues(alpha: 0.6);
    const accent = Color(0xFFA855F7);
    final steps = isFr
        ? const [
            'Ouvre une vidéo ou une page dans TikTok, Instagram, YouTube, Safari…',
            'Appuie sur Partager, puis choisis Reelr.',
            'Reelr range le lien tout seul dans la bonne catégorie.',
          ]
        : const [
            'Open a video or page in TikTok, Instagram, YouTube, Safari…',
            'Tap Share, then choose Reelr.',
            'Reelr files the link in the right category for you.',
          ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bookmark_add_rounded,
                        size: 30, color: accent),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isFr ? 'COMMENCE ICI' : 'START HERE',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isFr
                        ? 'Ta bibliothèque est vide\npour l\'instant'
                        : 'Your library is empty\nfor now',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.18),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: subColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnboardingScreen(state: state),
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded,
                        color: accent),
                    label: Text(
                      isFr ? 'Revoir le tutoriel' : 'Watch the tutorial again',
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubcategoryEmptyState extends StatelessWidget {
  final AppL10n l;
  const _SubcategoryEmptyState({required this.l});

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subColor = isDark ? Colors.white.withValues(alpha: 0.5) : AppTheme.lightTextSecondary;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : AppTheme.lightBorder.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.checklist_rounded, size: 30, color: Color(0xFFA855F7)),
              ),
              const SizedBox(height: 18),
              Text(
                isFr ? 'ORGANISE TES CLIPS' : 'ORGANIZE YOUR CLIPS',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Color(0xFFA855F7),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFr ? 'Cette liste est vide\npour l\'instant' : 'This list is empty\nfor now',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                isFr
                    ? 'Va dans l\'onglet Tout, appuie sur le menu ⋮ d\'un clip,\npuis choisis Classer pour l\'ajouter ici'
                    : 'Go to the All tab, tap the ⋮ menu on a clip,\nthen choose Sort to add it here',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: subColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _CategoryEmptyState extends StatelessWidget {
  final AppL10n l;
  const _CategoryEmptyState({required this.l});
  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subColor = isDark ? Colors.white.withValues(alpha: 0.5) : AppTheme.lightTextSecondary;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : AppTheme.lightBorder.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.drive_file_move_rounded, size: 30, color: Color(0xFFA855F7)),
              ),
              const SizedBox(height: 18),
              Text(
                isFr ? 'ORGANISE TES CLIPS' : 'ORGANIZE YOUR CLIPS',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Color(0xFFA855F7),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFr ? 'Cette catégorie est vide\npour l\'instant' : 'This category is empty\nfor now',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                isFr
                    ? 'Ouvre le menu ⋮ d\'une vidéo, appuie sur\nDéplacer vers, puis choisis cette catégorie'
                    : 'Open a video\'s ⋮ menu, tap\nMove to, then choose this category',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: subColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Retourne le chemin de l'asset PNG du logo pour [platformId], si un logo
/// dédié existe (voir assets/icons/). Sinon, retourne null : il faut alors
/// utiliser l'icône Material générique de la plateforme en fallback.
String? _platformLogoAsset(String platformId) {
  const availableLogos = {
    'facebook', 'instagram', 'twitch', 'pinterest', 'reddit', 'tiktok', 'youtube',
    'linkedin',
  };
  return availableLogos.contains(platformId)
      ? 'assets/icons/$platformId.png'
      : null;
}

class _ThumbnailBanner extends StatelessWidget {
  final String? thumbUrl;
  final SocialPlatform platform;
  final String clipId;
  final String linkUrl;
  final String title;

  const _ThumbnailBanner({
    required this.title,
    required this.thumbUrl,
    required this.platform,
    required this.clipId,
    required this.linkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: thumbUrl != null
            ? ResilientThumbnail(
                key: ValueKey('card_thumb_$clipId'),
                url: thumbUrl,
                cacheKeyId: clipId,
                persistId: clipId,
                platformId: platform.id,
                fit: BoxFit.cover,
                // Loader
                loadingBuilder: (_) => _fallback(shimmer: true),
                // Erreur → icône plateforme (uniquement si aucune miniature
                // valide n'a jamais été chargée avec succès pour ce clip)
                fallbackBuilder: (_) => _searchCardOr(
                    () => _fallback(context: context, isError: true)),
              )
            : _searchCardOr(
                () => _fallback(context: context, isError: true)),
      ),
    );
  }

  /// Recherche Google dont la capture a echoue : la requete en carte.
  Widget _searchCardOr(Widget Function() other) {
    final q = SearchQueryCard.queryFor(linkUrl);
    if (q != null) return SearchQueryCard(query: q);
    if (platform.id == 'other' && title.trim().isNotEmpty) {
      return LinkFallbackCard(
        url: linkUrl,
        title: title,
        logoFallback: Icon(platform.icon,
            color: Colors.white.withValues(alpha: 0.7), size: 40),
      );
    }
    return other();
  }

  Widget _fallback({bool shimmer = false, bool isError = false, BuildContext? context}) {
    final showInfoBadge = isError &&
        !shimmer &&
        context != null &&
        platform.id != 'youtube';
    return Container(
      color: platform.color.withValues(alpha: 0.12),
      child: Stack(
        children: [
          shimmer
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Center(
                  child: _platformLogoAsset(platform.id) != null
                      ? Image.asset(
                          _platformLogoAsset(platform.id)!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        )
                      : SiteLogo(url: linkUrl, size: 48, fallback: Icon(
                          platform.icon,
                          color: platform.color.withValues(alpha: 0.6),
                          size: 48,
                        )),
                ),
          if (showInfoBadge)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: () => _showThumbnailInfo(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          AppL10n.of(context).t('thumbnail_unavailable_title'),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showThumbnailInfo(BuildContext context) {
    final l = AppL10n.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0E1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('thumbnail_unavailable_title'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.t('thumbnail_unavailable_body'),
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLIP CARD
// ─────────────────────────────────────────────

/// Adresse a utiliser pour AFFICHER la carte : pour un lien Google Images
/// (google.com/imgres), la page d'origine (imgrefurl). Sinon, l'adresse
/// du clip. N'est jamais enregistree.
String _displayUrlFor(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final isGoogle = uri.host == 'google.com' || uri.host.endsWith('.google.com') ||
      RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(uri.host);
  if (isGoogle && uri.path == '/imgres') {
    final ref = uri.queryParameters['imgrefurl'];
    if (ref != null && (Uri.tryParse(ref)?.hasAuthority ?? false)) return ref;
  }
  return url;
}

class ClipCard extends StatelessWidget {
  final Clip clip;
  final ClipsState state;
  final String? currentCategoryId;
  // Ancre optionnelle pour la bulle d'aide "classer une vidéo dans une
  // sous-catégorie" — n'est fournie que pour le tout premier ClipCard visible
  // d'un écran ; sans effet visuel ou fonctionnel sur les autres cartes.
  final GlobalKey? menuKey;

  const ClipCard({
    super.key,
    required this.clip,
    required this.state,
    this.currentCategoryId,
    this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayUrl = _displayUrlFor(clip.url);
    final platform = SocialPlatform.detect(displayUrl);
    final category = state.categoryById(clip.categoryId);
    final lang = Localizations.localeOf(context).languageCode;
    final thumbUrl =
        OEmbedService.bestThumbnailUrl(clip.url, clip.thumbnailUrl);
    final isPendingClassification =
        category == null && state.isClassificationPending(clip);

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _openUrl(context, clip.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Miniature 16:9 ──────────────────────────────────────────
          _ThumbnailBanner(title: clip.title, thumbUrl: thumbUrl, platform: platform, clipId: clip.id, linkUrl: displayUrl),
          // ── Infos principales ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo réseau social
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: platform.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _platformLogoAsset(platform.id) != null
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            _platformLogoAsset(platform.id)!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Center(child: SiteLogo(url: displayUrl, size: 26, fallback: Icon(platform.icon, color: platform.color, size: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.35,
                          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: platform.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            platform.name,
                            style: TextStyle(
                              color: platform.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat.yMMMd(lang).format(clip.addedAt),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.withValues(alpha: 0.65)
                                  : AppTheme.lightTextTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: menuKey,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark
                        ? Colors.grey.withValues(alpha: 0.7)
                        : AppTheme.lightIconInactive,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'move',
                        child: _MenuItem(
                            icon: Icons.drive_file_move_rounded,
                            label: l.t('move_to_category'))),
                    PopupMenuItem(
                        value: 'share',
                        child: _MenuItem(
                            icon: Icons.send_rounded, label: l.t('share'))),
                    PopupMenuItem(
                        value: 'delete',
                        child: _MenuItem(
                            icon: Icons.delete_rounded,
                            label: l.t('delete'),
                            danger: true)),
                  ],
                  onSelected: (v) => _handleAction(context, v, l),
                ),
              ],
            ),
          ),
          // ── Badges catégorie + tags ──────────────────────────────────
          // La rangée est désormais toujours présente : sans catégorie et
          // sans classement en cours, la puce « À trier » prend le relais.
          // Auparavant l'emplacement restait vide, et rien n'indiquait à
          // l'utilisateur que la vidéo n'avait pas pu être classée.
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (category != null)
                    _Badge(
                      label: AppL10n.of(context).localizeCategoryDisplay(category.id, category.name),
                      color: category.color,
                      icon: category.icon,
                    ),
                  if (isPendingClassification)
                    _Badge(
                      label: lang == 'fr' ? 'Classification en cours…' : 'Classifying…',
                      color: isDark ? Colors.grey : AppTheme.lightTextTertiary,
                      icon: Icons.hourglass_top_rounded,
                    ),
                  // Classement terminé sans résultat exploitable : on le
                  // dit, et on offre le raccourci pour y remédier en un
                  // appui plutôt que par le menu contextuel.
                  if (category == null && !isPendingClassification)
                    Tooltip(
                      message: l.t('to_sort_hint'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _handleAction(context, 'move', l),
                        child: _Badge(
                          label: l.t('to_sort'),
                          // `_Badge` assombrit lui-même la teinte en mode
                          // clair via `_legibleAccent` : la même couleur
                          // reste lisible sur les deux thèmes.
                          color: _toSortAccent,
                          icon: Icons.label_off_rounded,
                        ),
                      ),
                    ),
                  // Pastille « X ou Y ? » : les deux hypotheses gardees quand
                  // Claude a hesite. Un appui range le lien (et l'apprend).
                  if (category == null &&
                      !isPendingClassification &&
                      clip.candidates.length >= 2)
                    ...clip.candidates.take(2).map((id) => InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => state.assignCandidateCategory(clip, id),
                          child: _Badge(
                            label:
                                '${l.localizeCategoryDisplay(id, state.candidateName(id))} ?',
                            color: AppL10n.categoryColors[id] ?? _toSortAccent,
                            icon: AppL10n.categoryIcons[id] ??
                                Icons.help_outline_rounded,
                          ),
                        )),
                  ...clip.tags.map((t) => _Badge(
                        label: '#$t',
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'fr'
                ? "Impossible d'ouvrir ce lien"
                : 'Could not open this link',
          ),
        ),
      );
    }
  }

  void _handleAction(BuildContext context, String action, AppL10n l) {
    switch (action) {
      case 'edit':
        if (currentCategoryId != null) {
        final subs = state.getSubCategoriesFor(currentCategoryId);
        final currentSubId = state.subcategoryIdForClip(clip.id);
        final currentSubSubId = state.subsubcategoryIdForClip(clip.id);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => _SubcategoryAssignSheet(
            categoryId: currentCategoryId!,
            clipId: clip.id,
            state: state,
            subcategories: subs,
            currentSubId: currentSubId,
            currentSubSubId: currentSubSubId,
          ),
        );
        return;
      }
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditClipSheet(clip: clip, state: state),
        );
        return;
      case 'share':
        final box = context.findRenderObject() as RenderBox?;
        final screenSize = MediaQuery.of(context).size;
        final origin = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromLTWH(0, 0, screenSize.width, screenSize.height / 2);
        Share.share(
          _shareText(clip),
          sharePositionOrigin: origin,
        );
        return;
      case 'move':
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => _MoveToCategorySheet(
            clip: clip,
            state: state,
          ),
        );
        return;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(l.t('confirm_delete')),
            content: Text(l.t('confirm_delete_sub')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.t('cancel')),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  state.removeClip(clip.id);
                  Navigator.pop(ctx);
                },
                child: Text(l.t('delete')),
              ),
            ],
          ),
        );
    }
  }
}


class _MoveToCategorySheet extends StatefulWidget {
  final Clip clip;
  final ClipsState state;
  const _MoveToCategorySheet({required this.clip, required this.state});
  @override
  State<_MoveToCategorySheet> createState() => _MoveToCategorySheetState();
}
class _MoveToCategorySheetState extends State<_MoveToCategorySheet> {
  late Clip _clip = widget.clip;

  /// Appui long sur une categorie : propose de la supprimer. Les videos ne
  /// sont jamais supprimees, elles repassent en « A trier ».
  Future<void> _confirmDeleteCategory(ClipCategory cat) async {
    final l = AppL10n.of(context);
    final name = l.localizeCategoryDisplay(cat.id, cat.name);
    final count = widget.state.countForCategory(cat.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('delete_category_confirm').replaceAll('{name}', name)),
        content: Text(
          count == 0
              ? l.t('delete_category_empty')
              : l.t('delete_category_keeps_clips').replaceAll('{n}', '$count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.state.removeCategory(cat.id);
    if (!mounted) return;
    setState(() {
      if (_clip.categoryId == cat.id) {
        _clip = _clip.copyWith(categoryId: null);
      }
    });
  }

  /// Appui long sur une sous-categorie ou un sous-dossier : confirmation,
  /// puis suppression. Les videos ne sont jamais supprimees.
  Future<void> _confirmDeleteSub({
    required String title,
    required String name,
    required Future<void> Function() onYes,
  }) async {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(fr ? '"$name" sera supprimée.' : '"$name" will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(fr ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(fr ? 'Supprimer' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await onYes();
    if (mounted) setState(() {});
  }

  Widget _tile({
    required double width,
    required IconData icon,
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    String? caption,
  }) {
    // Toutes les tuiles ont la meme hauteur : un titre long reduit sa
    // police au lieu d'agrandir la tuile.
    final labelSize = label.length > 22 ? 9.0 : (label.length > 14 ? 10.0 : 11.0);
    final height = caption != null ? 92.0 : 80.0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.35 : 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            SizedBox(
              height: labelSize * 2.5,
              child: Center(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: labelSize,
                      height: 1.15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (caption != null)
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final categories = List<ClipCategory>.from(widget.state.categories)
      ..sort((a, b) => a.name.compareTo(b.name));
    // Toutes les sous-catégories de toutes les catégories, d'un coup.
    final subs = <SubCategory>[
      for (final c in categories) ...widget.state.getSubCategoriesFor(c.id),
    ];
    final currentSubId = widget.state.subcategoryIdForClip(_clip.id);
    final currentSubSubId = widget.state.subsubcategoryIdForClip(_clip.id);
    final subsubs = widget.state.getSubSubCategoriesFor(currentSubId);
    const gap = 8.0;
    return ConstrainedBox(
      // Jamais plus haut que 88 % de l'ecran : le haut reste touchable pour
      // fermer la feuille, meme avec beaucoup de categories.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: SingleChildScrollView(
        child: LayoutBuilder(builder: (ctx, box) {
          final w = (box.maxWidth - gap * 3) / 4;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fr ? 'Catégorie' : 'Category',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                fr
                    ? 'Appui long sur une catégorie, une sous-catégorie ou un sous-dossier pour le supprimer.'
                    : 'Long-press a category, subfolder or sub-subfolder to delete it.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: categories.map((cat) {
                  return _tile(
                    width: w,
                    icon: cat.icon,
                    label: AppL10n.of(context)
                        .localizeCategoryDisplay(cat.id, cat.name),
                    color: cat.color,
                    selected: cat.id == _clip.categoryId,
                    onLongPress: () => _confirmDeleteCategory(cat),
                    onTap: () async {
                      if (cat.id == _clip.categoryId) {
                        Navigator.pop(ctx);
                        return;
                      }
                      final before = _clip;
                      final updated = before.copyWith(categoryId: cat.id);
                      await widget.state.updateClip(updated);
                      // L'ordre est libre : `upsertClip` ne touche pas aux
                      // colonnes classification_*, le journal est intact.
                      await widget.state
                          .recordUserCategoryChoice(before, cat.id);
                      // L'ancienne sous-catégorie appartenait à l'ancienne
                      // catégorie : on la vide.
                      await widget.state.setClipSubcategory(_clip.id, null);
                      await widget.state.setClipSubSubcategory(_clip.id, null);
                      if (!ctx.mounted) return;
                      // Choix fait : on ferme la feuille d'un seul geste.
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                fr ? 'Sous-catégorie' : 'Subcategory',
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (subs.isEmpty)
                Text(
                  fr ? 'Aucune sous-catégorie créée' : 'No subcategory created',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                )
              else
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: subs.map((sc) {
                    return _tile(
                      width: w,
                      icon: sc.icon,
                      label: sc.name,
                      caption: AppL10n.of(context).localizeCategoryDisplay(
                          sc.categoryId,
                          categories
                              .firstWhere((c) => c.id == sc.categoryId)
                              .name),
                      color: sc.color,
                      selected: sc.id == currentSubId,
                      onLongPress: () => _confirmDeleteSub(
                        title: fr
                            ? 'Supprimer la sous-catégorie ?'
                            : 'Delete subfolder?',
                        name: sc.name,
                        onYes: () => widget.state.deleteSubCategory(sc.id),
                      ),
                      onTap: () async {
                        if (sc.categoryId != _clip.categoryId) {
                          final before = _clip;
                          final updated =
                              before.copyWith(categoryId: sc.categoryId);
                          await widget.state.updateClip(updated);
                          await widget.state
                              .recordUserCategoryChoice(before, sc.categoryId);
                          _clip = updated;
                        }
                        await widget.state.setClipSubcategory(_clip.id, sc.id);
                        await widget.state.recordUserSubcategoryChoice(_clip.id, sc.id);
                        await widget.state.setClipSubSubcategory(_clip.id, null);
                        if (!ctx.mounted) return;
                        // S'il y a des sous-dossiers, on les propose ;
                        // sinon le rangement est terminé.
                        if (widget.state.getSubSubCategoriesFor(sc.id).isEmpty) {
                          Navigator.pop(ctx);
                        } else {
                          setState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),
              if (subsubs.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  fr ? 'Sous-dossier' : 'Subfolder',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: subsubs.map((ss) {
                    return _tile(
                      width: w,
                      icon: ss.icon,
                      label: ss.name,
                      color: ss.color,
                      selected: ss.id == currentSubSubId,
                      onLongPress: () => _confirmDeleteSub(
                        title: fr
                            ? 'Supprimer ce sous-dossier ?'
                            : 'Delete this subfolder?',
                        name: ss.name,
                        onYes: () => widget.state.deleteSubSubCategory(ss.id),
                      ),
                      onTap: () async {
                        await widget.state.setClipSubcategory(_clip.id, currentSubId);
                        await widget.state.setClipSubSubcategory(_clip.id, ss.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        }),
      ),
      ),
    );
  }
}
class _SubcategoryAssignSheet extends StatelessWidget {
  final String categoryId;
  final String clipId;
  final ClipsState state;
  final List<SubCategory> subcategories;
  final String? currentSubId;
  final String? currentSubSubId;

  const _SubcategoryAssignSheet({
    required this.categoryId,
    required this.clipId,
    required this.state,
    required this.subcategories,
    required this.currentSubId,
    required this.currentSubSubId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : AppTheme.lightElevatedSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Classer dans...' : 'Add to...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (subcategories.isEmpty)
              Center(
                child: Text(
                  Localizations.localeOf(context).languageCode == 'fr' ? 'Aucun dossier — crée-en un depuis la vue catégorie' : 'No folder — create one from the category view',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? Colors.grey.withValues(alpha: 0.6) : AppTheme.lightTextTertiary,
                      fontSize: 13),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () {
                          state.setClipSubcategory(clipId, null);
                          state.setClipSubSubcategory(clipId, null);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: currentSubId == null
                                ? (isDark ? Colors.grey : AppTheme.lightIconInactive)
                                : (isDark ? Colors.grey.withValues(alpha: 0.1) : AppTheme.lightSurfaceSecondary),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isDark ? Colors.grey.withValues(alpha: 0.4) : AppTheme.lightBorder),
                          ),
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'fr' ? 'Aucun' : 'None',
                            style: TextStyle(
                              color: currentSubId == null
                                  ? Colors.white
                                  : (isDark ? Colors.grey : AppTheme.lightTextSecondary),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...subcategories.map((s) {
                    final subsubs = state.getSubSubCategoriesFor(s.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              state.setClipSubcategory(clipId, s.id);
                              state.recordUserSubcategoryChoice(clipId, s.id);
                              state.setClipSubSubcategory(clipId, null);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: currentSubId == s.id && currentSubSubId == null
                                    ? s.color
                                    : s.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: s.color.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(s.icon,
                                      size: 14,
                                      color: currentSubId == s.id && currentSubSubId == null
                                          ? Colors.white
                                          : s.color),
                                  const SizedBox(width: 6),
                                  Text(s.name,
                                      style: TextStyle(
                                          color: currentSubId == s.id && currentSubSubId == null
                                              ? Colors.white
                                              : s.color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                          if (subsubs.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Wrap(
                                spacing: 6, runSpacing: 6,
                                children: subsubs.map((ss) => GestureDetector(
                                      onTap: () {
                                        state.setClipSubcategory(clipId, s.id);
                                        state.recordUserSubcategoryChoice(clipId, s.id);
                                        state.setClipSubSubcategory(clipId, ss.id);
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: currentSubSubId == ss.id
                                              ? ss.color
                                              : ss.color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                              color: ss.color.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(ss.icon,
                                                size: 12,
                                                color: currentSubSubId == ss.id
                                                    ? Colors.white
                                                    : ss.color),
                                            const SizedBox(width: 5),
                                            Text(ss.name,
                                                style: TextStyle(
                                                    color: currentSubSubId == ss.id
                                                        ? Colors.white
                                                        : ss.color,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    )).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuItem(
      {required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

/// Teinte de la puce « À trier ».
///
/// Ambre plutôt que gris : le gris est déjà pris par « Classification en
/// cours… », et les deux états se confondraient. L'ambre signale qu'il
/// manque quelque chose sans crier à l'erreur — la classification n'a pas
/// échoué, c'est le titre de la vidéo qui ne dit rien.
///
/// Une seule valeur pour les deux thèmes : `_Badge` l'assombrit en mode
/// clair via `_legibleAccent`, comme pour les couleurs de catégorie.
const Color _toSortAccent = Color(0xFFF0A020);

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    // En mode clair, certaines couleurs de catégorie/tag (jaune pâle, gris,
    // vert clair…) sont trop peu contrastées utilisées telles quelles comme
    // couleur de texte/icône sur le fond bleu pastel — on les assombrit
    // légèrement via `_legibleAccent` (même logique que `_CatChip`), tout
    // en gardant le fond/la bordure teintés dans la couleur d'origine.
    // Mode sombre : inchangé.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark ? color : _legibleAccent(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: displayColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: displayColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD CLIP SHEET
// ─────────────────────────────────────────────

class AddClipSheet extends StatefulWidget {
  final ClipsState state;
  final String? initialUrl;

  const AddClipSheet({super.key, required this.state, this.initialUrl});

  @override
  State<AddClipSheet> createState() => _AddClipSheetState();
}

class _AddClipSheetState extends State<AddClipSheet> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _newCategoryCtrl = TextEditingController();
  bool _showNewCategoryField = false;
  bool _isProposeInProgress = false;
  String? _selectedCategoryId;
  SocialPlatform? _detectedPlatform;
  bool _isFetchingTitle = false;
  String? _thumbnailUrl;
  bool _wasAutoSuggested = false;
  // ignore: unused_field
  String? _urlError;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlCtrl.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onUrlChanged(widget.initialUrl!);
      });
    } else {
      _tryPaste();
    }
  }

  String _extractSignalFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (host.contains('instagram.com')) {
        if (segments.isNotEmpty) return 'instagram ${segments.first}';
        return 'instagram';
      }
      if (host.contains('facebook.com') || host.contains('fb.watch')) {
        if (segments.isNotEmpty) return 'facebook ${segments.first}';
        return 'facebook';
      }
      if (host.contains('twitch.tv')) {
        if (segments.isNotEmpty) return 'twitch ${segments.first}';
        return 'gaming twitch';
      }
      if (host.contains('tiktok.com')) {
        final user = segments.firstWhere((s) => s.startsWith('@'), orElse: () => '');
        return user.isNotEmpty ? 'tiktok $user' : 'tiktok';
      }
    } catch (_) {}
    return '';
  }

  bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _tryPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (_isValidHttpUrl(text)) {
      _urlCtrl.text = text;
      _onUrlChanged(text);
    }
  }

  Future<void> _onUrlChanged(String url) async {
    if (!_isValidHttpUrl(url)) return;
    final generation = ++_fetchGeneration;
    final platform = SocialPlatform.detect(url);
    setState(() {
      _detectedPlatform = platform;
      _isFetchingTitle = true;
      _urlError = null;
    });
    final meta = await OEmbedService.fetchMetadata(url);
    if (!mounted || generation != _fetchGeneration) {
      if (mounted) setState(() => _isFetchingTitle = false);
      return;
    }
    final fetchedTitle = meta?.title ?? '';
    setState(() {
      _isFetchingTitle = false;
      _thumbnailUrl = meta?.thumbnailUrl;
      if (fetchedTitle.isNotEmpty && _titleCtrl.text.isEmpty) {
        _titleCtrl.text = fetchedTitle;
      }
    });
    // Twitch sans credentials → forcer Gaming directement
    if (url.toLowerCase().contains('twitch.tv') && _selectedCategoryId == null) {
      final signal = _extractSignalFromUrl(url);
      await _proposeCategory('gaming streaming twitch $signal');
      return;
    }
    final classifySignal = fetchedTitle.isNotEmpty ? fetchedTitle : _extractSignalFromUrl(url);
    if (classifySignal.isNotEmpty && _selectedCategoryId == null) {
      await _proposeCategory(classifySignal);
    }
  }

  /// Affiche la popup IA de confirmation de catégorie.
  Future<void> _proposeCategory(String title) async {
    if (_isProposeInProgress) return;
    _isProposeInProgress = true;
    try {
      final suggestion = CategoryClassifier.suggestDetailed(title);
      // IA sans catégorie reconnue → appel Claude comme fallback.
      if (suggestion.isUnclassified) {
        final claudeResult = await ClaudeService.classifyTitle(
          title: title,
          categoryNames: widget.state.categories.map((c) => c.name).toList(),
          platform: _detectedPlatform?.id,

        );
        if (!mounted) return;
        if (claudeResult != null && claudeResult.isNotEmpty) {
          final existing = widget.state.categories.firstWhere(
            (c) => c.name.toLowerCase() == claudeResult.toLowerCase(),
            orElse: () => ClipCategory(id: '__new__', name: claudeResult, color: const Color(0xFF7C3AED), icon: Icons.folder_outlined),
          );
          final cat = existing.id == '__new__' ? await widget.state.addCategory(existing) : existing;
          if (!mounted) return;
          setState(() { _selectedCategoryId = cat.id; _wasAutoSuggested = true; });
          if (mounted) await _submit();
          return;
        }
        setState(() => _showNewCategoryField = true);
        return;
      }
      final existingId = CategoryClassifier.matchExisting(
          suggestion, widget.state.categories);
      final result = await showDialog<Object?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CategorySuggestionDialog(
          suggestion: suggestion,
          hasExisting: existingId != null,
        ),
      );
      if (!mounted) return;
      if (result == true) {
        // "Ajouter dans [Catégorie]"
        await _applySuggestion(suggestion, existingId);
        if (mounted) await _submit();
      } else if (result == false) {
        // "Ajouter sans catégorie"
        setState(() {
          _selectedCategoryId = null;
          _wasAutoSuggested = false;
        });
        if (mounted) await _submit();
      } else if (result is String && result.isNotEmpty) {
        // Catégorie saisie manuellement
        final newCat = ClipCategory(
          id: const Uuid().v4(),
          name: result,
          color: const Color(0xFF7C3AED),
          icon: Icons.folder_outlined,
        );
        await widget.state.addCategory(newCat);
        if (!mounted) return;
        setState(() {
          _selectedCategoryId = newCat.id;
          _wasAutoSuggested = false;
        });
        if (mounted) await _submit();
      }
      // result == null → dialog fermé sans choix, on laisse la sheet ouverte
    } finally {
      if (mounted) setState(() => _isProposeInProgress = false);
    }
  }

  Future<void> _applySuggestion(
      CategorySuggestion s, String? existingId) async {
    if (s.isUnclassified) {
      setState(() {
        _selectedCategoryId = null;
        _wasAutoSuggested = false;
      });
      return;
    }
    if (existingId != null) {
      setState(() {
        _selectedCategoryId = existingId;
        _wasAutoSuggested = true;
      });
      return;
    }
    // Nouvelle catégorie automatique → création à la volée.
    final newCat = ClipCategory(
      id: s.aiCategoryId,
      name: s.name,
      color: s.color,
      icon: s.icon,
    );
    await widget.state.addCategory(newCat);
    if (!mounted) return;
    setState(() {
      _selectedCategoryId = newCat.id;
      _wasAutoSuggested = true;
    });
  }

  Future<void> _submit() async {
    final rawUrl = _urlCtrl.text.trim();
    final lang = Localizations.localeOf(context).languageCode;
    if (!_isValidHttpUrl(rawUrl)) {
      setState(() => _urlError = lang == 'fr'
          ? 'URL invalide. Vérifiez que le lien commence par http:// ou https://.'
          : 'Invalid URL. Make sure the link starts with http:// or https://.');
      return;
    }
    final l = AppL10n.of(context);
    final app = ClipsApp.of(context);

    // Ce formulaire appelait `addClip` directement : ni resolution des
    // liens courts, ni garde-fou sur les URLs sans contenu, ni increment
    // du compteur a vie. Un lien pin.it, share.google ou un wrapper
    // TikTok colle a la main ne beneficiait d'aucune des resolutions
    // existantes, et la limite gratuite etait contournable.
    final parsed = Uri.tryParse(rawUrl);
    final url = parsed != null
        ? (await OEmbedService.resolveShortLinkForDedup(parsed)).toString()
        : rawUrl;
    if (!mounted) return;

    if (OEmbedService.isContentlessUrl(url)) {
      setState(() => _urlError = lang == 'fr'
          ? "Ce lien ne pointe pas vers une vidéo précise. Ouvre la vidéo, puis copie son lien."
          : "This link doesn't point to a specific video. Open the video, then copy its link.");
      return;
    }
    if (widget.state.isDuplicate(url)) {
      setState(() => _urlError = lang == 'fr'
          ? 'Ce lien est déjà dans votre liste.'
          : 'This link is already in your list.');
      return;
    }
    // Le paywall s'affiche depuis ClipsAppState : on referme la feuille
    // pour ne pas le laisser apparaitre derriere elle.
    if (app != null && !app.canAddClip()) {
      Navigator.pop(context);
      return;
    }
    setState(() => _urlError = null);
    final tags = _tagsCtrl.text.trim().isEmpty
        ? <String>[]
        : _tagsCtrl.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
    // Si l'utilisateur a saisi une nouvelle catégorie, la créer maintenant.
    String? categoryId = _selectedCategoryId;
    final newCatName = _newCategoryCtrl.text.trim();
    if (_showNewCategoryField && newCatName.isNotEmpty) {
      final newCat = ClipCategory(
        id: const Uuid().v4(),
        name: newCatName,
        color: const Color(0xFF7C3AED),
        icon: Icons.folder_outlined,
      );
      await widget.state.addCategory(newCat);
      if (!mounted) return;
      categoryId = newCat.id;
    }
    final clip = Clip(
      id: const Uuid().v4(),
      url: url,
      title: _titleCtrl.text.trim().isEmpty
          ? l.t('no_title')
          : _titleCtrl.text.trim(),
      // `_detectedPlatform` a ete calcule pendant la saisie, donc sur
      // l'URL brute. Si la resolution l'a changee (pin.it -> pinterest,
      // share.google -> tiktok), c'est l'URL resolue qui fait foi.
      platform: (url == rawUrl
              ? (_detectedPlatform ?? SocialPlatform.detect(url))
              : SocialPlatform.detect(url))
          .id,
      categoryId: categoryId,
      tags: tags,
      addedAt: DateTime.now(),
      thumbnailUrl: _thumbnailUrl,
    );
    if (!await widget.state.addClip(clip)) {
      if (mounted) {
        setState(() => _urlError = lang == 'fr'
            ? 'Ce lien est déjà dans votre liste.'
            : 'This link is already in your list.');
      }
      return;
    }
    app?.registerClipAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

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
                  : AppTheme.lightElevatedSurface.withValues(alpha: 0.92),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppTheme.lightBorder.withValues(alpha: 0.7),
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
                      l.t('add_clip'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                      const SizedBox(height: 10),
                    Stack(
                      children: [
                        SheetField(
                          controller: _titleCtrl,
                          hint: l.t('title'),
                          icon: Icons.title_rounded,
                          isDark: isDark,
                        ),
                        if (_isFetchingTitle)
                          Positioned(
                            right: 14,
                            top: 14,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: scheme.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _showNewCategoryField
                              ? (Localizations.localeOf(context).languageCode == 'fr' ? 'Nouvelle catégorie' : 'New category')
                              : l.t('category'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (_wasAutoSuggested) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF6C63FF),
                                Color(0xFFFF6EC7),
                              ]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                    Localizations.localeOf(context)
                                                .languageCode ==
                                            'fr'
                                        ? 'IA'
                                        : 'AI',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_showNewCategoryField)
                      SheetField(
                        controller: _newCategoryCtrl,
                        hint: Localizations.localeOf(context).languageCode == 'fr' ? 'Dans quelle catégorie ?' : 'Which category?',
                        icon: Icons.folder_outlined,
                        isDark: isDark,
                      )
                    else
                      _CategoryPicker(
                        categories: widget.state.categories,
                        selected: _selectedCategoryId,
                        l: l,
                        onChanged: (id) => setState(() {
                          if (id == '__new__') {
                            _showNewCategoryField = true;
                          } else {
                            _selectedCategoryId = id;
                            _wasAutoSuggested = false;
                          }
                        }),
                      ),
                    if (_showNewCategoryField) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newCategoryCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: Localizations.localeOf(context).languageCode == 'fr' ? 'Nom de la catégorie' : 'Category name',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _showNewCategoryField = false),
                          ),
                        ),
                      ),
                    ],
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
                            child: Text(_showNewCategoryField ? 'Créer' : l.t('add')),
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


class _CategorySuggestionDialog extends StatefulWidget {
  final CategorySuggestion suggestion;
  final bool hasExisting;

  const _CategorySuggestionDialog({
    required this.suggestion,
    required this.hasExisting,
  });

  @override
  State<_CategorySuggestionDialog> createState() =>
      _CategorySuggestionDialogState();
}

class _CategorySuggestionDialogState
    extends State<_CategorySuggestionDialog> {
  bool _showCustom = false;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showCustom) ...[  
              Icon(s.icon, size: 40, color: s.color),
              const SizedBox(height: 12),
              Text(
                s.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                Localizations.localeOf(context).languageCode == 'fr' ? 'Cette vidéo ressemble à du \${s.name}' : 'This video looks like \${s.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade600 : AppTheme.lightTextTertiary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: s.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Ajouter dans \${s.name}' : 'Add to \${s.name}'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _showCustom = true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Autre catégorie' : 'Other category'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  Localizations.localeOf(context).languageCode == 'fr' ? 'Ajouter sans catégorie' : 'Add without category',
                  style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : AppTheme.lightTextTertiary,
                      fontSize: 13),
                ),
              ),
            ] else ...[  
              TextField(
                controller: _customCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: Localizations.localeOf(context).languageCode == 'fr' ? 'Nom de la catégorie...' : 'Category name...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onSubmitted: (v) {
                  final name = v.trim();
                  if (name.isNotEmpty) Navigator.pop(context, name);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _showCustom = false;
                        _customCtrl.clear();
                      }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Annuler' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final name = _customCtrl.text.trim();
                        if (name.isNotEmpty) Navigator.pop(context, name);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Créer' : 'Create'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final List<ClipCategory> categories;
  final String? selected;
  final AppL10n l;
  final ValueChanged<String?> onChanged;

  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.l,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CatChip(
          label: l.t('none'),
          color: isDark ? Colors.grey : AppTheme.lightIconInactive,
          icon: Icons.block_rounded,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        ...categories.map((cat) {
          final localizedName = l.localizeCategoryDisplay(cat.id, cat.name);
          final chipColor = !isDark
              ? (CategoryVisuals.lightBadgeBackground(localizedName) ?? cat.color)
              : cat.color;
          return _CatChip(
            label: localizedName,
            color: chipColor,
            icon: cat.icon,
            selected: selected == cat.id,
            onTap: () => onChanged(cat.id),
          );
        }),
        _CatChip(
          label: Localizations.localeOf(context).languageCode == 'fr' ? 'Créer' : 'Create',
          color: const Color(0xFF7C3AED),
          icon: Icons.add_rounded,
          selected: false,
          onTap: () => onChanged('__new__'),
        ),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : _legibleAccent(color)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _legibleAccent(color),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EDIT CLIP SHEET
// ─────────────────────────────────────────────

class EditClipSheet extends StatefulWidget {
  final Clip clip;
  final ClipsState state;

  const EditClipSheet({super.key, required this.clip, required this.state});

  @override
  State<EditClipSheet> createState() => _EditClipSheetState();
}

class _EditClipSheetState extends State<EditClipSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _newCategoryCtrl;
  late String? _selectedCategoryId;
  bool _showNewCategoryField = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.clip.title);
    _tagsCtrl = TextEditingController(text: widget.clip.tags.join(', '));
    _newCategoryCtrl = TextEditingController();
    _selectedCategoryId = widget.clip.categoryId;
  }

  Future<void> _submit() async {
    final l = AppL10n.of(context);
    final title = _titleCtrl.text.trim();
    final tags = _tagsCtrl.text.trim().isEmpty
        ? <String>[]
        : _tagsCtrl.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
    String? categoryId = _selectedCategoryId;
    if (_showNewCategoryField && _newCategoryCtrl.text.trim().isNotEmpty) {
      final newCat = ClipCategory(
        id: const Uuid().v4(),
        name: _newCategoryCtrl.text.trim(),
        color: const Color(0xFF7C3AED),
        icon: Icons.folder_outlined,
      );
      final created = await widget.state.addCategory(newCat);
      if (!mounted) return;
      categoryId = created.id;
    }
    // `updateClip` remplace la ligne entiere (insert + ConflictAlgorithm
    // .replace), il ne fusionne pas. Tout champ absent de ce constructeur est
    // donc ecrit a NULL en base, definitivement. Les parametres de `Clip`
    // etant nommes et optionnels, l'oubli ne provoque aucune erreur de
    // compilation : `channel` etait ainsi efface a chaque simple correction de
    // titre. Ajouter un champ a `Clip` impose de l'ajouter ici.
    //
    // Volontairement sans `copyWith` : sa semantique `valeur ?? ancienne`
    // empecherait de remettre `categoryId` a null, c'est-a-dire de sortir un
    // clip de sa categorie depuis _CategoryPicker.
    final updated = Clip(
      id: widget.clip.id,
      url: widget.clip.url,
      title: title.isEmpty ? l.t('no_title') : title,
      platform: widget.clip.platform,
      categoryId: categoryId,
      tags: tags,
      addedAt: widget.clip.addedAt,
      thumbnailUrl: widget.clip.thumbnailUrl,
      position: widget.clip.position,
      channel: widget.clip.channel,
      description: widget.clip.description,
    );
    await widget.state.updateClip(updated);
    await widget.state.recordUserCategoryChoice(widget.clip, categoryId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    _newCategoryCtrl.dispose();
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
                  : AppTheme.lightElevatedSurface.withValues(alpha: 0.92),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppTheme.lightBorder.withValues(alpha: 0.7),
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
                      l.t('edit_clip'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    SheetField(
                      controller: _titleCtrl,
                      hint: l.t('title'),
                      icon: Icons.title_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.t('category'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    _CategoryPicker(
                      categories: widget.state.categories,
                      selected: _selectedCategoryId,
                      l: l,
                      onChanged: (id) => setState(() {
                        if (id == '__new__') {
                          _showNewCategoryField = true;
                        } else {
                          _selectedCategoryId = id;
                        }
                      }),
                    ),
                    if (_showNewCategoryField) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newCategoryCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: Localizations.localeOf(context).languageCode == 'fr' ? 'Nom de la catégorie' : 'Category name',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _showNewCategoryField = false),
                          ),
                        ),
                      ),
                    ],
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


/// Texte envoye quand on partage un clip (SMS, WhatsApp...).
///
/// Le titre d'un clip Instagram, TikTok ou Pinterest est souvent la
/// legende COMPLETE de la publication (recette entiere, liste de hashtags,
/// plusieurs langues) : elle etait envoyee telle quelle et produisait des
/// messages interminables. On n'envoie plus que la premiere ligne, coupee
/// proprement a ~90 caracteres, suivie du lien. L'apercu riche (image,
/// titre) est de toute facon construit par l'app de messagerie a partir du
/// lien. Titre sans interet (« Instagram », « Reddit »...) : lien seul.
String _shareText(Clip clip) {
  const maxLength = 90;
  final firstLine = clip.title
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty || OEmbedService.isPlaceholderTitle(firstLine)) {
    return clip.url;
  }
  var title = firstLine;
  // Par caracteres visibles (emoji compris), pour ne jamais couper un
  // emoji en deux.
  if (title.characters.length > maxLength) {
    final cut = title.characters.take(maxLength).toString();
    final lastSpace = cut.lastIndexOf(' ');
    title = '${(lastSpace > 40 ? cut.substring(0, lastSpace) : cut).trimRight()}…';
  }
  return '$title\n${clip.url}';
}
