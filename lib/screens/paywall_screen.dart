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

  bool _isFr(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'fr';
  }

  String _title(BuildContext context) {
    return _isFr(context)
        ? 'Vidéos illimitées,\ncatégories illimitées'
        : 'Unlimited videos,\nunlimited categories';
  }

  String _subtitle(BuildContext context) {
    return _isFr(context)
        ? 'Tu as sauvegardé 50 vidéos. Passe à Premium pour continuer sans limite.'
        : "You've saved 50 videos. Upgrade to keep bookmarking without limits.";
  }

  String _pricePeriod(BuildContext context) {
    return _isFr(context) ? '/ an' : '/ year';
  }

  String _coffeeLine(BuildContext context) {
    return _isFr(context)
        ? 'Moins qu’un café par mois'
        : 'Less than a coffee per month';
  }

  String _buttonLabel(BuildContext context) {
    return _isFr(context) ? 'Passer à Premium' : 'Upgrade to Premium';
  }

  String _notNowLabel(BuildContext context) {
    return _isFr(context) ? 'Pas maintenant' : 'Not now';
  }

  String _renewalLabel(BuildContext context) {
    return _isFr(context)
        ? 'Renouvellement annuel · Annulable à tout moment'
        : 'Renews annually · Cancel anytime';
  }

  String _loadingPriceLabel(BuildContext context) {
    return _isFr(context) ? 'Chargement du prix…' : 'Loading price…';
  }

  @override
  Widget build(BuildContext context) {
    final isFr = _isFr(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1F),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF7C3AED,
                            ).withValues(alpha: 0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'REELR PREMIUM',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: Color(0xFFA855F7),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      _title(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      _subtitle(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _FeatureRow(
                      icon: Icons.all_inclusive_rounded,
                      title: isFr ? 'Vidéos illimitées' : 'Unlimited videos',
                      subtitle: isFr
                          ? 'Sauvegarde autant de vidéos que tu veux'
                          : 'Save as many as you want',
                    ),
                    const SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.auto_awesome_rounded,
                      title: isFr ? 'Classement IA' : 'AI classification',
                      subtitle: isFr
                          ? 'Des catégories intelligentes'
                          : 'Smart categories, always',
                    ),
                    const SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.folder_copy_rounded,
                      title: isFr
                          ? 'Catégories illimitées'
                          : 'Unlimited categories',
                      subtitle: isFr
                          ? 'Organise tes vidéos comme tu veux'
                          : 'Organize your way',
                    ),
                    const SizedBox(height: 32),

                    if (priceText == null)
                      Text(
                        _loadingPriceLabel(context),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 15,
                        ),
                      )
                    else ...[
                      Text(
                        priceText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _pricePeriod(context),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _coffeeLine(context),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isLoading
                                ? [
                                    const Color(0xFF5B4B7A),
                                    const Color(0xFF7A5B9A),
                                  ]
                                : [
                                    const Color(0xFF7C3AED),
                                    const Color(0xFFA855F7),
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : onUpgrade,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
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
                                  _buttonLabel(context),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: onClose,
                      child: Text(
                        _notNowLabel(context),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _renewalLabel(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: const Color(0xFFA855F7), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
