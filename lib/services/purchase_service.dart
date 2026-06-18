import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Service responsable de l'achat et de la restauration de l'abonnement
/// Reelr Premium via StoreKit (App Store).
class PurchaseService {
  static const String premiumYearlyId = 'com.reelr.app.premium.yearly';

  final VoidCallback onPremiumUnlocked;
  final void Function(String message)? onError;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool isAvailable = false;
  ProductDetails? premiumProduct;
  bool isLoadingProduct = false;

  PurchaseService({required this.onPremiumUnlocked, this.onError});

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
        onError?.call('Erreur du service d\'achat. Réessaie plus tard.');
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
      onError?.call('Les achats ne sont pas disponibles sur cet appareil.');
      return false;
    }
    final product = premiumProduct;
    if (product == null) {
      onError?.call('Produit indisponible pour le moment. Réessaie dans un instant.');
      return false;
    }
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[purchase] Exception lors de buyNonConsumable: $e');
      onError?.call('Achat impossible. Réessaie plus tard.');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!isAvailable) {
      onError?.call('Les achats ne sont pas disponibles sur cet appareil.');
      return;
    }
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[purchase] Exception lors de restorePurchases: $e');
      onError?.call('Restauration impossible. Réessaie plus tard.');
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
          onError?.call('L\'achat a échoué. Réessaie plus tard.');
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
