import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Copie du compteur a vie dans le Keychain iOS.
///
/// SharedPreferences est efface quand l'utilisateur supprime l'app : le
/// quota de 50 sauvegardes gratuites repartait alors de zero. Le Keychain
/// survit a la suppression de l'app (et se synchronise entre les appareils
/// de l'utilisateur via le trousseau iCloud). Sur Android, la sauvegarde
/// automatique de Google restaure deja SharedPreferences : on ne fait rien.
class LifetimeCounterStore {
  static const MethodChannel _channel = MethodChannel('reelr/lifetime_counter');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Valeur sauvegardee, ou null (aucune, indisponible, autre plateforme).
  static Future<int?> read() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<int>('get');
    } catch (e) {
      debugPrint('[lifetime] lecture Keychain impossible : $e');
      return null;
    }
  }

  static Future<void> write(int value) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('set', value);
    } catch (e) {
      debugPrint('[lifetime] ecriture Keychain impossible : $e');
    }
  }
}
