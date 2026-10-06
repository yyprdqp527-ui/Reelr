import 'package:flutter/material.dart';
import '../models/legal_content.dart';
import 'legal_document_screen.dart';

/// Shown when a free user reaches the saved-videos limit.
class PaywallScreen extends StatefulWidget {
  /// Doit rester en vol tant que StoreKit n'a pas tranche : l'ecran affiche
  /// un indicateur pendant toute la duree de ce Future.
  final Future<void> Function() onUpgrade;

  /// Restauration d'un abonnement deja paye (nouvel appareil, reinstallation).
  /// Exige par la guideline Apple 3.1.1 sur l'ecran qui propose l'achat.
  final Future<void> Function()? onRestore;

  final VoidCallback onClose;
  final String? priceText;
  final bool isLoading;

  /// Liens partages gardes en attente par la limite gratuite. Affiches
  /// sur l'ecran pour que l'utilisatrice sache qu'ils ne sont pas perdus.
  final int heldCount;

  const PaywallScreen({
    super.key,
    required this.onUpgrade,
    required this.onClose,
    this.onRestore,
    this.priceText,
    this.isLoading = false,
    this.heldCount = 0,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  /// Achat ou restauration en cours. Sans cet etat, le tap sur « Passer a
  /// Premium » ne produisait aucun retour visuel pendant les secondes ou
  /// StoreKit prepare sa feuille de paiement : l'ecran paraissait mort et
  /// l'utilisateur retapait, empilant des addPayment en double.
  bool _busy = false;

  /// Le bouton d'achat est inerte tant que le prix n'est pas charge ou
  /// qu'une operation est en vol.
  bool get _upgradeBlocked => widget.isLoading || _busy;

  /// Bandeau « X liens t'attendent » : glisse depuis le haut à l'ouverture
  /// (seulement s'il y a des liens en attente), et se ferme avec la croix.
  bool _popOn = false;
  bool _popClosed = false;

  @override
  void initState() {
    super.initState();
    if (widget.heldCount > 0) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _popOn = true);
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      // L'ecran peut avoir ete ferme entre-temps (achat reussi : le paywall
      // se retire tout seul), d'ou le garde-fou avant setState.
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isFr(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'fr';
  }


  String _heldBold(bool fr) {
    final n = widget.heldCount;
    if (fr) return n == 1 ? '1 lien t’attend.' : '$n liens t’attendent.';
    return n == 1 ? '1 link is waiting.' : '$n links are waiting.';
  }

  String _heldRest(bool fr) {
    final one = widget.heldCount == 1;
    if (fr) {
      return one
          ? 'Il sera ajouté dès que tu passes à Premium.'
          : 'Ils seront ajoutés dès que tu passes à Premium.';
    }
    return one
        ? 'It will be added as soon as you upgrade.'
        : 'They will be added as soon as you upgrade.';
  }

  @override
  Widget build(BuildContext context) {
    final fr = _isFr(context);
    final sc = (MediaQuery.sizeOf(context).height / 844).clamp(0.78, 1.0).toDouble();
    final showPop = widget.heldCount > 0 && _popOn && !_popClosed;

    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, child: w);

    final top = Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          height: showPop ? 104 * sc : 36 * sc,
        ),
        // Logo
        Container(
          width: 72 * sc,
          height: 72 * sc,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20 * sc),
            border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.7), blurRadius: 30),
              BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.5), blurRadius: 60),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20 * sc),
            child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: 12 * sc),
        _PwGradText(
          'Reelr',
          TextStyle(fontSize: 40 * sc, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1),
        ),
        SizedBox(height: 26 * sc),
        fit(Text(
          fr ? 'Ne perds plus rien.' : 'Never lose a thing.',
          style: TextStyle(color: Colors.white, fontSize: 27 * sc, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        )),
        SizedBox(height: 4 * sc),
        fit(Text(
          fr ? 'Mets tout dans Reelr.' : 'Drop it all in Reelr.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 21 * sc,
            fontWeight: FontWeight.w600,
          ),
        )),
        SizedBox(height: 16 * sc),
        fit(Text.rich(
          TextSpan(
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16.5 * sc, height: 1.45),
            children: [
              TextSpan(
                text: fr
                    ? 'Pour moins d’un café par mois,\ntu peux tout garder '
                    : 'For less than a coffee a month,\nkeep everything ',
              ),
              TextSpan(
                text: fr ? 'en illimité' : 'unlimited',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  foreground: Paint()..shader = _pwGradient.createShader(const Rect.fromLTWH(0, 0, 200, 30)),
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        )),
        SizedBox(height: 30 * sc),
        fit(Text.rich(
          TextSpan(
            style: TextStyle(color: Colors.white, fontSize: 30 * sc, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.6),
            children: [
              TextSpan(
                text: 'Reelr',
                style: TextStyle(
                  foreground: Paint()..shader = _pwGradient.createShader(const Rect.fromLTWH(0, 0, 90, 38)),
                ),
              ),
              TextSpan(
                text: fr
                    ? ' un endroit pour tout\nce qui compte pour toi.'
                    : ', one place for everything\nthat matters to you.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
        )),
        SizedBox(height: 14 * sc),
        fit(Text(
          fr
              ? 'Tu as utilisé tes 50 sauvegardes gratuites\n(même celles supprimées).'
              : 'You’ve used your 50 free saves\n(deleted ones count too).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5 * sc, height: 1.45),
        )),
      ],
    );

    final bottom = Column(
      children: [
        if (widget.priceText == null)
          Text(
            fr ? 'Chargement du prix…' : 'Loading price…',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
          )
        else ...[
          Text(
            'Reelr Premium',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14 * sc),
          ),
          const SizedBox(height: 2),
          Text(
            widget.priceText!,
            style: TextStyle(color: Colors.white, fontSize: 34 * sc, fontWeight: FontWeight.w600, height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            fr ? 'par an' : 'per year',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14 * sc),
          ),
        ],
        SizedBox(height: 22 * sc),
        // Bouton d'achat
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _upgradeBlocked
                  ? const [Color(0xFF5B4B7A), Color(0xFF7A5B9A)]
                  : const [Color(0xFF7C3AED), Color(0xFFA855F7)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _upgradeBlocked ? null : () => _run(widget.onUpgrade),
              child: Center(
                child: _upgradeBlocked
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        fr ? 'Je passe à Premium' : 'Upgrade to Premium',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: Text(
                fr ? 'Pas maintenant' : 'Not now',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
              ),
            ),
            if (widget.onRestore != null)
              TextButton(
                onPressed: _busy ? null : () => _run(widget.onRestore!),
                child: Text(
                  fr ? 'Restaurer mes achats' : 'Restore purchases',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        Text(
          fr
              ? 'Renouvellement automatique annuel · Résiliable à tout moment'
              : 'Renews automatically every year · Cancel anytime',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LegalDocumentScreen(
                    title: fr ? 'Politique de confidentialité' : 'Privacy Policy',
                    content: fr ? legalPrivacyPolicyFr : legalPrivacyPolicyEn,
                  ),
                ),
              ),
              child: Text(
                fr ? 'Politique de confidentialité' : 'Privacy Policy',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LegalDocumentScreen(
                    title: fr ? 'Conditions d’utilisation' : 'Terms of Use',
                    content: fr ? legalTermsFr : legalTermsEn,
                  ),
                ),
              ),
              child: Text(
                fr ? 'Conditions d’utilisation' : 'Terms of Use',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );

    return Scaffold(
      backgroundColor: _pwBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _PwGlow()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [top, SizedBox(height: 24 * sc), bottom],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bouton fermer
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6), size: 18),
                  ),
                ),
              ),
            ),
          ),
          // Bandeau « liens en attente »
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            top: showPop ? MediaQuery.paddingOf(context).top + 10 : -220,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: const Color(0xF514182B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _pwLilac, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10)),
                  BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), blurRadius: 18),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: _pwLilac, shape: BoxShape.circle),
                    child: Text(
                      '${widget.heldCount}',
                      style: const TextStyle(color: Color(0xFF0B1440), fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                        children: [
                          TextSpan(text: _heldBold(fr), style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: '\n${_heldRest(fr)}'),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _popClosed = true),
                    icon: Icon(Icons.close, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Color _pwBg = Color(0xFF0B0820);
const Color _pwLilac = Color(0xFFA78BFA);
const LinearGradient _pwGradient = LinearGradient(
  colors: [Color(0xFF8B5CF6), Color(0xFF2563EB), Color(0xFF22D3EE)],
  stops: [0.0, 0.6, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Texte au dégradé du logo.
class _PwGradText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _PwGradText(this.text, this.style);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _pwGradient.createShader(bounds),
      child: Text(text, textAlign: TextAlign.center, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Halos violets (mêmes que l'onboarding).
class _PwGlow extends StatelessWidget {
  const _PwGlow();

  Widget _halo(Color c, double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(top: -160, right: -180, child: _halo(const Color(0xFF6D28D9), 460, 0.45)),
          Positioned(top: 240, left: -230, child: _halo(const Color(0xFF312E81), 420, 0.6)),
          Positioned(top: 420, right: -220, child: _halo(_pwLilac, 360, 0.22)),
          Positioned(bottom: -230, left: -40, child: _halo(const Color(0xFF4C1D95), 480, 0.5)),
        ],
      ),
    );
  }
}
