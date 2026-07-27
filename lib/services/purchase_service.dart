import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

  Future<bool> buyPremium() async {
    if (!isAvailable) {
      onError?.call(isFr()
          ? 'Les achats ne sont pas disponibles sur cet appareil.'
          : 'Purchases are not available on this device.');
      return false;
    }
    final product = premiumProduct;
    if (product == null) {
      onError?.call(isFr()
          ? 'Produit indisponible pour le moment. Réessaie dans un instant.'
          : 'Product unavailable right now. Please try again in a moment.');
      return false;
    }
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
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
    try {
      await _iap.restorePurchases();
    } catch (e) {
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
    var found = false;
    final sub = _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.productID == premiumYearlyId &&
            (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored)) {
          found = true;
        }
      }
    });
    try {
      await _iap.restorePurchases();
      // Les événements de la queue d'achat arrivent de façon asynchrone,
      // pas nécessairement avant la fin de restorePurchases() : on laisse
      // un délai raisonnable pour qu'ils remontent.
      await Future.delayed(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[purchase] silentlyReverifyEntitlement error: $e');
      await sub.cancel();
      return;
    }
    await sub.cancel();
    if (currentlyPremium && !found) {
      debugPrint(
          '[purchase] Abonnement non retrouvé au démarrage — retrait du statut Premium local.');
      onPremiumExpired?.call();
    }
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
          debugPrint('[purchase] Achat confirmé (${purchase.status}).');
          onPremiumUnlocked();
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[purchase] Erreur d\'achat: ${purchase.error}');
          onError?.call(isFr()
              ? 'L\'achat a échoué. Réessaie plus tard.'
              : 'The purchase failed. Please try again later.');
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          debugPrint('[purchase] Achat annulé par l\'utilisateur.');
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
