package com.saatxi.eatapp.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PhotoDao {

    @Query("SELECT * FROM photos WHERE restaurantId = :restaurantId ORDER BY position ASC")
    fun observePhotosForRestaurant(restaurantId: String): Flow<List<Photo>>

    @Query("SELECT * FROM photos WHERE visitId = :visitId ORDER BY position ASC")
    fun observePhotosForVisit(visitId: String): Flow<List<Photo>>

    /** One-shot: the first restaurant-level photo, if any — used to prefill the edit form. */
    @Query("SELECT * FROM photos WHERE restaurantId = :restaurantId ORDER BY position ASC LIMIT 1")
    suspend fun getFirstPhotoForRestaurant(restaurantId: String): Photo?

    @Insert
    suspend fun insert(photo: Photo)

    @Query("DELETE FROM photos WHERE id = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM photos WHERE restaurantId = :restaurantId")
    suspend fun deleteAllForRestaurant(restaurantId: String)
}
