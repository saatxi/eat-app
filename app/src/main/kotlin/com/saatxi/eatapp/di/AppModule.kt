package com.saatxi.eatapp.di

import android.content.Context
import com.saatxi.eatapp.data.local.EatAppDatabase
import com.saatxi.eatapp.data.local.buildEatAppDatabase
import com.saatxi.eatapp.data.prefs.AppCompatLocaleManager
import com.saatxi.eatapp.data.prefs.AppLocaleManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton
import kotlin.random.Random

/**
 * Provides the dependencies that don't have a natural constructor-injectable
 * implementation to bind ([EatAppDatabase] is built via a factory function,
 * [AppLocaleManager] wraps a stateless singleton with no dependencies of its
 * own). Interface-to-implementation bindings ([RestaurantRepository],
 * [UserPreferencesRepository], [RestaurantPhotoStorage]) live in
 * [BindsModule] instead.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideEatAppDatabase(@ApplicationContext context: Context): EatAppDatabase =
        buildEatAppDatabase(context)

    @Provides
    @Singleton
    fun provideAppLocaleManager(): AppLocaleManager = AppCompatLocaleManager()

    /** Roulette's real pick source; tests construct `RouletteViewModel` directly with a seeded one instead. */
    @Provides
    fun provideRandom(): Random = Random.Default
}
