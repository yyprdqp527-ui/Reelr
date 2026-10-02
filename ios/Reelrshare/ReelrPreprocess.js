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

    // Pas d'image declaree : la plus grande image visible de la page.
    if (!image) {
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
      image = best;
    }

    var title =
      meta('meta[property="og:title"]') ||
      meta('meta[name="twitter:title"]') ||
      document.title || '';

    args.completionFunction({
      url: document.URL,
      title: title,
      image: absolute(image)
    });
  }
};

var ExtensionPreprocessingJS = new ReelrPreprocess();
