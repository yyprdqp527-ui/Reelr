import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../services/oembed.dart';
import '../services/playlist_link.dart';
import '../state/clips_state.dart';
import '../widgets/resilient_thumbnail.dart';

// ─────────────────────────────────────────────
// PLAYLIST IMPORT SCREEN
// ─────────────────────────────────────────────
//
// Écran d'aperçu affiché à l'ouverture d'un lien reelr://playlist reçu
// d'un ami (Part 6 — étape 2). Chaque vidéo peut être décochée avant
// l'import ; les vidéos déjà présentes dans la collection sont signalées
// et non sélectionnées par défaut. L'import réel réutilise entièrement le
// pipeline existant (dédoublonnage, limite gratuite, classification en
// arrière-plan) via [onImportUrl].

class PlaylistImportScreen extends StatefulWidget {
  final ClipsState state;
  final PlaylistLink playlist;
  final Future<void> Function(String url) onImportUrl;

  const PlaylistImportScreen({
    super.key,
    required this.state,
    required this.playlist,
    required this.onImportUrl,
  });

  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  late final Set<int> _selected;
  late final List<bool> _alreadySaved;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _alreadySaved = widget.playlist.items
        .map((i) => widget.state.isDuplicate(i.url))
        .toList();
    _selected = {
      for (var i = 0; i < widget.playlist.items.length; i++)
        if (!_alreadySaved[i]) i,
    };
  }

  void _toggleAll(bool select) {
    setState(() {
      _selected
        ..clear()
        ..addAll([
          for (var i = 0; i < widget.playlist.items.length; i++)
            if (select && !_alreadySaved[i]) i,
        ]);
    });
  }

  Future<void> _import(AppL10n l) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('playlist_import_none_selected'))),
      );
      return;
    }
    setState(() => _importing = true);
    var imported = 0;
    for (final index in _selected.toList()..sort()) {
      final url = widget.playlist.items[index].url;
      await widget.onImportUrl(url);
      imported++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.playlistImportedCount(imported))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final items = widget.playlist.items;
    final allSelectable = <int>[
      for (var i = 0; i < items.length; i++)
        if (!_alreadySaved[i]) i,
    ];
    final allSelected =
        allSelectable.isNotEmpty && allSelectable.every(_selected.contains);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(allSelected
                ? Icons.deselect_rounded
                : Icons.select_all_rounded),
            tooltip: allSelected
                ? l.t('playlist_import_deselect_all')
                : l.t('playlist_import_select_all'),
            onPressed: allSelectable.isEmpty
                ? null
                : () => _toggleAll(!allSelected),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final duplicate = _alreadySaved[index];
          final platform = SocialPlatform.detect(item.url);
          return CheckboxListTile(
            value: _selected.contains(index),
            // Toujours cochable, y compris pour les vidéos déjà présentes
            // (l'import ignore silencieusement les doublons) — seul l'état
            // par défaut (décochée) diffère pour celles-ci.
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _selected.add(index);
              } else {
                _selected.remove(index);
              }
            }),
            secondary: SizedBox(
              width: 48,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ResilientThumbnail(
                  url: item.thumbnailUrl,
                  cacheKeyId: 'playlist_import_$index',
                  platformId: platform.id,
                  fit: BoxFit.cover,
                  fallbackBuilder: (_) => Container(
                    color: platform.color.withValues(alpha: 0.12),
                    child: Icon(platform.icon, color: platform.color, size: 20),
                  ),
                ),
              ),
            ),
            title: Text(
              item.title.isEmpty ? item.url : item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: duplicate
                ? Text(l.t('playlist_import_already_saved'))
                : Text(
                    item.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _importing ? null : () => _import(l),
              child: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${l.t('playlist_import_action')} (${_selected.length})'),
            ),
          ),
        ),
      ),
    );
  }
}
