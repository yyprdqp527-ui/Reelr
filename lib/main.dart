import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'services/thumbnail_store.dart';
import 'state/clips_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  final state = ClipsState();
  // Base de donnees et index des vignettes en parallele : l'index (une
  // lecture de dossier) permet d'afficher les vignettes des la premiere
  // image, sans etat de chargement.
  await Future.wait([
    state.loadAll().catchError((Object e, StackTrace st) {
      debugPrint('DB init error: $e\n$st');
    }),
    ThumbnailStore.instance.warmUp(),
  ]);
  runApp(ClipsApp(state: state));
}


