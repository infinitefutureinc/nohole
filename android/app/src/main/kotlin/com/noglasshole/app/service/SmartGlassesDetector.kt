package com.noglasshole.app.service

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import com.noglasshole.app.data.MediaItem

/**
 * Detects photos/videos taken with smart glasses (Ray-Ban Meta, Samsung Galaxy Glasses).
 *
 * Two-pass strategy:
 *  1. Fast pass: album/bucket name + filename pattern (no I/O)
 *  2. Deep pass: EXIF Make/Model read (I/O, for images only)
 */
object SmartGlassesDetector {

    // ---------------------------------------------------------------------------
    // Ray-Ban Meta — confirmed from real device EXIF
    // ---------------------------------------------------------------------------
    private val META_MAKE_KEYWORDS = listOf("meta ai")
    private val META_MODEL_KEYWORDS = listOf("ray-ban meta", "meta smart glasses")

    // Filename patterns injected by the Meta AI companion app
    private val META_FILENAME_PATTERNS = listOf(
        "singular_display",   // primary signal — appears in all Ray-Ban Meta filenames
        "od_video-"           // video pattern: od_video-NNN_...
    )

    // MediaStore bucket names used by the Meta AI app on Android
    private val META_BUCKET_NAMES = setOf(
        "meta ai", "meta view", "ray-ban meta",
        "ray-ban stories", "ray-ban"
    )

    // ---------------------------------------------------------------------------
    // Samsung Galaxy Glasses — pre-release estimates (update when hardware ships)
    // EXIF Make = "SAMSUNG", Model contains one of these strings
    // ---------------------------------------------------------------------------
    private val SAMSUNG_GLASSES_MODEL_KEYWORDS = listOf(
        "galaxy glasses",
        "sm-r110",  // speculative model number — verify when devices are available
        "sm-r120"
    )
    private val SAMSUNG_BUCKET_NAMES = setOf(
        "galaxy glasses", "samsung glasses"
    )

    // ---------------------------------------------------------------------------

    /**
     * Quick check using only MediaStore metadata (no file I/O).
     * Bucket/album name → filename pattern.
     */
    fun isSmartGlassesMediaFast(item: MediaItem): Boolean {
        val bucket = item.displayName.lowercase() // displayName is filename here
        val filename = item.displayName.lowercase()

        // Bucket detection happens at MediaItem construction via fetchMedia()
        // Here we only check filename patterns
        for (pattern in META_FILENAME_PATTERNS) {
            if (filename.contains(pattern)) return true
        }
        if (filename.startsWith("photo-") && (filename.endsWith(".heic") || filename.endsWith(".jpg"))) {
            return true
        }
        return false
    }

    /**
     * Check whether a MediaStore bucket name matches a known smart-glasses album.
     */
    fun isBucketSmartGlasses(bucketName: String): Boolean {
        val lower = bucketName.lowercase()
        return META_BUCKET_NAMES.any { lower.contains(it) } ||
               SAMSUNG_BUCKET_NAMES.any { lower.contains(it) }
    }

    /**
     * Deep EXIF check — reads Make/Model from the image file.
     * Call this only for images; it performs file I/O.
     */
    fun checkExifForSmartGlasses(context: Context, uri: Uri): Boolean {
        return try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val exif = ExifInterface(stream)
                val make = exif.getAttribute(ExifInterface.TAG_MAKE)?.lowercase() ?: ""
                val model = exif.getAttribute(ExifInterface.TAG_MODEL)?.lowercase() ?: ""

                // Ray-Ban Meta
                if (META_MAKE_KEYWORDS.any { make.contains(it) }) return true
                if (META_MODEL_KEYWORDS.any { model.contains(it) }) return true

                // Samsung Galaxy Glasses
                if (make.contains("samsung") &&
                    SAMSUNG_GLASSES_MODEL_KEYWORDS.any { model.contains(it) }) return true

                false
            } ?: false
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Full detection: fast check first, EXIF fallback for images.
     */
    fun isSmartGlassesMedia(context: Context, item: MediaItem): Boolean {
        if (isSmartGlassesMediaFast(item)) return true
        if (item.isPhoto) return checkExifForSmartGlasses(context, item.uri)
        return false
    }
}
