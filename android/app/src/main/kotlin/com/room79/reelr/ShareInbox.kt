package com.room79.reelr

import android.content.Context
import org.json.JSONArray

/**
 * Boite de partage Android : equivalent de la boite de l'extension iOS.
 * Le recepteur invisible y range les liens, l'app les lit a son ouverture
 * (canal « reelr/share_inbox », meme contrat que sur iOS).
 */
object ShareInbox {
    private const val PREFS = "reelr_share_inbox"
    private const val KEY_URLS = "urls"
    private const val KEY_LANG = "lang"

    private fun norm(u: String) = u.trim().lowercase().trimEnd('/')

    /** Ajoute [raw] ; false s'il y est deja. */
    @Synchronized
    fun add(ctx: Context, raw: String): Boolean {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(p.getString(KEY_URLS, "[]"))
        for (i in 0 until arr.length()) {
            if (norm(arr.getString(i)) == norm(raw)) return false
        }
        arr.put(raw)
        // commit() : ecriture immediate, l'activite se ferme juste apres.
        p.edit().putString(KEY_URLS, arr.toString()).commit()
        return true
    }

    /** Renvoie les liens en attente et vide la boite. */
    @Synchronized
    fun drain(ctx: Context): List<String> {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(p.getString(KEY_URLS, "[]"))
        val out = ArrayList<String>(arr.length())
        for (i in 0 until arr.length()) out.add(arr.getString(i))
        p.edit().remove(KEY_URLS).commit()
        return out
    }

    fun setLang(ctx: Context, lang: String?) {
        if (lang == null) return
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_LANG, lang).apply()
    }

    /** Langue choisie dans l'app, sinon celle du telephone. */
    fun lang(ctx: Context): String =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_LANG, null) ?: java.util.Locale.getDefault().language
}
