import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../services/playlist_link.dart';
import '../state/clips_state.dart';
import '../widgets/playlist_pick_row.dart';

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
  /// Renvoie `true` si un clip a bien été créé. Doit être appelée en mode
  /// silencieux : cet écran importe en boucle, et tout retour visuel émis
  /// par l'ingestion se répéterait autant de fois qu'il y a de vidéos.
  final Future<bool> Function(PlaylistLinkItem item) onImportItem;
  /// Vrai tant que la limite gratuite permet d'ajouter un clip.
  final bool Function() canAddMore;
  /// Appelée une seule fois, après la fermeture de l'écran, avec les
  /// vidéos non importées faute de place (limite gratuite atteinte).
  final void Function(List<String> heldUrls) onLimitReached;

  const PlaylistImportScreen({
    super.key,
    required this.state,
    required this.playlist,
    required this.onImportItem,
    required this.canAddMore,
    required this.onLimitReached,
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
    final held = <String>[];
    for (final index in _selected.toList()..sort()) {
      final item = widget.playlist.items[index];
      final url = item.url;
      // Limite gratuite atteinte : les vidéos restantes sont gardées en
      // attente, pas perdues. Un doublon n'a pas besoin d'être gardé.
      if (!widget.canAddMore()) {
        if (!widget.state.isDuplicate(url)) held.add(url);
        continue;
      }
      // On compte les clips REELLEMENT crees. `onImportUrl` refuse
      // silencieusement les doublons, les URLs sans contenu et tout ce
      // qui depasse la limite gratuite : annoncer « 10 importees » quand
      // trois seulement le sont serait mentir a l'utilisateur.
      if (await widget.onImportItem(item)) imported++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.playlistImportedCount(imported))),
    );
    Navigator.of(context).pop();
    if (held.isNotEmpty) widget.onLimitReached(held);
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
          TextButton(
            onPressed: allSelectable.isEmpty
                ? null
                : () => _toggleAll(!allSelected),
            child: Text(allSelected
                ? l.t('playlist_import_deselect_all')
                : l.t('playlist_import_select_all')),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final duplicate = _alreadySaved[index];
          // Toujours cochable, y compris pour les liens déjà présents
          // (l'import ignore les doublons) : seul l'état par défaut
          // (décoché) diffère pour ceux-ci.
          return PlaylistPickRow(
            url: item.url,
            title: item.title,
            thumbnailUrl: item.thumbnailUrl,
            cacheKeyId: 'playlist_import_$index',
            subtitle: duplicate
                ? l.t('playlist_import_already_saved')
                : PlaylistPickRow.sourceLabel(item.url),
            selected: _selected.contains(index),
            onTap: () => setState(() {
              if (!_selected.remove(index)) _selected.add(index);
            }),
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
