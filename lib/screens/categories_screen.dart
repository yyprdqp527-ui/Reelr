import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/l10n.dart';
import '../models/category.dart';
import '../state/clips_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/sheet_field.dart';

// ─────────────────────────────────────────────
// EDIT CATEGORY SHEET
// ─────────────────────────────────────────────

class EditCategorySheet extends StatefulWidget {
  final ClipCategory category;
  final ClipsState state;

  const EditCategorySheet({
    super.key,
    required this.category,
    required this.state,
  });

  @override
  State<EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<EditCategorySheet> {
  late final TextEditingController _nameCtrl;
  late Color _color;
  late IconData _icon;

  static const _colors = [
    Color(0xFF4F8EF7),
    Color(0xFFFF5252),
    Color(0xFF2ECC71),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFFFFB300),
    Color(0xFF009688),
    Color(0xFF3F51B5),
  ];

  static const _icons = [
    Icons.folder_rounded,
    Icons.star_rounded,
    Icons.bookmark_rounded,
    Icons.favorite_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.movie_rounded,
    Icons.restaurant_rounded,
    Icons.travel_explore_rounded,
    Icons.science_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category.name);
    _color = widget.category.color;
    _icon = widget.category.icon;
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final updated = ClipCategory(
      id: widget.category.id,
      name: _nameCtrl.text.trim(),
      color: _color,
      icon: _icon,
    );
    await widget.state.updateCategory(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      l.t('edit_category'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    SheetField(
                      controller: _nameCtrl,
                      hint: l.t('category_name'),
                      icon: Icons.label_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),
                    Text(l.t('color'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: _colors
                          .map((c) => GestureDetector(
                                onTap: () => setState(() => _color = c),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _color == c
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: _color == c
                                        ? [
                                            BoxShadow(
                                                color: c.withValues(alpha: 0.5),
                                                blurRadius: 8)
                                          ]
                                        : [],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(l.t('icon'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _icons
                          .map((ic) => GestureDetector(
                                onTap: () => setState(() => _icon = ic),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _icon == ic
                                        ? _color.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _icon == ic
                                          ? _color
                                          : Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    ic,
                                    size: 20,
                                    color: _icon == ic ? _color : Colors.grey,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l.t('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l.t('save')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORIES SCREEN
// ─────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  final ClipsState state;

  const CategoriesScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              l.t('categories'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.5),
            ),
            actions: [
              const SizedBox(width: 8),
            ],
          ),
          if (state.categories.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  l.t('no_category'),
                  style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.5), fontSize: 16),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final cat = state.categories[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(cat.icon,
                                  color: cat.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  ),
                                  Builder(builder: (bctx) {
                                    final subs =
                                        state.getSubCategoriesFor(cat.id);
                                    if (subs.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        '${subs.length} sous-cat.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cat.color
                                              .withValues(alpha: 0.75),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _showEditSheet(context, cat),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline_rounded),
                              color: Colors.red.withValues(alpha: 0.75),
                              onPressed: () =>
                                  _confirmDelete(context, cat.id, l),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: state.categories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, ClipCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCategorySheet(category: cat, state: state),
    );
  }

  void _confirmDelete(BuildContext context, String id, AppL10n l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.t('confirm_delete')),
        content: Text(l.t('confirm_delete_sub')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              state.removeCategory(id);
              Navigator.pop(ctx);
            },
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD CATEGORY DIALOG
// ─────────────────────────────────────────────

class AddCategoryDialog extends StatefulWidget {
  final ClipsState state;

  const AddCategoryDialog({super.key, required this.state});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameCtrl = TextEditingController();
  Color _color = const Color(0xFF4F8EF7);
  IconData _icon = Icons.folder_rounded;

  static const _colors = [
    Color(0xFF4F8EF7),
    Color(0xFFFF5252),
    Color(0xFF2ECC71),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFFFFB300),
    Color(0xFF009688),
    Color(0xFF3F51B5),
  ];

  static const _icons = [
    Icons.folder_rounded,
    Icons.star_rounded,
    Icons.bookmark_rounded,
    Icons.favorite_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.movie_rounded,
    Icons.restaurant_rounded,
    Icons.travel_explore_rounded,
    Icons.science_rounded,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.t('new_category')),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l.t('category_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Text(l.t('color'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _colors
                    .map((c) => GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: _color == c
                                  ? [
                                      BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(l.t('icon'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons
                    .map((ic) => GestureDetector(
                          onTap: () => setState(() => _icon = ic),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _icon == ic
                                  ? _color.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _icon == ic
                                    ? _color
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              ic,
                              size: 20,
                              color: _icon == ic ? _color : Colors.grey,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.t('cancel'))),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            widget.state.addCategory(ClipCategory(
              id: const Uuid().v4(),
              name: _nameCtrl.text.trim(),
              color: _color,
              icon: _icon,
            ));
            Navigator.pop(context);
          },
          child: Text(l.t('save')),
        ),
      ],
    );
  }
}

