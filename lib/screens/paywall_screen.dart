import 'package:flutter/material.dart';

/// Shown when a free user reaches the saved-videos limit.
class PaywallScreen extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onClose;
  final String? priceText;
  final bool isLoading;

  const PaywallScreen({
    super.key,
    required this.onUpgrade,
    required this.onClose,
    this.priceText,
    this.isLoading = false,
  });

  String _upgradeLabel(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    if (priceText == null) {
      return isFr ? 'Passer à Premium' : 'Upgrade to Premium';
    }

    return isFr
        ? 'Passer à Premium — $priceText/an'
        : 'Upgrade to Premium — $priceText/year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onClose,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.workspace_premium,
                size: 64,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 24),
              Text(
                Localizations.localeOf(context).languageCode == 'fr'
                    ? 'Tu as atteint ta limite gratuite'
                    : "You've reached your free limit",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                Localizations.localeOf(context).languageCode == 'fr'
                    ? 'Reelr Free te permet de sauvegarder jusqu\'à 50 vidéos. Passe à Reelr Premium pour des vidéos et des catégories illimitées.'
                    : 'Reelr Free lets you save up to 50 videos. Upgrade to Reelr Premium for unlimited videos and unlimited categories.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF6D48C4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _upgradeLabel(context),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClose,
                child: Text(
                  Localizations.localeOf(context).languageCode == 'fr'
                      ? 'Pas maintenant'
                      : 'Not now',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
