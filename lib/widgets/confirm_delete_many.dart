import 'package:flutter/material.dart';

import '../core/l10n.dart';

/// Seuil au-dela duquel supprimer une tuile demande une deuxieme
/// confirmation : un appui long suffit a ouvrir la suppression, et elle
/// emporte les liens de la tuile pour toujours.
const int kDeleteManyThreshold = 10;

/// Deuxieme confirmation avant de supprimer une tuile qui contient plus de
/// [kDeleteManyThreshold] liens. Renvoie vrai si la personne confirme.
Future<bool> confirmDeleteMany(
    BuildContext context, AppL10n l, int count) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.t('delete_many_title').replaceAll('{n}', '$count')),
      content: Text(l.t('delete_many_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(l.t('delete_many_confirm')),
        ),
      ],
    ),
  );
  return ok == true;
}
