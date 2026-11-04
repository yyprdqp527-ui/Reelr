class Clip {
  final String id;
  final String url;
  final String title;
  final String platform;
  final String? categoryId;
  final List<String> tags;
  final DateTime addedAt;
  final String? thumbnailUrl;
  final int position;
  final String? channel;

  /// Description publique de la vidéo, récupérée à l'hydratation (oEmbed ou
  /// og:description). Stockée uniquement pour être relue par le classifieur :
  /// sans elle, la description était refetchée puis jetée entre l'hydratation
  /// et la classification. Aucun affichage ne s'en sert.
  final String? description;

  /// Etiquette « a acheter » : le lien montre un produit qu'on peut acheter.
  /// Transversale aux tuiles. Lue par `fromMap`, jamais ecrite par `toMap`
  /// (colonne `toBuy` geree par `DatabaseHelper.setClipToBuy`).
  final bool toBuy;

  /// Lien commercial a montrer dans le panier « a acheter » : une PAGE WEB
  /// ou une EPINGLE PINTEREST etiquetee produit (2026-11-04 : une epingle
  /// est une image de produit, pas une video). Jamais une video (reel,
  /// short, TikTok...), meme si elle presente un produit.
  bool get isShoppingLink => toBuy && Clip.canBeShopping(platform);

  /// Plateformes qui peuvent recevoir le panier « a acheter ».
  static bool canBeShopping(String platform) =>
      platform == 'other' || platform == 'pinterest';

  /// Deux categories proposees pour un lien laisse « a trier » (IDs cat_xxx).
  /// Lu par `fromMap`, jamais ecrit par `toMap` (colonne `classification_alt`).
  final List<String> candidates;

  /// Titre choisi par le client. Le titre d'origine (`title`) n'est jamais
  /// modifie : la recherche porte sur les deux. Lu par `fromMap`, jamais ecrit
  /// par `toMap` (colonne `customTitle` geree par
  /// `DatabaseHelper.setClipCustomTitle`), comme `toBuy`.
  final String? customTitle;

  /// Titre a afficher : celui du client s'il existe, sinon l'original.
  String get displayTitle {
    final t = customTitle?.trim();
    return (t != null && t.isNotEmpty) ? t : title;
  }

  const Clip({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    this.categoryId,
    required this.tags,
    required this.addedAt,
    this.thumbnailUrl,
    this.position = 0,
    this.channel,
    this.description,
    this.toBuy = false,
    this.candidates = const [],
    this.customTitle,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'title': title,
        'platform': platform,
        'categoryId': categoryId,
        'tags': tags.join(','),
        'addedAt': addedAt.toIso8601String(),
        'thumbnailUrl': thumbnailUrl,
        'position': position,
        'channel': channel,
        'description': description,
      };

  factory Clip.fromMap(Map<String, dynamic> map) => Clip(
        id: map['id'] as String,
        url: map['url'] as String,
        title: map['title'] as String,
        platform: map['platform'] as String,
        categoryId: map['categoryId'] as String?,
        tags: (map['tags'] as String? ?? '').isEmpty
            ? []
            : (map['tags'] as String)
                .split(',')
                .where((t) => t.isNotEmpty)
                .toList(),
        addedAt: DateTime.parse(map['addedAt'] as String),
        thumbnailUrl: map['thumbnailUrl'] as String?,
        position: (map['position'] as int?) ?? 0,
        channel: map['channel'] as String?,
        description: map['description'] as String?,
        toBuy: (map['toBuy'] as int?) == 1,
        customTitle: map['customTitle'] as String?,
        candidates: ((map['classification_alt'] as String?) ?? '')
            .split(',')
            .where((c) => c.isNotEmpty)
            .toList(),
      );

  Clip copyWith({String? categoryId, int? position, bool? toBuy}) => Clip(
        id: id,
        url: url,
        title: title,
        platform: platform,
        categoryId: categoryId ?? this.categoryId,
        tags: tags,
        addedAt: addedAt,
        thumbnailUrl: thumbnailUrl,
        position: position ?? this.position,
        channel: channel,
        description: description,
        toBuy: toBuy ?? this.toBuy,
        candidates: candidates,
        customTitle: customTitle,
      );

  /// Copie avec un autre titre personnalise (`null` = revenir a l'original).
  Clip withCustomTitle(String? value) => Clip(
        id: id,
        url: url,
        title: title,
        platform: platform,
        categoryId: categoryId,
        tags: tags,
        addedAt: addedAt,
        thumbnailUrl: thumbnailUrl,
        position: position,
        channel: channel,
        description: description,
        toBuy: toBuy,
        candidates: candidates,
        customTitle: value,
      );
}
