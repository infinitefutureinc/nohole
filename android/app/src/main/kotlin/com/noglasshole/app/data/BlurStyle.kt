package com.noglasshole.app.data

enum class BlurStyle(val key: String, val displayName: String) {
    GAUSSIAN("gaussian", "Gaussian Blur"),
    PIXELATE("pixelate", "Pixelate"),
    SOLID_BLACK("solid_black", "Solid Black");

    companion object {
        fun fromKey(key: String): BlurStyle =
            entries.firstOrNull { it.key == key } ?: GAUSSIAN
    }
}
