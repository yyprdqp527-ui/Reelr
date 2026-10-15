import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'receipt_expiry.dart';

/// Service responsable de l'achat et de la restauration de l'abonnement
/// Reelr Premium via StoreKit (App Store).
class PurchaseService {
  static const String premiumYearlyId = 'com.reelr.app.premium.yearly';

  final VoidCallback onPremiumUnlocked;
  /// Appelé quand [silentlyReverifyEntitlement] ne retrouve plus
  /// l'abonnement côté store alors que l'appareil le croyait actif
  /// localement (résiliation, remboursement, expiration...). Optionnel :
  /// si non fourni, aucune revérification n'est effectuée.
  final VoidCallback? onPremiumExpired;
  final void Function(String message)? onError;
  final bool Function() isFr;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool isAvailable = false;
  ProductDetails? premiumProduct;
  bool isLoadingProduct = false;

  /// Se complete quand l'operation en cours (achat ou restauration) atteint
  /// un etat terminal cote StoreKit : achete, restaure, annule ou en erreur.
  /// Permet a l'ecran appelant d'afficher un indicateur tant que rien n'est
  /// tranche, au lieu de rendre la main immediatement apres addPayment et de
  /// laisser l'utilisateur devant un bouton qui ne reagit pas.
  Completer<void>? _settled;

  /// Filet de securite : StoreKit peut ne jamais rien renvoyer (restauration
  /// sans rien a restaurer, file de paiement muette). Sans ce minuteur, le
  /// jalon resterait ouvert a vie et gelerait les achats suivants.
  Timer? _watchdog;

  /// Vrai entre l'appel a buyNonConsumable et l'etat terminal de cet achat.
  /// Sert uniquement a ignorer les taps repetes : une restauration en cours
  /// ne doit pas, elle, empecher un achat.
  bool _purchaseInFlight = false;

  PurchaseService({
    required this.onPremiumUnlocked,
    required this.isFr,
    this.onError,
    this.onPremiumExpired,
  });

