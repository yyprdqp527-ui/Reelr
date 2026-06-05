import 'package:flutter/material.dart';

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
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color.fromRGBO(235, 228, 255, 0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color.fromRGBO(200, 185, 255, 0.40),
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
              child: Icon(icon, size: 20, color: Colors.grey),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textCapitalization: textCapitalization,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
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
