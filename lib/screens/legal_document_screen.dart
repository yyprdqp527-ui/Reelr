import 'package:flutter/material.dart';

/// Écran générique pour afficher un document légal (Privacy Policy, CGU/CGV)
/// directement dans l'application, sans dépendre d'une URL externe.
///
/// Le contenu est passé en paramètre sous forme de texte avec une syntaxe
/// markdown minimale :
///   - une ligne commençant par "# " est un titre principal
///   - une ligne commençant par "## " est un sous-titre
///   - une ligne commençant par "### " est un sous-sous-titre
///   - une ligne entourée de "**...**" est mise en gras
///   - une ligne commençant par "- " est un item de liste
///   - les lignes vides créent un espacement entre paragraphes
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.content,
  });

  List<Widget> _buildBlocks(BuildContext context) {
    final lines = content.split('\n');
    final blocks = <Widget>[];
    final theme = Theme.of(context);

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 12));
        continue;
      }
      if (line.startsWith('# ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            line.substring(2),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
        ));
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 14),
          child: Text(
            line.substring(3),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ));
        continue;
      }
      if (line.startsWith('### ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 10),
          child: Text(
            line.substring(4),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ));
        continue;
      }
      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line.substring(2, line.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ));
        continue;
      }
      if (line.startsWith('- ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\u2022  ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(line.substring(2),
                    style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
            ],
          ),
        ));
        continue;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          line,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ));
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildBlocks(context),
          ),
        ),
      ),
    );
  }
}
