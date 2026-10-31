// Reelr : lit l'image et le titre de la page affichee dans Safari au moment
// du partage. La page est deja chargee par une vraie personne : elle est
// passee a travers les protections anti-robots (H&M...), ce que ni l'app ni
// un serveur ne peuvent faire.
var ReelrPreprocess = function () {};

ReelrPreprocess.prototype = {
  run: function (args) {
    function meta(selector) {
      var el = document.querySelector(selector);
      if (!el) return '';
      return el.getAttribute('content') || el.getAttribute('href') || '';
    }
    function absolute(u) {
      try { return u ? new URL(u, document.baseURI).href : ''; } catch (e) { return ''; }
    }

    var image =
      meta('meta[property="og:image"]') ||
      meta('meta[property="og:image:secure_url"]') ||
      meta('meta[name="twitter:image"]') ||
      meta('meta[name="twitter:image:src"]') ||
      meta('link[rel="image_src"]');

    // Plus grande image visible de la page : secours si l'image declaree
    // est absente, morte (404) ou n'est qu'un logo.
    var largest = '';
    {
      var best = '';
      var bestArea = 0;
      var imgs = document.images;
      for (var i = 0; i < imgs.length; i++) {
        var img = imgs[i];
        var r = img.getBoundingClientRect();
        var area = r.width * r.height;
        var src = img.currentSrc || img.src || '';
        if (src.indexOf('data:') === 0) continue;
        if (r.width >= 200 && r.height >= 150 && area > bestArea) {
          bestArea = area;
          best = src;
        }
      }
      largest = best;
    }

    var title =
      meta('meta[property="og:title"]') ||
      meta('meta[name="twitter:title"]') ||
      document.title || '';

    // TikTok dans Safari : l'adresse reste celle de la 1re video quand on
    // fait defiler les suivantes. On prend la video visible a l'ecran.
    function tiktokVisibleUrl() {
      var vids = document.querySelectorAll('video');
      var best = null, bestArea = 0;
      var vw = window.innerWidth, vh = window.innerHeight;
      for (var i = 0; i < vids.length; i++) {
        var r = vids[i].getBoundingClientRect();
        var w = Math.max(0, Math.min(r.right, vw) - Math.max(r.left, 0));
        var h = Math.max(0, Math.min(r.bottom, vh) - Math.max(r.top, 0));
        if (w * h > bestArea) { bestArea = w * h; best = vids[i]; }
      }
      if (!best) return '';
      var user = (location.pathname.match(/\/@([^\/?#]+)/) || [])[1] || '';
      for (var el = best, d = 0; el && d < 15; el = el.parentElement, d++) {
        var idm = (el.id || '').match(/(\d{18,20})/);
        if (idm && user) {
          return 'https://www.tiktok.com/@' + user + '/video/' + idm[1];
        }
        var links = el.querySelectorAll ?
          el.querySelectorAll('a[href*="/video/"], a[href*="/photo/"]') : [];
        var found = {};
        var n = 0, first = '';
        for (var j = 0; j < links.length; j++) {
          var m = (links[j].getAttribute('href') || '')
            .match(/\/@([^\/?#]+)\/(video|photo)\/(\d{15,20})/);
          if (m && !found[m[3]]) {
            found[m[3]] = 1;
            n++;
            if (!first) first = 'https://www.tiktok.com/@' + m[1] + '/' + m[2] + '/' + m[3];
          }
        }
        if (n === 1) return first;
        if (n > 1) break;
      }
      return '';
    }

    var pageUrl = document.URL;
    if (/(^|\.)tiktok\.com$/.test(location.hostname)) {
      var visible = tiktokVisibleUrl();
      if (visible && visible.indexOf(location.pathname) === -1) {
        pageUrl = visible;
        // Titre et image lus dans la page = ceux de la 1re video.
        title = '';
        image = '';
        largest = '';
      }
    }

    // Video TikTok, YouTube Shorts ou Instagram ouverte DANS Google :
    // l'adresse est celle de la recherche. On prend le lien de la video
    // visible a l'ecran.
    function googleVideoUrl() {
      var re = /^https?:\/\/(www\.|m\.|vm\.)?(tiktok\.com\/@[^\/]+\/(video|photo)\/\d+|youtube\.com\/shorts\/[\w-]+|instagram\.com\/(reel|p)\/[\w-]+)/;
      var links = document.querySelectorAll('a[href]');
      var vw = window.innerWidth, vh = window.innerHeight;
      var best = '', bestArea = 0;
      for (var i = 0; i < links.length; i++) {
        var href = links[i].href || '';
        var wrapped = href.match(/[?&](?:q|url)=([^&]+)/);
        if (wrapped && !re.test(href)) {
          try { href = decodeURIComponent(wrapped[1]); } catch (e) {}
        }
        if (!re.test(href)) continue;
        var r = links[i].getBoundingClientRect();
        var w = Math.max(0, Math.min(r.right, vw) - Math.max(r.left, 0));
        var h = Math.max(0, Math.min(r.bottom, vh) - Math.max(r.top, 0));
        if (w * h > bestArea) { bestArea = w * h; best = href; }
      }
      return best;
    }
    if (/(^|\.)google\.[a-z.]+$/.test(location.hostname)) {
      var gVideo = googleVideoUrl();
      if (gVideo) {
        pageUrl = gVideo;
        title = '';
        image = '';
        largest = '';
      }
    }

    args.completionFunction({
      url: pageUrl,
      title: title,
      image: absolute(image || largest),
      image2: absolute(largest)
    });
  }
};

var ExtensionPreprocessingJS = new ReelrPreprocess();
