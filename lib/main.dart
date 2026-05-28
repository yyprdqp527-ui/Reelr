import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'state/clips_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  final state = ClipsState();
  try {
    await state.loadAll();
  } catch (e, st) {
    debugPrint('DB init error: $e\n$st');
  }
  runApp(ClipsApp(state: state));
}


