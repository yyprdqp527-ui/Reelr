import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/state/clips_state.dart';

String n(String url) => ClipsState.normalizeUrlForDedup(url);

void same(String a, String b) =>
    expect(n(a), n(b), reason: 'doublon non detecte :\n  $a\n  $b');

void different(String a, String b) =>
    expect(n(a) == n(b), isFalse, reason: 'faux doublon :\n  $a\n  $b');

void main() {
  test('YouTube : watch, youtu.be, shorts, live, tracking', () {
    const id = 'dQw4w9WgXcQ';
    same('https://www.youtube.com/watch?v=$id', 'https://youtu.be/$id?si=abc');
    same('https://youtu.be/$id', 'https://m.youtube.com/watch?v=$id&feature=share');
    same('https://www.youtube.com/shorts/$id', 'https://youtu.be/$id');
    same('https://www.youtube.com/live/$id?si=x', 'https://youtu.be/$id');
    different('https://youtu.be/$id', 'https://youtu.be/aaaaaaaaaaa');
  });

  test('TikTok : parametres de partage', () {
    same('https://www.tiktok.com/@a/video/7401?is_from_webapp=1&_r=1',
        'https://www.tiktok.com/@a/video/7401');
  });

  test('Instagram : reel, reels, p, tv, tracking', () {
    same('https://www.instagram.com/reel/C8abc/?igsh=xyz',
        'https://www.instagram.com/reels/C8abc/');
    same('https://www.instagram.com/p/C8abc/', 'https://instagram.com/reel/C8abc');
    same('https://www.instagram.com/tv/C8abc/', 'https://instagram.com/p/C8abc');
  });

  test('Reddit : share_id different a chaque partage', () {
    same(
      'https://www.reddit.com/r/whatisit/comments/1wnoawu/found/?share_id=AAA&utm_source=share',
      'https://www.reddit.com/r/whatisit/comments/1wnoawu/found/?share_id=BBB',
    );
    same('https://old.reddit.com/r/x/comments/1wnoawu/', 'https://redd.it/1wnoawu');
  });

  test('Facebook : reel, watch, videos', () {
    same('https://www.facebook.com/reel/123456/?mibextid=abc',
        'https://m.facebook.com/reel/123456');
    same('https://www.facebook.com/watch/?v=987', 'https://www.facebook.com/page/videos/987/');
  });

  test('Twitch et X', () {
    same('https://clips.twitch.tv/FunnyClipSlug',
        'https://www.twitch.tv/streamer/clip/FunnyClipSlug?filter=clips');
    same('https://x.com/user/status/1799', 'https://twitter.com/user/status/1799?s=20');
  });

  test('Pinterest : sous-domaines de langue', () {
    same('https://fr.pinterest.com/pin/335518241006685788/',
        'https://www.pinterest.com/pin/335518241006685788/');
  });

  test('Generique : tracking retire, casse du chemin conservee', () {
    same('https://exemple.com/article?utm_source=x&fbclid=y',
        'https://www.exemple.com/article/');
    different('https://bit.ly/aBcD', 'https://bit.ly/AbCd');
  });

  test('Booking : dates, suivi et langue ignores', () {
    same('https://www.booking.com/hotel/fr/marriott-s-village-d-lle-de-france.fr.html?aid=304142&nad_id=a&srpvid=1',
        'https://www.booking.com/hotel/fr/marriott-s-village-d-lle-de-france.fr.html?aid=1&nad_id=b&checkin=2026-10-03');
    same('https://www.booking.com/hotel/fr/x.fr.html',
        'https://www.booking.com/hotel/fr/x.en-gb.html');
    different('https://www.booking.com/hotel/fr/x.fr.html',
        'https://www.booking.com/hotel/fr/y.fr.html');
  });

  test('Recherche Google : seule la requete compte', () {
    same('https://www.google.com/search?q=haaland&ie=UTF-8&client=safari#sv=abc',
        'https://www.google.fr/search?q=Haaland&ved=xyz&sxsrf=1');
    different('https://www.google.com/search?q=haaland',
        'https://www.google.com/search?q=mbappe');
  });

  test('Publicite : gclid, gbraid, gad_source, srsltid retires', () {
    same('https://boutique.ol.fr/fr/m.html?utm_source=g&gclid=1&gbraid=2&gad_source=1&gad_campaignid=3',
        'https://boutique.ol.fr/fr/m.html');
    same('https://www2.hm.com/fr_fr/index.html?srsltid=AU7gw4',
        'https://www2.hm.com/fr_fr/index.html');
    different('https://www2.hm.com/fr_fr/x.html?productId=1',
        'https://www2.hm.com/fr_fr/x.html?productId=2');
  });

  test('Google Images : meme page, parametres differents', () {
    same('https://www.google.com/imgres?imgurl=a&imgrefurl=https://www.goal.com/fr/news/x&kgs=1',
        'https://www.google.com/imgres?imgurl=a&imgrefurl=https://www.goal.com/fr/news/x&kgs=2');
  });
}
