package com.saatxi.eatapp.ui.common

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper

/**
 * `LocalContext.current` inside a composable is not always the Activity itself
 * (it can be wrapped, e.g. in a `ContextThemeWrapper`), so this walks the
 * wrapper chain to find it.
 */
tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
