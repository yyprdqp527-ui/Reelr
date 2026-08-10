// Modèle — copier en secrets.dart et remplir les valeurs.
//
// Seules les deux premières sont nécessaires au fonctionnement de l'app :
// tous les appels à Claude et le proxy de vignettes passent par le Worker
// Cloudflare, qui détient les vraies clés côté serveur.
//
// Les identifiants de plateforme sont optionnels. Laissés vides, l'app
// retombe sur le scraping OpenGraph, qui fonctionne aujourd'hui pour
// TikTok, Instagram, Facebook, LinkedIn, Pinterest et Twitch. Ne les
// remplissez que si vous constatez une extraction insuffisante.
//
// ATTENTION : ce fichier est compilé dans le binaire de l'application et
// ses valeurs sont extractibles. N'y mettez jamais une clé facturée à
// l'usage (Anthropic, OpenAI…) : elle doit rester dans le Worker.
class Secrets {
  /// URL du Worker Cloudflare, terminée par /v1/messages.
  static const String reelrProxyUrl = 'https://…workers.dev/v1/messages';

  /// Secret partagé exigé par le Worker (en-tête x-reelr-secret).
  static const String appSharedSecret = 'VOTRE_SECRET_PARTAGE';

  /// Optionnel — oEmbed Instagram officiel. Sans lui, repli OpenGraph.
  static const String instagramAccessToken = '';

  /// Optionnel — API Helix de Twitch. Sans eux, repli OpenGraph.
  /// À créer sur dev.twitch.tv/console si besoin.
  static const String twitchClientId = '';
  static const String twitchAccessToken = '';
}
