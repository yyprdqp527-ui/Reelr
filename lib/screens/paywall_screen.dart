import 'package:flutter/material.dart';
import '../models/legal_content.dart';
import '../services/oembed.dart' show SocialPlatform;
import '../widgets/resilient_thumbnail.dart';
import '../widgets/thumbnail_fallback.dart';
import 'legal_document_screen.dart';

/// Une vignette montree sur le paywall : celle d'un lien en attente, ou celle
/// d'un lien deja enregistre.
class PaywallThumb {
  /// Identifiant stable (id du clip, ou adresse du lien en attente).
  final String id;

  /// Adresse du lien (sert au logo de repli si l'image manque).
  final String linkUrl;

  /// Adresse de l'image, si on l'a.
  final String? url;

  /// Id du clip, pour retrouver la copie permanente de la vignette.
  final String? persistId;

  const PaywallThumb({
    required this.id,
    required this.linkUrl,
    this.url,
    this.persistId,
  });
}

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

  /// Charge les vignettes a montrer (liens en attente, sinon derniers liens
  /// enregistres). Appele une fois a l'ouverture ; l'ecran ne l'attend jamais.
  final Future<List<PaywallThumb>> Function()? loadThumbs;

  const PaywallScreen({
    super.key,
    required this.onUpgrade,
    required this.onClose,
    this.onRestore,
    this.priceText,
    this.isLoading = false,
    this.heldCount = 0,
    this.loadThumbs,
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

  /// Vignettes : null = en cours de chargement (cartes vides douces),
  /// liste vide = rien a montrer (la rangee est masquee).
  List<PaywallThumb>? _thumbs;

  @override
  void initState() {
    super.initState();
    _loadThumbs();
  }

  Future<void> _loadThumbs() async {
    final loader = widget.loadThumbs;
    if (loader == null) {
      _thumbs = const [];
      return;
    }
    try {
      final list = await loader().timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _thumbs = list.take(3).toList());
    } catch (_) {
      if (mounted) setState(() => _thumbs = const []);
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

  /// Une carte de la rangee : vraie vignette, ou carte douce en attendant.
  Widget _card(PaywallThumb? t, double sc) {
    final w = 76 * sc;
    final h = 100 * sc;
    Widget inner;
    if (t == null) {
      inner = Container(color: Colors.white.withValues(alpha: 0.08));
    } else {
      inner = ResilientThumbnail(
        key: ValueKey('pw_${t.id}'),
        url: t.url,
        cacheKeyId: t.id,
        persistId: t.persistId,
        platformId: SocialPlatform.detect(t.linkUrl).id,
        fit: BoxFit.cover,
        fallbackBuilder: (_) => ThumbnailFallback(url: t.linkUrl, compact: true),
      );
    }
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * sc),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5 * sc),
        child: inner,
      ),
    );
  }

  /// Rangee de trois cartes en eventail.
  Widget _cards(double sc) {
    final list = _thumbs;
    if (list != null && list.isEmpty) return const SizedBox.shrink();
    final n = list == null ? 3 : list.length;
    PaywallThumb? at(int i) => (list != null && i < list.length) ? list[i] : null;
    final angles = n == 1
        ? const [0.0]
        : n == 2
            ? const [-0.07, 0.07]
            : const [-0.14, 0.0, 0.14];
    final lifts = n == 3 ? const [6.0, -4.0, 6.0] : const [0.0, 0.0, 0.0];
    return Padding(
      padding: EdgeInsets.only(top: 20 * sc),
      child: SizedBox(
        height: 116 * sc,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < n; i++)
              Transform.translate(
                offset: Offset((i - (n - 1) / 2) * 68 * sc, lifts[i] * sc),
                child: Transform.rotate(angle: angles[i], child: _card(at(i), sc)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _check(String text, double sc) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * sc),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✓', style: TextStyle(color: _pwSun, fontSize: 17 * sc, fontWeight: FontWeight.w900)),
          SizedBox(width: 9 * sc),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Figtree',
              color: const Color(0xFFD7D4F6),
              fontSize: 15.5 * sc,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fr = _isFr(context);
    final sc = (MediaQuery.sizeOf(context).height / 844).clamp(0.78, 1.0).toDouble();

    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, child: w);

    final top = Column(
      children: [
        Text(
          fr
              ? 'Tu as utilisé tes 50 sauvegardes gratuites\n(même celles supprimées).'
              : 'You’ve used your 50 free saves\n(deleted ones count too).',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Figtree',
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 13.5 * sc,
            fontWeight: FontWeight.w800,
            height: 1.45,
          ),
        ),
        SizedBox(height: 26 * sc),
        // Slogan comme sur myreelr.app : « Mets tout dans » puis le logo.
        fit(Text(
          fr ? 'Mets tout dans' : 'Put it all in',
          style: TextStyle(
            fontFamily: 'Figtree',
            color: Colors.white,
            fontSize: 46 * sc,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.1 * sc,
            height: 1.0,
          ),
        )),
        SizedBox(height: 4 * sc),
        Image.asset(
          'assets/onboarding/reelr-wordmark.png',
          height: 44 * sc,
          fit: BoxFit.contain,
        ),
        SizedBox(height: 14 * sc),
        fit(Text(
          fr ? 'Ne perds plus rien' : 'Never lose a thing',
          style: TextStyle(
            fontFamily: 'Figtree',
            color: Colors.white,
            fontSize: 23 * sc,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        )),
        SizedBox(height: 14 * sc),
        _check(fr ? 'Sauvegardes illimitées' : 'Unlimited saves', sc),
        _check(fr ? 'Tri automatique' : 'Automatic sorting', sc),
        _check(fr ? 'Retrouve tout en 2 secondes' : 'Find anything in 2 seconds', sc),
        _cards(sc),
        if (widget.heldCount > 0) ...[
          SizedBox(height: 10 * sc),
          Text.rich(
            TextSpan(
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13 * sc, height: 1.4),
              children: [
                TextSpan(
                  text: _heldBold(fr),
                  style: TextStyle(color: _pwSun, fontWeight: FontWeight.w800, fontSize: 14 * sc),
                ),
                TextSpan(text: '\n${_heldRest(fr)}'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            widget.priceText!,
            style: TextStyle(
              fontFamily: 'Figtree',
              color: Colors.white,
              fontSize: 36 * sc,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fr ? 'par an · moins d’un café par mois' : 'per year · less than a coffee a month',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 13),
          ),
        ],
        SizedBox(height: 16 * sc),
        // Bouton d'achat
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: _upgradeBlocked ? _pwSun.withValues(alpha: 0.55) : _pwSun,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onTap: _upgradeBlocked ? null : () => _run(widget.onUpgrade),
              child: Center(
                child: _upgradeBlocked
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1651)),
                        ),
                      )
                    : Text(
                        fr ? 'Tout garder' : 'Keep everything',
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          color: Color(0xFF1A1651),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fr ? 'Résiliable à tout moment' : 'Cancel anytime',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: Text(
                fr ? 'Pas maintenant' : 'Not now',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.onRestore != null)
              TextButton(
                onPressed: _busy ? null : () => _run(widget.onRestore!),
                child: Text(
                  fr ? 'Restaurer mes achats' : 'Restore purchases',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        Text(
          fr ? 'Renouvellement automatique annuel' : 'Renews automatically every year',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 4),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                        children: [
                          SizedBox(height: 36 * sc),
                          top,
                          SizedBox(height: 22 * sc),
                          bottom,
                        ],
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
        ],
      ),
    );
  }
}

const Color _pwBg = Color(0xFF1A1651);
const Color _pwSun = Color(0xFFE6E98A);

/// Lueurs bleues du site (mêmes que l'onboarding).
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
          Positioned(top: -190, left: -200, child: _halo(const Color(0xFF2B43F4), 520, 0.62)),
          Positioned(top: 400, right: -240, child: _halo(const Color(0xFF12C2DA), 440, 0.30)),
          Positioned(bottom: -240, left: -60, child: _halo(const Color(0xFF2B43F4), 520, 0.40)),
        ],
      ),
    );
  }
}
