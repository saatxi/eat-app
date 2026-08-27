package com.albertferran.eatapp.data.sync

import com.albertferran.eatapp.BuildConfig

/**
 * Where the `.db` is downloaded from.
 *
 * The value is generated per build type in `app/build.gradle.kts`: release always
 * uses the public raw GitHub URL hardcoded there, while a debug build can be
 * pointed at a branch or a fork through `eatapp.database.url` in
 * `local.properties` or the `EATAPP_DATABASE_URL` environment variable. It must
 * be public HTTPS either way — nothing requiring authentication belongs here.
 */
object RemoteConfig {
    val DATABASE_URL: String = BuildConfig.DATABASE_URL
}
