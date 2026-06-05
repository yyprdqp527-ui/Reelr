import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

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
import '../widgets/glass_card.dart';
import '../widgets/sheet_field.dart';

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final ClipsState state;

  const HomeScreen({super.key, required this.state});

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
                    '${widget.state.totalCount} vidéo${widget.state.totalCount > 1 ? 's' : ''} sauvegardée${widget.state.totalCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1, // carré parfait
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i == 0) {
                        return _CategoryTile(
                          name: l.t('all'),
                          color: AppTheme.orange,
                          icon: Icons.grid_view_rounded,
                          count: widget.state.totalCount,
                          onTap: () =>
                              _openCategory(context, null, l.t('all')),
                        );
                      }
                      final cat = widget.state.categories[i - 1];
                      final catClips =
                          widget.state.clipsForCategory(cat.id);
                      return _CategoryTile(
                        name: cat.name,
                        color: cat.color,
                        icon: DatabaseHelper.iconFor(cat.id) ?? cat.icon,
                        count: widget.state.countForCategory(cat.id),
                        onTap: () =>
                            _openCategory(context, cat.id, cat.name),
                        thumbnailUrl: catClips.isEmpty
                            ? null
                            : catClips.reversed.where((c) => c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty).map((c) => c.thumbnailUrl!.replaceAll('hqdefault.jpg', 'mqdefault.jpg').replaceAll('sddefault.jpg', 'mqdefault.jpg')).firstOrNull,
                        showBadge: widget.state.newlyClassifiedCategoryIds.contains(cat.id),
                      );
                    },
                    childCount: widget.state.categories.length + 1,
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
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: Text(
            l.t('app_name'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 30,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
        ),
      ),
      actions: [
        if (clips.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: l.t('share_list'),
            onPressed: () {
              final text =
                  clips.map((c) => '${c.title}\n${c.url}').join('\n\n');
              Share.share(text);
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

class _CategoryTile extends StatefulWidget {
  final String name;
  final Color color;
  final IconData? icon;
  final int count;
  final VoidCallback onTap;
  final bool isAdd;

  final String? thumbnailUrl;
  final bool showBadge;

  const _CategoryTile({
    required this.name,
    required this.color,
    required this.count,
    required this.onTap,
    this.icon,
    this.isAdd = false,
    this.thumbnailUrl,
    this.showBadge = false,
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
    final tintColor = widget.color;

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: widget.thumbnailUrl != null
                // ── Mode thumbnail : pas de BackdropFilter ──
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.thumbnailUrl!,
                        fit: BoxFit.cover,
                      ),
                      // Overlay gradient sombre en bas
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0xB3000000),
                              ],
                              stops: [0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Icône en haut à gauche
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          widget.icon ?? Icons.folder_outlined,
                          size: 24,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      // Nom + compteur en bas
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.4,
                                color: Colors.white,
                              ),
                            ),
                            if (!widget.isAdd) ...[
                              const SizedBox(height: 1),
                              Text(
                                '${widget.count}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: tintColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: tintColor.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
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
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(),
                              Icon(
                                widget.icon ?? Icons.folder_outlined,
                                size: 38,
                                color: isDark
                                    ? tintColor
                                    : tintColor.withValues(alpha: 0.80),
                                shadows: [
                                  Shadow(
                                    color: AppTheme.shadowGrey
                                        .withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.darkGreen,
                                ),
                              ),
                              if (!widget.isAdd) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.count}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
  String? _selectedSubcategoryId;

  List<Clip> _sorted(List<Clip> src) {
    final list = List<Clip>.from(src);
    switch (_sortOrder) {
      case SortOrder.chronological:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortOrder.alphabetical:
        list.sort((a, b) => a.title.compareTo(b.title));
      case SortOrder.manual:
        list.sort((a, b) {
          final cmp = a.position.compareTo(b.position);
          return cmp != 0 ? cmp : b.addedAt.compareTo(a.addedAt);
        });
    }
    return list;
  }

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
                onPressed: () => setState(() => _gridView = !_gridView),
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
                }),
                itemBuilder: (_) => [
                  _sortItem(SortOrder.chronological,
                      Icons.access_time_rounded, 'Chronologique'),
                  _sortItem(SortOrder.alphabetical,
                      Icons.sort_by_alpha_rounded, 'Alphabétique'),
                  _sortItem(
                      SortOrder.manual, Icons.drag_handle_rounded, 'Manuel'),
                ],
              ),
              // Toggle réorganiser (visible uniquement en mode Manuel)
              if (_sortOrder == SortOrder.manual)
                IconButton(
                  icon: Icon(_reorderMode
                      ? Icons.check_circle_rounded
                      : Icons.reorder_rounded),
                  tooltip: _reorderMode ? 'Terminé' : 'Réorganiser',
                  onPressed: () =>
                      setState(() => _reorderMode = !_reorderMode),
                ),
              if (clips.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () {
                    final text = clips
                        .map((c) => '${c.title}\n${c.url}')
                        .join('\n\n');
                    Share.share(text);
                  },
                ),
              if (widget.categoryId != null) ...[  
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  tooltip: 'Suggestions IA',
                  onPressed: () => _suggestWithAI(context, raw),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Ajouter une sous-catégorie',
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
                                            state: widget.state),
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
                                        onTap: () => launchUrl(Uri.parse(c.url)),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              c.thumbnailUrl != null
                                                  ? Image.network(c.thumbnailUrl!, fit: BoxFit.cover)
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
                                            title: const Text(
                                                'Supprimer ce clip ?'),
                                            content: const Text(
                                                'Cette action est irréversible.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        dlgCtx, false),
                                                child: const Text(
                                                    'Annuler'),
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
                                                child: const Text(
                                                    'Supprimer'),
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
                                          state: widget.state),
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
    IconData pickedIcon = Icons.label_rounded;
    final colors = [
      const Color(0xFF4F8EF7), const Color(0xFFFF5252), const Color(0xFF2ECC71),
      const Color(0xFFFF9800), const Color(0xFF9C27B0), const Color(0xFF00BCD4),
      const Color(0xFFE91E63), const Color(0xFFFFB300), const Color(0xFF009688),
      AppTheme.orange,
    ];
    final icons = [
      Icons.label_rounded, Icons.star_rounded, Icons.bookmark_rounded,
      Icons.favorite_rounded, Icons.tag_rounded, Icons.folder_rounded,
      Icons.movie_rounded, Icons.photo_rounded, Icons.music_note_rounded,
      Icons.travel_explore_rounded,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle sous-catégorie'),
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
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Couleur',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
                  const SizedBox(height: 14),
                  const Text('Icône',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: icons
                        .map((ic) => GestureDetector(
                              onTap: () =>
                                  setDlgState(() => pickedIcon = ic),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: pickedIcon == ic
                                      ? pickedColor.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: pickedIcon == ic
                                        ? pickedColor
                                        : Colors.grey.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(ic,
                                    size: 18,
                                    color: pickedIcon == ic
                                        ? pickedColor
                                        : Colors.grey),
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
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.state.addSubCategory(SubCategory(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  categoryId: widget.categoryId!,
                  color: pickedColor,
                  icon: pickedIcon,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _suggestWithAI(BuildContext context, List<Clip> rawClips) {
    if (rawClips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun clip à analyser.')),
      );
      return;
    }
    // Groupe les clips par thème via le classifieur
    final Map<String, List<String>> groups = {};
    for (final clip in rawClips) {
      final suggestion = CategoryClassifier.suggestDetailed(clip.title);
      if (!suggestion.isUnclassified) {
        groups.putIfAbsent(suggestion.name, () => []).add(clip.title);
      }
    }
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun thème détecté automatiquement.')),
      );
      return;
    }
    final selected = <String>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.orange, size: 22),
              const SizedBox(width: 8),
              const Text('Sous-catégories suggérées'),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: groups.entries.map((e) {
                  final isSelected = selected.contains(e.key);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(e.key,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${e.value.length} clip${e.value.length > 1 ? "s" : ""}',
                        style: const TextStyle(fontSize: 12)),
                    onChanged: (v) => setDlgState(() {
                      if (v == true) {
                        selected.add(e.key);
                      } else {
                        selected.remove(e.key);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      for (final name in selected) {
                        final suggestion =
                            CategoryClassifier.suggestDetailed(name);
                        widget.state.addSubCategory(SubCategory(
                          id: const Uuid().v4(),
                          name: name,
                          categoryId: widget.categoryId!,
                          color: suggestion.isUnclassified
                              ? AppTheme.orange
                              : suggestion.color,
                          icon: suggestion.isUnclassified
                              ? Icons.label_rounded
                              : suggestion.icon,
                        ));
                      }
                    },
              child: const Text('Créer la sélection'),
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
        title: const Text('Supprimer la sous-catégorie ?'),
        content: Text('"${sub.name}" sera supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              onDelete(sub.id);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
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
            color: selected ? Colors.white : color,
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
            Text('Tes vidéos préférées,\nenfin au même endroit', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3, color: textColor)),
            const SizedBox(height: 12),
            Text('Va sur YouTube, Instagram ou TikTok\nappuie sur  ↑  puis choisis Reelr', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.6, color: subColor)),
          ],
        ),
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
            ? Image.network(
                thumbUrl!,
                fit: BoxFit.cover,
                // Loader
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _fallback(shimmer: true);
                },
                // Erreur → icône plateforme
                errorBuilder: (_, __, ___) => _fallback(), // ignore: unnecessary_underscores
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

  const ClipCard({super.key, required this.clip, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final platform = SocialPlatform.detect(clip.url);
    final category = state.categoryById(clip.categoryId);
    final lang = Localizations.localeOf(context).languageCode;
    final thumbUrl =
        OEmbedService.bestThumbnailUrl(clip.url, clip.thumbnailUrl);

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _openUrl(clip.url),
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
          if (clip.tags.isNotEmpty || category != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (category != null)
                    _Badge(
                      label: category.name,
                      color: category.color,
                      icon: category.icon,
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleAction(BuildContext context, String action, AppL10n l) {
    switch (action) {
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditClipSheet(clip: clip, state: state),
        );
      case 'share':
        Share.share('${clip.title}\n${clip.url}');
      case 'open':
        _openUrl(clip.url);
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
                              ? 'Nouvelle catégorie'
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
                        hint: 'Dans quelle catégorie ?',
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
                'Cette vidéo ressemble à du ${s.name}',
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
                  child: Text('Ajouter dans ${s.name}'),
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
                  child: const Text('Autre catégorie'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Ajouter sans catégorie',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            ] else ...[  
              TextField(
                controller: _customCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nom de la catégorie...',
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
                      child: const Text('Annuler'),
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
                      child: const Text('Créer'),
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
              label: cat.name,
              color: cat.color,
              icon: cat.icon,
              selected: selected == cat.id,
              onTap: () => onChanged(cat.id),
            )),
        _CatChip(
          label: '+ Créer',
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
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
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
  late String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.clip.title);
    _tagsCtrl =
        TextEditingController(text: widget.clip.tags.join(', '));
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
    final updated = Clip(
      id: widget.clip.id,
      url: widget.clip.url,
      title: title.isEmpty ? l.t('no_title') : title,
      platform: widget.clip.platform,
      categoryId: _selectedCategoryId,
      tags: tags,
      addedAt: widget.clip.addedAt,
      thumbnailUrl: widget.clip.thumbnailUrl,
    );
    await widget.state.updateClip(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
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
                      onChanged: (id) =>
                          setState(() => _selectedCategoryId = id),
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
