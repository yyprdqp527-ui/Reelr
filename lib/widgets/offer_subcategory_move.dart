import 'package:flutter/material.dart';

import '../state/clips_state.dart';

/// Apres la creation d'une sous-categorie par le client : si des liens deja
/// presents dans la categorie correspondent a son nom, propose de les y
/// ranger d'un geste. Ne fait rien s'il n'y en a aucun.
Future<void> offerMoveMatchingClips(
    BuildContext context, ClipsState state, SubCategory sub) async {
  if (state.candidateClipsForSubcategory(sub).isEmpty || !context.mounted) {
    return;
  }
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  // Claude lit les liens de la tuile (titre, description, vignette) : on
  // patiente quelques secondes derriere un indicateur.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: Text(fr ? 'Reelr cherche les liens…' : 'Reelr is looking…'),
            ),
          ],
        ),
      ),
    ),
  );
  final matches = await state.findClipsForNewSubcategory(sub);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (matches.isEmpty) return;
  final n = matches.length;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(fr
          ? 'Ranger ${n == 1 ? 'ce lien' : 'ces $n liens'} dans « ${sub.name} » ?'
          : 'Move ${n == 1 ? 'this link' : 'these $n links'} to "${sub.name}"?'),
      content: Text(fr
          ? (n == 1
              ? 'Un lien déjà enregistré correspond à ce nom.'
              : '$n liens déjà enregistrés correspondent à ce nom.')
          : (n == 1
              ? 'One saved link matches this name.'
              : '$n saved links match this name.')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(fr ? 'Non' : 'No')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(fr ? 'Ranger' : 'Move')),
      ],
    ),
  );
  if (ok == true) await state.moveClipsToSubcategory(matches, sub);
}
