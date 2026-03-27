package com.noglasshole.app.data

import android.net.Uri

data class MediaItem(
    val id: Long,
    val uri: Uri,
    val displayName: String,
    val mimeType: String,
    val dateAdded: Long,
    val width: Int,
    val height: Int,
    val duration: Long = 0L, // ms, 0 for images
    val isSmartGlasses: Boolean = false
) {
    val isVideo: Boolean get() = mimeType.startsWith("video/")
    val isPhoto: Boolean get() = mimeType.startsWith("image/")
    val aspectRatio: Float get() = if (height > 0) width.toFloat() / height.toFloat() else 1f
}
