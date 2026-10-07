import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n.dart';
import '../models/category.dart';
import '../models/clip.dart';
import '../services/oembed.dart';
import '../services/sorting_notebook.dart';
import '../state/clips_state.dart';
import '../widgets/resilient_thumbnail.dart';

/// Ecran « Ce que Reelr a appris » : les rangements faits a la main, que
/// l'appli utilise comme exemples pour classer les liens du meme sujet.
/// Chaque exemple montre la vignette du lien, son site et sa categorie en
/// couleur, pour pouvoir juger d'un coup d'oeil s'il est juste. Il peut etre
/// supprime s'il est faux.
class SortingNotebookScreen extends StatefulWidget {
  final ClipsState state;

  const SortingNotebookScreen({super.key, required this.state});

  @override
  State<SortingNotebookScreen> createState() => _SortingNotebookScreenState();
}

class _SortingNotebookScreenState extends State<SortingNotebookScreen> {
  final SortingNotebook _notebook = SortingNotebook();
  List<NotebookEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final loaded = await _notebook.load();
    loaded.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    if (!mounted) return;
    setState(() => _entries = loaded);
  }

  Future<void> _remove(NotebookEntry entry) async {
    await _notebook.remove(entry.id);
    await _reload();
  }

  Future<void> _clearAll() async {
    final l = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.t('notebook_clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('notebook_clear')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _notebook.clear();
    await _reload();
  }

  Clip? _clipOf(NotebookEntry e) {
    for (final c in widget.state.allClips) {
      if (c.id == e.id) return c;
    }
    return null;
  }

  /// Categorie de l'exemple dans l'appli : par identifiant (`cat_xxx`) ou,
  /// pour une tuile personnelle, par nom.
  ClipCategory? _categoryOf(NotebookEntry e) {
    for (final c in widget.state.categories) {
      if (c.id == e.categoryRef || c.name == e.categoryRef) return c;
    }
    return null;
  }

  String _categoryText(AppL10n l, NotebookEntry e) {
    if (e.categoryRef.startsWith('cat_')) {
      return l.localizeCategoryDisplay(e.categoryRef, e.categoryLabel);
    }
    return e.categoryLabel;
  }

  Widget _thumbnail(Clip? clip, Color accent) {
    Widget fallback(BuildContext _) => Container(
          color: accent.withValues(alpha: 0.15),
          child: Icon(Icons.link_rounded, color: accent, size: 22),
        );
    return SizedBox(
      width: 64,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: clip == null
            ? fallback(context)
            : ResilientThumbnail(
                url: OEmbedService.bestThumbnailUrl(
                        clip.url, clip.thumbnailUrl) ??
                    clip.thumbnailUrl,
                cacheKeyId: clip.id,
                persistId: clip.id,
                platformId: SocialPlatform.detect(clip.url).id,
                fit: BoxFit.cover,
                fallbackBuilder: fallback,
              ),
      ),
    );
  }

  Widget _categoryChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppL10n l, NotebookEntry e) {
    final clip = _clipOf(e);
    final cat = _categoryOf(e);
    final color =
        cat?.color ?? AppL10n.categoryColors[e.categoryRef] ?? Colors.grey;
    final host = clip == null
        ? ''
        : (Uri.tryParse(clip.url)?.host.replaceFirst('www.', '') ?? '');
    return InkWell(
      onTap: clip == null
          ? null
          : () async {
              final uri = Uri.tryParse(clip.url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _thumbnail(clip, color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (host.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _categoryChip(_categoryText(l, e), color),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => _remove(e),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('settings_notebook')),
        actions: [
          if (entries != null && entries.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(l.t('notebook_clear')),
            ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l.t('notebook_intro'),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      l.t('notebook_empty'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                for (final e in entries)
                  Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child:
                          const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) => _remove(e),
                    child: _row(l, e),
                  ),
              ],
            ),
    );
  }
}
