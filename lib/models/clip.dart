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
  /// etiquetee produit. Jamais une video (reel, short, TikTok...), meme si
  /// elle presente un produit.
  bool get isShoppingLink => toBuy && platform == 'other';

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
      );
}
