import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../models/clip.dart';
import '../services/oembed.dart';
import '../widgets/playlist_pick_row.dart';

// ─────────────────────────────────────────────
// PLAYLIST SHARE SELECT SCREEN
// ─────────────────────────────────────────────
//
// Ouvert par le bouton partager d'une catégorie, avant de générer le lien.
// Tout est coché au départ ; on décoche ce qu'on ne veut pas envoyer.
// Renvoie (Navigator.pop) la liste des clips choisis, dans l'ordre de la
// catégorie, ou null si on revient en arrière.

class PlaylistShareSelectScreen extends StatefulWidget {
  final String name;
  final List<Clip> clips;

  const PlaylistShareSelectScreen({
    super.key,
    required this.name,
    required this.clips,
  });

  @override
  State<PlaylistShareSelectScreen> createState() =>
      _PlaylistShareSelectScreenState();
}

class _PlaylistShareSelectScreenState extends State<PlaylistShareSelectScreen> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.clips.length; i++) i,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final clips = widget.clips;
    final allSelected = _selected.length == clips.length;
    final count = _selected.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.playlistShareTitle(widget.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (allSelected) {
                _selected.clear();
              } else {
                _selected.addAll([for (var i = 0; i < clips.length; i++) i]);
              }
            }),
            child: Text(allSelected
                ? l.t('playlist_import_deselect_all')
                : l.t('playlist_import_select_all')),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              l.playlistShareSummary(clips.length),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              itemCount: clips.length,
              itemBuilder: (context, index) {
                final clip = clips[index];
                return PlaylistPickRow(
                  url: clip.url,
                  title: clip.title,
                  thumbnailUrl:
                      OEmbedService.bestThumbnailUrl(clip.url, clip.thumbnailUrl),
                  cacheKeyId: clip.id,
                  persistId: clip.id,
                  subtitle: PlaylistPickRow.sourceLabel(clip.url),
                  selected: _selected.contains(index),
                  onTap: () => setState(() {
                    if (!_selected.remove(index)) _selected.add(index);
                  }),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: count == 0
                  ? null
                  : () => Navigator.of(context).pop([
                        for (var i = 0; i < clips.length; i++)
                          if (_selected.contains(i)) clips[i],
                      ]),
              child: Text(count == 0
                  ? l.t('playlist_share_none_selected')
                  : l.playlistShareSend(count)),
            ),
          ),
        ),
      ),
    );
  }
}
