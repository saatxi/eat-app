package com.saatxi.eatapp.ui.common

import android.content.Context
import android.content.Intent
import com.saatxi.eatapp.data.share.RestaurantExport
import com.saatxi.eatapp.data.share.writeRestaurantShareFile

/**
 * MIME type used both for the outgoing share `Intent` and for the manifest's
 * `<intent-filter>` that lets a received file reopen the app. A plain,
 * standard `application/json` — not a custom type — is what makes "Open with
 * EatApp" reliably show up for a file forwarded through another app, since
 * those apps generally can't be trusted to preserve a custom MIME type.
 */
const val RESTAURANT_SHARE_MIME_TYPE = "application/json"

/** Opens the system share sheet with [restaurants] as a small JSON attachment. */
fun Context.shareRestaurants(restaurants: List<RestaurantExport>) {
    val uri = writeRestaurantShareFile(this, restaurants)
    val sendIntent = Intent(Intent.ACTION_SEND).apply {
        type = RESTAURANT_SHARE_MIME_TYPE
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    startActivity(Intent.createChooser(sendIntent, null))
}
