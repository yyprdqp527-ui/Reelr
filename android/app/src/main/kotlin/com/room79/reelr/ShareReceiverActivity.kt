package com.room79.reelr

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Recepteur de partage invisible (equivalent de l'extension de partage iOS).
 * Range le lien dans la boite, affiche « Ajoute a Reelr » une seconde puis se
 * ferme : la cliente reste dans l'appli d'ou elle partage et peut enchainer.
 */
class ShareReceiverActivity : Activity() {
    private companion object {
        val URL_RE = Regex("https?://\\S+")
        const val SHOW_MS = 900L
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent?.getStringExtra(Intent.EXTRA_TEXT)
        val url = text?.let { URL_RE.find(it)?.value?.trimEnd('.', ',', ')', ']', '!', '?', ';') }
        if (intent?.action != Intent.ACTION_SEND || url.isNullOrBlank()) {
            finish()
            return
        }
        ShareInbox.add(this, url)
        showCard()
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun showCard() {
        val fr = ShareInbox.lang(this) == "fr"

        val icon = ImageView(this).apply {
            setImageDrawable(packageManager.getApplicationIcon(packageName))
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(44))
        }
        val title = TextView(this).apply {
            text = if (fr) "Ajouté à Reelr" else "Added to Reelr"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        val subtitle = TextView(this).apply {
            text = if (fr) "Inbox mis à jour" else "Inbox updated"
            setTextColor(0xB3FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        }
        val texts = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), 0, 0, 0)
            addView(title)
            addView(subtitle)
        }
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(20), dp(16), dp(26), dp(16))
            background = GradientDrawable().apply {
                setColor(0xF21C1C24.toInt())
                cornerRadius = dp(22).toFloat()
            }
            elevation = dp(12).toFloat()
            addView(icon)
            addView(texts)
            alpha = 0f
        }
        val root = FrameLayout(this)
        root.addView(
            card,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
        setContentView(root)

        card.animate().alpha(1f).setDuration(120).start()
        Handler(Looper.getMainLooper()).postDelayed({
            card.animate().alpha(0f).setDuration(200).withEndAction {
                finish()
                overridePendingTransition(0, 0)
            }.start()
        }, SHOW_MS)
    }
}
