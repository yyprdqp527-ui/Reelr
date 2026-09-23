package com.room79.reelr

import android.annotation.SuppressLint
import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONTokener
import java.net.URL

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Apercu de lien : equivalent Android du LinkPresentation d'iOS.
        // Secours pour les pages que l'extraction HTTP de l'app ne sait pas
        // lire (Reddit, pages de pub...). Meme canal, meme methode que sur iOS.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reelr/link_preview")
            .setMethodCallHandler { call, result ->
                if (call.method != "fetch") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.arguments as? String
                if (url == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                LinkPreviewFetcher(this).fetch(url) { payload -> result.success(payload) }
            }
    }
}

/**
 * Charge la page dans une WebView invisible (moteur de Chrome, JavaScript
 * active) puis lit og:title et og:image dans le document rendu. Renvoie
 * l'URL de l'image, que l'app telecharge ensuite elle-meme.
 */
class LinkPreviewFetcher(private val activity: FlutterActivity) {
    private val handler = Handler(Looper.getMainLooper())
    private var done = false

    @SuppressLint("SetJavaScriptEnabled")
    fun fetch(url: String, completion: (Map<String, String>?) -> Unit) {
        handler.post {
            val webView = WebView(activity)
            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.settings.blockNetworkImage = true

            fun finish(payload: Map<String, String>?) {
                if (done) return
                done = true
                completion(payload)
                webView.stopLoading()
                webView.destroy()
            }

            val timeout = Runnable { finish(null) }
            handler.postDelayed(timeout, 15000)

            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, loadedUrl: String) {
                    // Laisse au JavaScript de la page le temps d'injecter
                    // ses balises (pages rendues cote client).
                    handler.postDelayed({
                        if (done) return@postDelayed
                        view.evaluateJavascript(EXTRACT_JS) { raw ->
                            handler.removeCallbacks(timeout)
                            finish(parse(raw, view.url ?: loadedUrl))
                        }
                    }, 1500)
                }
            }
            webView.loadUrl(url)
        }
    }

    companion object {
        private const val EXTRACT_JS = """(function(){
  function m(k){
    var e=document.querySelector('meta[property="'+k+'"],meta[name="'+k+'"]');
    return e?e.getAttribute('content'):null;
  }
  return JSON.stringify({
    title: m('og:title')||document.title||null,
    image: m('og:image')||m('og:image:url')||m('twitter:image')||null
  });
})()"""

        fun parse(raw: String?, pageUrl: String): Map<String, String>? {
            if (raw == null || raw == "null") return null
            return try {
                // evaluateJavascript renvoie la valeur encodee en JSON : ici
                // une chaine, elle-meme du JSON.
                val json = JSONObject(JSONTokener(raw).nextValue() as String)
                val payload = mutableMapOf<String, String>()
                json.optString("title").takeIf { it.isNotBlank() && it != "null" }
                    ?.let { payload["title"] = it }
                json.optString("image").takeIf { it.isNotBlank() && it != "null" }
                    ?.let { image ->
                        // Image relative (« /files/x.jpg ») : resolue contre la page.
                        val absolute = try { URL(URL(pageUrl), image).toString() } catch (e: Exception) { image }
                        if (absolute.startsWith("http")) payload["imageUrl"] = absolute
                    }
                if (payload.isEmpty()) null else payload
            } catch (e: Exception) {
                null
            }
        }
    }
}
