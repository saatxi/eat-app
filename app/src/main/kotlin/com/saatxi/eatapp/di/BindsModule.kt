package com.saatxi.eatapp.di

import com.saatxi.eatapp.data.photo.AndroidRestaurantPhotoStorage
import com.saatxi.eatapp.data.photo.RestaurantPhotoStorage
import com.saatxi.eatapp.data.prefs.DataStoreUserPreferencesRepository
import com.saatxi.eatapp.data.prefs.UserPreferencesRepository
import com.saatxi.eatapp.data.repository.RestaurantRepository
import com.saatxi.eatapp.data.repository.RoomRestaurantRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/** Interface-to-implementation bindings — see [AppModule] for the `@Provides` side. */
@Module
@InstallIn(SingletonComponent::class)
abstract class BindsModule {

    @Binds
    @Singleton
    abstract fun bindRestaurantRepository(impl: RoomRestaurantRepository): RestaurantRepository

    @Binds
    @Singleton
    abstract fun bindUserPreferencesRepository(impl: DataStoreUserPreferencesRepository): UserPreferencesRepository

    @Binds
    abstract fun bindRestaurantPhotoStorage(impl: AndroidRestaurantPhotoStorage): RestaurantPhotoStorage
}
