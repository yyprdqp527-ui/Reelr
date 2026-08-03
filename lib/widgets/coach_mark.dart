import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

// ─────────────────────────────────────────────
// COACH MARK — bulle d'aide contextuelle harmonisée
// ─────────────────────────────────────────────
//
// Composant unique et réutilisable pour toutes les explications de
// première utilisation de Reelr (coach marks). Une seule bulle visible
// à la fois, ancrée visuellement à l'élément qu'elle explique, mémorisée
// via SharedPreferences (indépendamment de la langue), respectant la
// SafeArea, Dynamic Type et Reduce Motion.
//
// Ne pas dupliquer ce composant pour une nouvelle explication : ajouter
// simplement un nouvel appel à [CoachMark.showOnce] avec sa propre clé
// de mémorisation et son propre texte localisé.

enum CoachMarkSide { above, below }

class CoachMark {
  CoachMark._();

  static bool _visible = false;

  /// Affiche une bulle ancrée sur [anchorKey], une seule fois par
  /// utilisateur/installation. Ne fait rien si :
  /// - la bulle a déjà été vue (mémorisée sous [prefsKey]) ;
  /// - une autre bulle est déjà affichée à l'écran ;
  /// - l'ancre n'est pas (ou plus) montée à l'écran.
  ///
  /// Retourne `true` si la bulle a effectivement été affichée (utile pour
  /// les appelants qui gèrent un état "en attente d'affichage" en plus du
  /// simple flag "déjà vue").
  static Future<bool> showOnce({
    required BuildContext context,
    required String prefsKey,
    required GlobalKey anchorKey,
    required String message,
    required String dismissLabel,
    CoachMarkSide preferredSide = CoachMarkSide.below,
  }) async {
    if (_visible) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) ?? false) return false;
    if (!context.mounted) return false;

    final renderObject = anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

    _visible = true;
    late OverlayEntry entry;

    Future<void> dismiss() async {
      if (!_visible) return;
      _visible = false;
      entry.remove();
      await prefs.setBool(prefsKey, true);
    }

    entry = OverlayEntry(
      builder: (overlayContext) => _CoachMarkOverlay(
        anchorBox: renderObject,
        message: message,
        dismissLabel: dismissLabel,
        preferredSide: preferredSide,
        onDismiss: dismiss,
      ),
    );
    overlay.insert(entry);
    return true;
  }
}

class _CoachMarkOverlay extends StatefulWidget {
  final RenderBox anchorBox;
  final String message;
  final String dismissLabel;
  final CoachMarkSide preferredSide;
  final Future<void> Function() onDismiss;

  const _CoachMarkOverlay({
    required this.anchorBox,
    required this.message,
    required this.dismissLabel,
    required this.preferredSide,
    required this.onDismiss,
  });

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _controller.forward(from: reduceMotion ? 1.0 : 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.anchorBox.attached) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final safePadding = mq.padding;

    final anchorTopLeft = widget.anchorBox.localToGlobal(Offset.zero);
    final anchorSize = widget.anchorBox.size;
    final anchorRect = anchorTopLeft & anchorSize;

    const horizontalMargin = 16.0;
    const bubbleMaxWidth = 320.0;
    const arrowSize = 10.0;
    const gap = 12.0;

    final maxWidth =
        (screenSize.width - horizontalMargin * 2).clamp(0.0, bubbleMaxWidth);

    final spaceBelow = screenSize.height - safePadding.bottom - anchorRect.bottom;
    final spaceAbove = anchorRect.top - safePadding.top;
    final preferBelow = widget.preferredSide == CoachMarkSide.below;
    // Bascule automatiquement de côté si la place manque, sans jamais
    // dépasser l'écran ni chevaucher la SafeArea (Dynamic Island / Home
    // Indicator).
    final showBelow = preferBelow
        ? spaceBelow >= 120 || spaceBelow >= spaceAbove
        : !(spaceAbove >= 120 || spaceAbove >= spaceBelow);

    double left = anchorRect.center.dx - maxWidth / 2;
    left = left.clamp(
      horizontalMargin,
      (screenSize.width - horizontalMargin - maxWidth).clamp(horizontalMargin, screenSize.width),
    );
    final arrowCenterX =
        (anchorRect.center.dx - left).clamp(20.0, (maxWidth - 20.0).clamp(20.0, maxWidth));

    final bubble = _CoachMarkBubble(
      message: widget.message,
      dismissLabel: widget.dismissLabel,
      isDark: isDark,
      maxWidth: maxWidth,
      arrowCenterX: arrowCenterX,
      arrowSize: arrowSize,
      arrowOnTop: !showBelow,
      onDismiss: widget.onDismiss,
    );

    final animated = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(
          scale: _scale.value,
          alignment: showBelow ? Alignment.topCenter : Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: bubble,
    );

    return Positioned.fill(
      child: Stack(
        children: [
          // Barrière transparente : capte le tap en dehors de la bulle
          // pour la fermer sans jamais laisser le geste atteindre
          // l'interface située derrière (aucune action accidentelle).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onDismiss(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: showBelow ? anchorRect.bottom + gap : null,
            bottom: showBelow ? null : screenSize.height - anchorRect.top + gap,
            width: maxWidth,
            child: Semantics(
              container: true,
              liveRegion: true,
              child: animated,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachMarkBubble extends StatelessWidget {
  final String message;
  final String dismissLabel;
  final bool isDark;
  final double maxWidth;
  final double arrowCenterX;
  final double arrowSize;
  final bool arrowOnTop;
  final Future<void> Function() onDismiss;

  const _CoachMarkBubble({
    required this.message,
    required this.dismissLabel,
    required this.isDark,
    required this.maxWidth,
    required this.arrowCenterX,
    required this.arrowSize,
    required this.arrowOnTop,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppTheme.surfaceElevated.withValues(alpha: 0.97)
        : AppTheme.lightSurface(alpha: 0.96);
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final arrow = Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: arrowSize,
        height: arrowSize,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1),
        ),
      ),
    );

    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            maxLines: 4,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: TextButton(
              onPressed: () => onDismiss(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.lightBlue,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                dismissLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );

    final arrowPositioned = Positioned(
      left: (arrowCenterX - arrowSize / 2).clamp(12.0, maxWidth - arrowSize - 12.0),
      top: arrowOnTop ? null : -arrowSize / 2,
      bottom: arrowOnTop ? -arrowSize / 2 : null,
      child: arrow,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          arrowPositioned,
        ],
      ),
    );
  }
}