  Future<void> init() async {
    isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      debugPrint('[purchase] StoreKit indisponible sur cet appareil.');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        debugPrint('[purchase] purchaseStream error: $error');
        onError?.call(isFr()
            ? 'Erreur du service d\'achat. Réessaie plus tard.'
            : 'Purchase service error. Please try again later.');
      },
    );

    await _loadProduct();
  }

  /// Recharge le produit s'il manque (StoreKit lent ou echec precedent).
  Future<void> ensureProduct() async {
    if (premiumProduct != null || isLoadingProduct || !isAvailable) return;
    await _loadProduct();
  }

  Future<void> _loadProduct() async {
    isLoadingProduct = true;
    try {
      final response =
          await _iap.queryProductDetails({premiumYearlyId});
      if (response.error != null) {
        debugPrint('[purchase] queryProductDetails error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            '[purchase] Produit introuvable côté store: ${response.notFoundIDs}');
      }
      if (response.productDetails.isNotEmpty) {
        premiumProduct = response.productDetails.first;
      }
    } catch (e) {
      debugPrint('[purchase] Exception lors du chargement du produit: $e');
    } finally {
      isLoadingProduct = false;
    }
  }

  /// Ouvre un nouveau jalon d'attente, en liberant celui qui trainait.
  Completer<void> _arm(Duration watchdog) {
    _settle();
    final fresh = Completer<void>();
    _settled = fresh;
    _watchdog = Timer(watchdog, _settle);
    return fresh;
  }

  /// Marque l'operation en cours comme tranchee. Idempotent.
  void _settle() {
    _watchdog?.cancel();
    _watchdog = null;
    _purchaseInFlight = false;
    final c = _settled;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Attend que l'achat ou la restauration en cours atteigne un etat
  /// terminal, avec un plafond de securite pour ne jamais laisser un
  /// indicateur tourner indefiniment si StoreKit ne renvoie rien.
  Future<void> waitUntilSettled({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final c = _settled;
    if (c == null || c.isCompleted) return;
    try {
      await c.future.timeout(timeout);
    } on TimeoutException {
      debugPrint('[purchase] waitUntilSettled: plafond atteint.');
      _settle();
    }
  }

  Future<bool> buyPremium() async {
    if (!isAvailable) {
      onError?.call(isFr()
          ? 'Les achats ne sont pas disponibles sur cet appareil.'
          : 'Purchases are not available on this device.');
      return false;
    }
    if (premiumProduct == null) await ensureProduct();
    final product = premiumProduct;
    if (product == null) {
      onError?.call(isFr()
          ? 'Produit indisponible pour le moment. Réessaie dans un instant.'
          : 'Product unavailable right now. Please try again in a moment.');
      return false;
    }
    // Un achat deja en vol : ne pas empiler un second addPayment dans la
    // file StoreKit, qui le rejetterait avec une erreur trompeuse.
    if (_purchaseInFlight) {
      debugPrint('[purchase] Achat deja en cours — tap ignore.');
      return true;
    }
    final purchaseParam = PurchaseParam(productDetails: product);
    final settled = _arm(const Duration(minutes: 3));
    _purchaseInFlight = true;
    try {
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started && identical(_settled, settled)) _settle();
      return started;
    } catch (e) {
      if (identical(_settled, settled)) _settle();
      debugPrint('[purchase] Exception lors de buyNonConsumable: $e');
      onError?.call(isFr()
          ? 'Achat impossible. Réessaie plus tard.'
          : 'Purchase failed. Please try again later.');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!isAvailable) {
      onError?.call(isFr()
          ? 'Les achats ne sont pas disponibles sur cet appareil.'
          : 'Purchases are not available on this device.');
      return;
    }
    final settled = _arm(const Duration(seconds: 30));
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (identical(_settled, settled)) _settle();
      debugPrint('[purchase] Exception lors de restorePurchases: $e');
      onError?.call(isFr()
          ? 'Restauration impossible. Réessaie plus tard.'
          : 'Restore failed. Please try again later.');
    }
  }

  /// Resynchronise silencieusement le statut Premium local avec le store,
  /// à appeler une fois au démarrage de l'app (jamais suite à une action de
  /// l'utilisateur, donc aucune erreur affichée ici).
  ///
  /// Avant cet ajout, une fois `is_premium` passé à `true`, rien ne le
  /// repassait jamais à `false` : un abonnement résilié, expiré ou
  /// remboursé laissait l'accès Premium actif indéfiniment sur l'appareil.
  /// Ici, on relance une restauration ; si l'abonnement est toujours actif
  /// côté store, [onPremiumUnlocked] sera rappelé normalement via
  /// [_handlePurchaseUpdates]. S'il ne l'est plus (et que l'appareil le
  /// croyait actif), [onPremiumExpired] est appelé pour retirer l'accès
  /// local. En cas d'erreur réseau/store, on ne change rien par prudence
  /// (mieux vaut un faux positif "encore Premium" temporaire qu'un vrai
  /// utilisateur payant perdant l'accès à cause d'un simple problème
  /// réseau).
  Future<void> silentlyReverifyEntitlement({
    required bool currentlyPremium,
  }) async {
    if (!isAvailable) return;
    // Rien a revoquer chez un utilisateur non Premium : inutile de lancer
    // une restauration au demarrage. Elle occupait la file de paiement
    // StoreKit pendant plusieurs secondes (restore + 6 s d'attente) et tout
    // achat declenche dans cette fenetre restait bloque derriere elle —
    // exactement le cas d'un utilisateur gratuit qui ouvre le paywall.
    if (!currentlyPremium) return;
    var found = false;
    final sub = _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.productID == premiumYearlyId &&
            (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored) &&
            !_isExpiredRestore(p)) {
          found = true;
        }
      }
    });
    try {
      await _iap.restorePurchases();
      // Les evenements de la file d'achat arrivent de facon asynchrone, pas
      // forcement avant la fin de restorePurchases(). On attend jusqu'a
      // [_reverifyWait] (reseau lent), mais on s'arrete des qu'un abonnement
      // actif est retrouve : le cas normal reste rapide.
      final deadline = DateTime.now().add(_reverifyWait);
      while (!found && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } catch (e) {
      debugPrint('[purchase] silentlyReverifyEntitlement error: $e');
      await sub.cancel();
      return;
    }
    await sub.cancel();

    // Deux verifications negatives de suite avant de retirer Premium : une
    // seule reponse manquante (reseau lent, App Store muet) ne doit jamais
    // priver un abonne de son acces. Le compteur repart a zero des qu'on
    // retrouve l'abonnement.
    final prefs = await SharedPreferences.getInstance();
    if (found) {
      await prefs.setInt(_missedKey, 0);
      return;
    }
    final missed = (prefs.getInt(_missedKey) ?? 0) + 1;
    if (missed < _missedLimit) {
      await prefs.setInt(_missedKey, missed);
      debugPrint('[purchase] Abonnement non retrouve ($missed/$_missedLimit) '
          '— Premium conserve, nouvelle verification au prochain demarrage.');
      return;
    }
    await prefs.setInt(_missedKey, 0);
    debugPrint(
        '[purchase] Abonnement non retrouve $_missedLimit fois de suite — '
        'retrait du statut Premium local.');
    onPremiumExpired?.call();
  }

  static const String _missedKey = 'premium_reverify_missed';
  static const int _missedLimit = 2;
  static const Duration _reverifyWait = Duration(seconds: 20);

  /// Vrai si [p] est une transaction « restauree » dont le recu App Store
  /// montre que l'abonnement est DEJA expire. StoreKit renvoie aussi ces
  /// transactions-la : sans ce test, restaurer un abonnement perime redonnait
  /// Premium. Faux au moindre doute (recu illisible, date absente) : on ne
  /// refuse jamais un abonne a cause d'un recu mal lu.
  bool _isExpiredRestore(PurchaseDetails p) {
    if (p.status != PurchaseStatus.restored) return false;
    final receipt = p.verificationData.serverVerificationData;
    if (receipt.isEmpty) return false;
    final expiry = ReceiptExpiry.latestExpiry(receipt, premiumYearlyId);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now().toUtc());
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != premiumYearlyId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('[purchase] Achat en attente...');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_isExpiredRestore(purchase)) {
            // Abonnement deja expire : pas de Premium. L'ecran d'achat
            // affiche « Aucun abonnement a restaurer » si rien d'autre ne
            // debloque.
            debugPrint('[purchase] Restauration ignoree : abonnement expire.');
            _settle();
            if (purchase.pendingCompletePurchase) {
              _iap.completePurchase(purchase);
            }
            break;
          }
          debugPrint('[purchase] Achat confirmé (${purchase.status}).');
          _settle();
          onPremiumUnlocked();
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[purchase] Erreur d\'achat: ${purchase.error}');
          _settle();
          onError?.call(isFr()
              ? 'L\'achat a échoué. Réessaie plus tard.'
              : 'The purchase failed. Please try again later.');
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          debugPrint('[purchase] Achat annulé par l\'utilisateur.');
          _settle();
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  void dispose() {
    _settle();
    _subscription?.cancel();
  }
}
