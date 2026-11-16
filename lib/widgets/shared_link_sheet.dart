import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/oembed.dart';
import '../services/playlist_link.dart';
import '../state/clips_state.dart';
import 'resilient_thumbnail.dart';
import 'site_logo.dart';

/// Feuille « Un ami te partage » : un seul lien reçu.
/// Remplace l'écran de playlist quand le partage ne contient qu'un lien.
class SharedLinkSheet extends StatefulWidget {
  final ClipsState state;
  final PlaylistLinkItem item;
  /// Renvoie `true` si le clip a bien été créé (mode silencieux).
  final Future<bool> Function(PlaylistLinkItem item) onImportItem;
  final bool Function() canAddMore;
  /// Appelée avec le lien si la limite gratuite est atteinte.
  final void Function(List<String> heldUrls) onLimitReached;

  const SharedLinkSheet({
    super.key,
    required this.state,
    required this.item,
    required this.onImportItem,
    required this.canAddMore,
    required this.onLimitReached,
  });

  static Future<void> show(
    BuildContext context, {
    required ClipsState state,
    required PlaylistLinkItem item,
    required Future<bool> Function(PlaylistLinkItem item) onImportItem,
    required bool Function() canAddMore,
    required void Function(List<String> heldUrls) onLimitReached,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SharedLinkSheet(
        state: state,
        item: item,
        onImportItem: onImportItem,
        canAddMore: canAddMore,
        onLimitReached: onLimitReached,
      ),
    );
  }

  @override
  State<SharedLinkSheet> createState() => _SharedLinkSheetState();
}

class _SharedLinkSheetState extends State<SharedLinkSheet> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = AppL10n.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final url = widget.item.url;
    // Limite gratuite : le lien est gardé, pas perdu.
    if (!widget.canAddMore()) {
      nav.pop();
      if (!widget.state.isDuplicate(url)) widget.onLimitReached([url]);
      return;
    }
    final ok = await widget.onImportItem(widget.item);
    messenger.showSnackBar(
      SnackBar(content: Text(l.playlistImportedCount(ok ? 1 : 0))),
    );
    if (nav.mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final theme = Theme.of(context);
    final item = widget.item;
    final platform = SocialPlatform.detect(item.url);
    final saved = widget.state.isDuplicate(item.url);
    final fallbackIcon = Icon(platform.icon, color: platform.color, size: 48);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.t('shared_link_title'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: double.infinity,
                height: 220,
                child: ResilientThumbnail(
                  url: item.thumbnailUrl,
                  cacheKeyId: 'shared_${item.url.hashCode}',
                  platformId: platform.id,
                  fit: BoxFit.cover,
                  fallbackBuilder: (_) => Container(
                    color: platform.color.withValues(alpha: 0.12),
                    child: Center(
                      child: platform.id == 'other'
                          ? SiteLogo(
                              url: item.url, size: 56, fallback: fallbackIcon)
                          : fallbackIcon,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.title.isEmpty ? item.url : item.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.violet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: (saved || _busy) ? null : _add,
                child: Text(
                  saved
                      ? l.t('playlist_import_already_saved')
                      : l.t('shared_link_add'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(l.t('shared_link_later')),
            ),
          ],
        ),
      ),
    );
  }
}
