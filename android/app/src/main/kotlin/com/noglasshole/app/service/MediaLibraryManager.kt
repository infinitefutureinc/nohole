package com.noglasshole.app.service

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.noglasshole.app.data.MediaItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

object MediaLibraryManager {

    private val IMAGE_PROJECTION = arrayOf(
        MediaStore.Images.Media._ID,
        MediaStore.Images.Media.DISPLAY_NAME,
        MediaStore.Images.Media.MIME_TYPE,
        MediaStore.Images.Media.DATE_ADDED,
        MediaStore.Images.Media.WIDTH,
        MediaStore.Images.Media.HEIGHT,
        MediaStore.Images.Media.BUCKET_DISPLAY_NAME
    )

    private val VIDEO_PROJECTION = arrayOf(
        MediaStore.Video.Media._ID,
        MediaStore.Video.Media.DISPLAY_NAME,
        MediaStore.Video.Media.MIME_TYPE,
        MediaStore.Video.Media.DATE_ADDED,
        MediaStore.Video.Media.WIDTH,
        MediaStore.Video.Media.HEIGHT,
        MediaStore.Video.Media.DURATION,
        MediaStore.Video.Media.BUCKET_DISPLAY_NAME
    )

    suspend fun fetchMedia(context: Context): List<MediaItem> = withContext(Dispatchers.IO) {
        val photos = fetchImages(context)
        val videos = fetchVideos(context)
        (photos + videos).sortedByDescending { it.dateAdded }
    }

    private fun fetchImages(context: Context): List<MediaItem> {
        val items = mutableListOf<MediaItem>()
        val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val sort = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        context.contentResolver.query(uri, IMAGE_PROJECTION, null, null, sort)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            val wCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.WIDTH)
            val hCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.HEIGHT)
            val bucketCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val name = cursor.getString(nameCol) ?: continue
                val bucket = cursor.getString(bucketCol) ?: ""
                val contentUri = Uri.withAppendedPath(uri, id.toString())
                val isGlasses = SmartGlassesDetector.isBucketSmartGlasses(bucket) ||
                        SmartGlassesDetector.isSmartGlassesMediaFast(
                            MediaItem(id, contentUri, name, cursor.getString(mimeCol) ?: "image/jpeg",
                                      cursor.getLong(dateCol), cursor.getInt(wCol), cursor.getInt(hCol))
                        )
                items.add(
                    MediaItem(
                        id = id,
                        uri = contentUri,
                        displayName = name,
                        mimeType = cursor.getString(mimeCol) ?: "image/jpeg",
                        dateAdded = cursor.getLong(dateCol),
                        width = cursor.getInt(wCol),
                        height = cursor.getInt(hCol),
                        isSmartGlasses = isGlasses
                    )
                )
            }
        }
        return items
    }

    private fun fetchVideos(context: Context): List<MediaItem> {
        val items = mutableListOf<MediaItem>()
        val uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val sort = "${MediaStore.Video.Media.DATE_ADDED} DESC"

        context.contentResolver.query(uri, VIDEO_PROJECTION, null, null, sort)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            val wCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val hCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val durCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val bucketCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val name = cursor.getString(nameCol) ?: continue
                val bucket = cursor.getString(bucketCol) ?: ""
                val contentUri = Uri.withAppendedPath(uri, id.toString())
                val isGlasses = SmartGlassesDetector.isBucketSmartGlasses(bucket) ||
                        SmartGlassesDetector.isSmartGlassesMediaFast(
                            MediaItem(id, contentUri, name, cursor.getString(mimeCol) ?: "video/mp4",
                                      cursor.getLong(dateCol), cursor.getInt(wCol), cursor.getInt(hCol))
                        )
                items.add(
                    MediaItem(
                        id = id,
                        uri = contentUri,
                        displayName = name,
                        mimeType = cursor.getString(mimeCol) ?: "video/mp4",
                        dateAdded = cursor.getLong(dateCol),
                        width = cursor.getInt(wCol),
                        height = cursor.getInt(hCol),
                        duration = cursor.getLong(durCol),
                        isSmartGlasses = isGlasses
                    )
                )
            }
        }
        return items
    }

    /** Save a processed bitmap to Pictures/NoGlasshole. */
    suspend fun saveImageToLibrary(context: Context, bitmap: Bitmap, originalName: String): Uri =
        withContext(Dispatchers.IO) {
            val filename = "noglasshole_${System.currentTimeMillis()}.jpg"
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_PICTURES}/NoGlasshole")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val resolver = context.contentResolver
            val insertUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Failed to create MediaStore entry")

            resolver.openOutputStream(insertUri)?.use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(insertUri, values, null, null)
            }
            insertUri
        }
}
