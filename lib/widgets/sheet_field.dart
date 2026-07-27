import 'package:flutter/material.dart';

import '../core/theme.dart';

class SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final ValueChanged<String>? onChanged;
  final Widget? prefixWidget;
  final TextCapitalization textCapitalization;

  const SheetField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.onChanged,
    this.prefixWidget,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Mode clair : surface gris-bleu opaque, cohérente avec le reste de
        // l'app (au lieu d'un violet translucide hors identité). Mode
        // sombre : inchangé.
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : AppTheme.lightSearchSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          if (prefixWidget != null) ...[
            const SizedBox(width: 12),
            prefixWidget!,
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? Colors.grey : AppTheme.lightIconSecondary,
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textCapitalization: textCapitalization,
              style: TextStyle(color: isDark ? null : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: isDark ? null : AppTheme.lightPlaceholder),
                // Neutralise explicitement tous les états de bordure (pas
                // seulement `border`) : sinon `enabledBorder`/`focusedBorder`
                // du thème global (AppTheme.inputDecorationTheme) prennent
                // le dessus et dessinent un second cadre à l'intérieur de
                // celui du Container ci-dessus.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
