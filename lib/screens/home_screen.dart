import 'dart:ui';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/category_visuals.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/clip.dart';
import '../services/classifier.dart';
import '../services/database.dart';
import '../services/oembed.dart';
import '../services/claude_service.dart';
import '../state/clips_state.dart';
import '../widgets/background.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/glass_card.dart';
import '../widgets/sheet_field.dart';
import 'categories_screen.dart';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

        return CustomScrollView(
          slivers: [
            _buildAppBar(l, widget.state.allClips),
            if (widget.state.totalCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 4),
                  child: Text(
                    l.videosSaved(widget.state.totalCount),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w400,
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
              SliverFillRemaining(child: _EmptyState(l: l))
            else if (searching)
              filtered.isEmpty
                  ? SliverFillRemaining(child: _EmptyState(l: l))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipCard(
                                clip: filtered[i], state: widget.state),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                sliver: SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -16),
                    child: _ReorderableCategoryGrid(
                    state: widget.state,
                    l: l,
                    onOpenCategory: _openCategory,
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
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 110,
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Lueur douce derrière le texte pour un rendu plus premium.
                  Text(
                    l.t('app_name'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      letterSpacing: -1.2,
                      foreground: Paint()
                        ..color = const Color(0xFF7C3AED).withValues(alpha: 0.55)
                        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
                    ),
                  ),
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
                        fontSize: 32,
                        letterSpacing: -1.2,
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
      actions: [
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            tooltip: 'Coller un lien',
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final url = data?.text?.trim() ?? '';
              if (url.startsWith('http') && widget.onPasteUrl != null) {
                await widget.onPasteUrl!(url);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Aucun lien valide dans le presse-papier' : 'No valid link in clipboard')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
      ],
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
  int? _draggingIndex;
  int? _hoverIndex;
  List<ClipCategory>? _previewOrder;

  List<ClipCategory> _baseOrder() => widget.state.categories
      .where((c) => widget.state.countForCategory(c.id) > 0)
      .toList();

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final visibleCats = _previewOrder ?? _baseOrder();
    final total = visibleCats.length + 1; // +1 pour la tuile "Tout"

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1,
      ),
      itemCount: total,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          // Tuile "Tout" : fixe, non déplaçable.
          return _CategoryTile(
            name: l.t('all'),
            color: AppTheme.orange,
            icon: Icons.grid_view_rounded,
            count: widget.state.totalCount,
            isPending: widget.state.hasPendingClassification,
            isAllTile: true,
            onTap: () => widget.onOpenCategory(context, null, l.t('all')),
          );
        }
        final catIndex = i - 1;
        final cat = visibleCats[catIndex];
        final catClips = widget.state.clipsForCategory(cat.id);
        final localizedName = l.localizeCategoryDisplay(cat.id, cat.name);
        final isBeingDragged = _draggingIndex == catIndex;
        final tile = _CategoryTile(
          name: localizedName,
          color: cat.color,
          icon: DatabaseHelper.iconFor(cat.id) ?? cat.icon,
          count: widget.state.countForCategory(cat.id),
          onTap: () {
            widget.state.markCategoryViewed(cat.id);
            widget.onOpenCategory(context, cat.id, localizedName);
          },
          thumbnailUrl: catClips.isEmpty
              ? null
              : () {
                  final order = widget.state.sortOrderFor(cat.id);
                  final sorted = sortClipsByOrder(catClips, order);
                  return sorted
                      .where((c) =>
                          c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty)
                      .map((c) => c.thumbnailUrl!)
                      .firstOrNull;
                }(),
          showBadge: widget.state.newlyClassifiedCategoryIds.contains(cat.id),
        );

        return DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            final fromIndex = details.data;
            if (fromIndex == catIndex) return false;
            setState(() {
              _hoverIndex = catIndex;
              final base = List<ClipCategory>.of(_previewOrder ?? _baseOrder());
              if (fromIndex < 0 || fromIndex >= base.length) return;
              final moved = base.removeAt(fromIndex);
              base.insert(catIndex.clamp(0, base.length), moved);
              _previewOrder = base;
              _draggingIndex = catIndex;
            });
            return true;
          },
          onLeave: (_) => setState(() => _hoverIndex = null),
          onAcceptWithDetails: (details) {
            setState(() {
              _hoverIndex = null;
              _draggingIndex = null;
              _previewOrder = null;
            });
            widget.state.reorderCategories(details.data, catIndex);
          },
          builder: (ctx, candidate, rejected) {
            final isHovering = _hoverIndex == catIndex && candidate.isNotEmpty;
            return AnimatedOpacity(
              opacity: isBeingDragged ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedScale(
              scale: isHovering ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: LongPressDraggable<int>(
                data: catIndex,
                delay: const Duration(milliseconds: 350),
                feedback: Opacity(opacity: 0.85, child: SizedBox(width: 100, height: 100, child: tile)),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                onDragStarted: () => setState(() => _draggingIndex = catIndex),
                onDragEnd: (_) => setState(() {
                  _draggingIndex = null;
                  _hoverIndex = null;
                }),
                child: tile,
              ),
              ),
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
  final bool showBadge;
  final bool isPending;
  final bool isAllTile;

  const _CategoryTile({
    required this.name,
    required this.color,
    required this.count,
    required this.onTap,
    this.icon,
    this.isAdd = false,
    this.thumbnailUrl,
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
    // Icône et couleur de badge uniformisées (visuel uniquement — n'affecte
    // ni les données persistées ni la classification IA).
    final badgeIcon = CategoryVisuals.iconFor(
        widget.name, widget.icon ?? Icons.folder_outlined);
    final badgeColor = widget.isAllTile
        ? AppTheme.violet
        : CategoryVisuals.desaturate(tintColor);

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
              color: widget.isAllTile
                  ? AppTheme.violet
                  : AppTheme.categoryCardBorder(isDark),
              width: widget.isAllTile
                  ? AppTheme.categoryCardBorderWidthSelected
                  : AppTheme.categoryCardBorderWidth,
            ),
            boxShadow: widget.isAllTile ? AppTheme.categoryCardSelectedGlow : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: widget.thumbnailUrl != null
                // ── Mode thumbnail : pas de BackdropFilter ──
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: tintColor.withValues(alpha: 0.12),
                        ),
                      ),
                      // Overlay gradient sombre en bas : transparent sur la
                      // moitié supérieure, assombrissement progressif à
                      // partir de 45% de la hauteur, jusqu'à ~75% de noir
                      // au bord inférieur — pour garder titre/compteur
                      // lisibles quelle que soit la miniature.
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Color(0xBF000000),
                              ],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.isPending) ...[
                        Positioned(
                          top: 8,
                          left: 8,
                          child: CategoryIconBadge(
                            icon: badgeIcon,
                            color: badgeColor,
                          ),
                        ),
                        Positioned(
                          left: 8, right: 8, bottom: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.name,
                                textAlign: TextAlign.left,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.15, color: Colors.white)),
                              if (!widget.isAdd) ...[
                                const SizedBox(height: 2),
                                Text(l.videosCount(widget.count), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75))),
                              ],
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
                            color: tintColor.withValues(alpha: 0.12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.shadowGrey
                                    .withValues(
                                        alpha: _hover ? 0.22 : 0.14),
                                blurRadius: _hover ? 36 : 28,
                                offset: Offset(0, _hover ? 12 : 8),
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
                            child: Center(child: CupertinoActivityIndicator(radius: 16, color: Colors.white)),
                          )
                        else ...[
                        Positioned(
                          top: 8,
                          left: 8,
                          child: CategoryIconBadge(
                            icon: badgeIcon,
                            color: badgeColor,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spacer(),
                              Text(
                                widget.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  height: 1.15,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.darkGreen,
                                ),
                              ),
                              if (!widget.isAdd) ...[
                                const SizedBox(height: 2),
                                Text(
                                  l.videosCount(widget.count),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                            .withValues(alpha: 0.55)
                                        : AppTheme.darkGreen
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                              const Spacer(),
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


// ─────────────────────────────────────────────
// CATEGORY DETAIL SCREEN
// ─────────────────────────────────────────────

class CategoryDetailScreen extends StatefulWidget {
  final ClipsState state;
  final String? categoryId;
  final String title;

  const CategoryDetailScreen({
    super.key,
    required this.state,
    required this.categoryId,
    required this.title,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  SortOrder _sortOrder = SortOrder.chronological;
  bool _reorderMode = false;
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.state.sortOrderFor(widget.categoryId);
    _gridView = widget.state.gridViewFor(widget.categoryId);
  }
  String? _selectedSubcategoryId;

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
        final raw = widget.categoryId == null
            ? List<Clip>.from(widget.state.allClips)
            : widget.state.clipsForCategory(widget.categoryId);
        final subcats = widget.state.getSubCategoriesFor(widget.categoryId);
        final subId = _selectedSubcategoryId;
        final filtered = subId == null
            ? raw
            : raw
                .where((c) =>
                    widget.state.subcategoryIdForClip(c.id) == subId)
                .toList();
        final clips = _sorted(filtered);
        final topPad =
            MediaQuery.of(context).padding.top + kToolbarHeight + 8;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: Icon(_gridView ? Icons.list_rounded : Icons.grid_view_rounded),
                tooltip: _gridView ? 'Vue liste' : 'Vue grille',
                onPressed: () => setState(() {
                  _gridView = !_gridView;
                  widget.state.setGridViewFor(widget.categoryId, _gridView);
                }),
              ),
              // Menu tri
              PopupMenuButton<SortOrder>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Trier',
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (order) => setState(() {
                  _sortOrder = order;
                  if (order != SortOrder.manual) _reorderMode = false;
                  widget.state.setSortOrderFor(widget.categoryId, order);
                }),
                itemBuilder: (_) => [
                  _sortItem(SortOrder.chronological,
                      Icons.access_time_rounded, Localizations.localeOf(context).languageCode == 'fr' ? 'Chronologique' : 'Recent'),
                  _sortItem(SortOrder.alphabetical,
                      Icons.sort_by_alpha_rounded, Localizations.localeOf(context).languageCode == 'fr' ? 'Alphabétique' : 'A-Z'),
                  _sortItem(
                      SortOrder.manual, Icons.drag_handle_rounded, Localizations.localeOf(context).languageCode == 'fr' ? 'Manuel' : 'Manual'),
                ],
              ),
              // Toggle réorganiser (visible uniquement en mode Manuel)
              if (_sortOrder == SortOrder.manual)
                IconButton(
                  icon: Icon(_reorderMode
                      ? Icons.check_circle_rounded
                      : Icons.reorder_rounded),
                  tooltip: _reorderMode
                      ? (Localizations.localeOf(context).languageCode == 'fr' ? 'Terminé' : 'Done')
                      : (Localizations.localeOf(context).languageCode == 'fr' ? 'Réorganiser' : 'Reorder'),
                  onPressed: () =>
                      setState(() => _reorderMode = !_reorderMode),
                ),
              if (widget.categoryId != null) ...[  
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: Localizations.localeOf(context).languageCode == 'fr'
                      ? 'Ajouter une sous-catégorie'
                      : 'Add a subcategory',
                  onPressed: () => _showAddSubcategoryDialog(context),
                ),
              ],
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
                      onSelect: (id) =>
                          setState(() => _selectedSubcategoryId = id),
                      onDelete: (id) =>
                          widget.state.deleteSubCategory(id),
                    ),
                  Expanded(
                    child: clips.isEmpty
                        ? _EmptyState(l: l)
                        : _reorderMode
                            ? ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 32),
                                itemCount: clips.length,
                                buildDefaultDragHandles: false,
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
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipCard(
                                            clip: clips[i],
                                            state: widget.state,
                                            currentCategoryId: widget.categoryId),
                                      ),
                                      ReorderableDragStartListener(
                                        index: i,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 16),
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            color: Colors.grey
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onReorderItem: (oldIndex, newIndex) =>
                                    widget.state.reorderClips(
                                        widget.categoryId,
                                        oldIndex,
                                        newIndex),
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
                                                  ? CachedNetworkImage(
                                                      imageUrl: c.thumbnailUrl!,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, _, _) => Container(
                                                          color: AppTheme.orange.withValues(alpha: 0.2)),
                                                    )
                                                  : Container(color: AppTheme.orange.withValues(alpha: 0.2)),
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
                                          currentCategoryId: widget.categoryId),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ],
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
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.state.addSubCategory(SubCategory(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  categoryId: widget.categoryId!,
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

  const _SubcategoryBar({
    required this.subcategories,
    required this.selectedId,
    required this.categoryColor,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _SubChip(
            label: 'Tout',
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

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      blur: 16,
      child: TextField(
        controller: widget.controller,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionsList({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: suggestions
            .map((s) => InkWell(
                  onTap: () => onTap(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          s.startsWith('#')
                              ? Icons.tag_rounded
                              : Icons.history_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
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

class _EmptyState extends StatefulWidget {
  final AppL10n l;
  const _EmptyState({required this.l});
  @override
  State<_EmptyState> createState() => _EmptyStateState();
}
class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scroll;
  late final Animation<double> _shareAppear;
  late final Animation<double> _arrowBounce;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(period: const Duration(milliseconds: 4000));
    _scroll = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.45, curve: Curves.easeInOut));
    _shareAppear = CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 0.7, curve: Curves.elasticOut));
    _arrowBounce = CurvedAnimation(parent: _ctrl, curve: const Interval(0.72, 1.0, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.4);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 160,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(top: 0, child: _PhoneMockup(scrollProgress: _scroll.value, isDark: isDark)),
                    if (_shareAppear.value > 0)
                      Positioned(
                        bottom: 10, right: 40,
                        child: Transform.scale(
                          scale: _shareAppear.value,
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    if (_arrowBounce.value > 0)
                      Positioned(
                        bottom: 0, right: 48,
                        child: Transform.translate(
                          offset: Offset(0, 6 * (1 - _arrowBounce.value).abs()),
                          child: Opacity(opacity: _arrowBounce.value, child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF7C3AED), size: 20)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Tes vidéos préférées,\nenfin au même endroit' : 'Your favorite videos,\nall in one place', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3, color: textColor)),
            const SizedBox(height: 12),
            Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Va sur YouTube, Instagram ou TikTok\nappuie sur  ↑  puis choisis Reelr' : 'Go to YouTube, Instagram or TikTok\ntap  ↑  then choose Reelr', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.6, color: subColor)),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AppShortcut(label: 'YouTube', icon: Icons.play_circle_fill_rounded, color: const Color(0xFFFF0000), url: 'https://www.youtube.com'),
                const SizedBox(width: 16),
                _AppShortcut(label: 'TikTok', icon: Icons.music_note_rounded, color: const Color(0xFF010101), url: 'https://www.tiktok.com'),
                const SizedBox(width: 16),
                _AppShortcut(label: 'Instagram', icon: Icons.camera_alt_rounded, color: const Color(0xFFE1306C), url: 'https://www.instagram.com'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class _AppShortcut extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String url;
  const _AppShortcut({required this.label, required this.icon, required this.color, required this.url});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final double scrollProgress;
  final bool isDark;
  const _PhoneMockup({required this.scrollProgress, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    return Container(
      width: 110, height: 130,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned(
              top: -60 * scrollProgress + 8, left: 8, right: 8,
              child: Column(
                children: List.generate(4, (i) => Container(
                  height: 28, margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(6)),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ThumbnailBanner extends StatelessWidget {
  final String? thumbUrl;
  final SocialPlatform platform;

  const _ThumbnailBanner({required this.thumbUrl, required this.platform});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: thumbUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbUrl!,
                fit: BoxFit.cover,
                // Loader
                placeholder: (ctx, url) => _fallback(shimmer: true),
                // Erreur → icône plateforme
                errorWidget: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback({bool shimmer = false}) {
    return Container(
      color: platform.color.withValues(alpha: 0.12),
      child: shimmer
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Center(
              child: Icon(
                platform.icon,
                color: platform.color.withValues(alpha: 0.6),
                size: 48,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// CLIP CARD
// ─────────────────────────────────────────────

class ClipCard extends StatelessWidget {
  final Clip clip;
  final ClipsState state;
  final String? currentCategoryId;

  const ClipCard({super.key, required this.clip, required this.state, this.currentCategoryId});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final platform = SocialPlatform.detect(clip.url);
    final category = state.categoryById(clip.categoryId);
    final lang = Localizations.localeOf(context).languageCode;
    final thumbUrl =
        OEmbedService.bestThumbnailUrl(clip.url, clip.thumbnailUrl);
    final isPendingClassification = category == null &&
        DateTime.now().difference(clip.addedAt) < const Duration(seconds: 20);
    debugPrint('[badge] id=${clip.id} categoryId=${clip.categoryId} pending=$isPendingClassification elapsedMs=${DateTime.now().difference(clip.addedAt).inMilliseconds}');

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _openUrl(context, clip.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Miniature 16:9 ──────────────────────────────────────────
          _ThumbnailBanner(thumbUrl: thumbUrl, platform: platform),
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
                  child: Icon(platform.icon, color: platform.color, size: 20),
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
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? Colors.white
                              : AppTheme.darkGreen,
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
                              color: Colors.grey.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.grey.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: _MenuItem(
                            icon: Icons.edit_rounded, label: l.t('edit'))),
                    PopupMenuItem(
                        value: 'share',
                        child: _MenuItem(
                            icon: Icons.share_rounded, label: l.t('share'))),
                    PopupMenuItem(
                        value: 'open',
                        child: _MenuItem(
                            icon: Icons.open_in_new_rounded,
                            label: l.t('open'))),
                    PopupMenuItem(
                        value: 'move',
                        child: _MenuItem(
                            icon: Icons.drive_file_move_rounded,
                            label: l.t('move_to_category'))),
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
          if (clip.tags.isNotEmpty || category != null || isPendingClassification)
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
                      color: Colors.grey,
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ...clip.tags.map((t) => _Badge(
                        label: '#$t',
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
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
          '${clip.title}\n${clip.url}',
          sharePositionOrigin: origin,
        );
        return;
      case 'open':
        _openUrl(context, clip.url);
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
  @override
  Widget build(BuildContext context) {
    final categories = widget.state.categories
        .where((c) => c.id != widget.clip.categoryId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
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
          const SizedBox(height: 16),
          Text(
            AppL10n.of(context).t('move_to_category'),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                return InkWell(
                  onTap: () async {
                    final updated = widget.clip.copyWith(categoryId: cat.id);
                    await widget.state.updateClip(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          AppL10n.of(context).localizeCategoryDisplay(cat.id, cat.name),
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

  const _SubcategoryAssignSheet({
    required this.categoryId,
    required this.clipId,
    required this.state,
    required this.subcategories,
    required this.currentSubId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
                  style: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 13),
                ),
              )
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () {
                      state.setClipSubcategory(clipId, null);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentSubId == null ? Colors.grey : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                      ),
                      child: Text(Localizations.localeOf(context).languageCode == 'fr' ? 'Aucun' : 'None', style: TextStyle(color: currentSubId == null ? Colors.white : Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  ...subcategories.map((s) => GestureDetector(
                    onTap: () {
                      state.setClipSubcategory(clipId, s.id);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentSubId == s.id ? s.color : s.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: s.color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(s.icon, size: 14, color: currentSubId == s.id ? Colors.white : s.color),
                          const SizedBox(width: 6),
                          Text(s.name, style: TextStyle(color: currentSubId == s.id ? Colors.white : s.color, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  )),
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
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
    final url = _urlCtrl.text.trim();
    final lang = Localizations.localeOf(context).languageCode;
    if (!_isValidHttpUrl(url)) {
      setState(() => _urlError = lang == 'fr'
          ? 'URL invalide. Vérifiez que le lien commence par http:// ou https://.'
          : 'Invalid URL. Make sure the link starts with http:// or https://.');
      return;
    }
    final l = AppL10n.of(context);
    if (widget.state.isDuplicate(url)) {
      setState(() => _urlError = lang == 'fr'
          ? 'Ce lien est déjà dans votre liste.'
          : 'This link is already in your list.');
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
      platform: (_detectedPlatform ?? SocialPlatform.detect(url)).id,
      categoryId: categoryId,
      tags: tags,
      addedAt: DateTime.now(),
      thumbnailUrl: _thumbnailUrl,
    );
    await widget.state.addClip(clip);
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text('IA',
                                    style: TextStyle(
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
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                      color: Colors.grey.shade500, fontSize: 13),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CatChip(
          label: l.t('none'),
          color: Colors.grey,
          icon: Icons.block_rounded,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        ...categories.map((cat) => _CatChip(
              label: l.localizeCategoryDisplay(cat.id, cat.name),
              color: cat.color,
              icon: cat.icon,
              selected: selected == cat.id,
              onTap: () => onChanged(cat.id),
            )),
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
    );
    await widget.state.updateClip(updated);
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
