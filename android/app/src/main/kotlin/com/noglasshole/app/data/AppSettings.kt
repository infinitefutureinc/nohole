package com.noglasshole.app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "noglasshole_settings")

data class AppSettingsData(
    val blurIntensity: Double = 50.0,
    val blurStyle: BlurStyle = BlurStyle.GAUSSIAN,
    val selectiveBlurEnabled: Boolean = true,
    val maskScale: Double = 1.3
)

class AppSettingsRepository(private val context: Context) {

    private object Keys {
        val BLUR_INTENSITY = doublePreferencesKey("blur_intensity")
        val BLUR_STYLE = stringPreferencesKey("blur_style")
        val SELECTIVE_BLUR = booleanPreferencesKey("selective_blur")
        val MASK_SCALE = doublePreferencesKey("mask_scale")
    }

    val settings: Flow<AppSettingsData> = context.dataStore.data.map { prefs ->
        AppSettingsData(
            blurIntensity = prefs[Keys.BLUR_INTENSITY] ?: 50.0,
            blurStyle = BlurStyle.fromKey(prefs[Keys.BLUR_STYLE] ?: ""),
            selectiveBlurEnabled = prefs[Keys.SELECTIVE_BLUR] ?: true,
            maskScale = prefs[Keys.MASK_SCALE] ?: 1.3
        )
    }

    suspend fun updateBlurIntensity(value: Double) {
        context.dataStore.edit { it[Keys.BLUR_INTENSITY] = value }
    }

    suspend fun updateBlurStyle(style: BlurStyle) {
        context.dataStore.edit { it[Keys.BLUR_STYLE] = style.key }
    }

    suspend fun updateSelectiveBlur(enabled: Boolean) {
        context.dataStore.edit { it[Keys.SELECTIVE_BLUR] = enabled }
    }

    suspend fun updateMaskScale(value: Double) {
        context.dataStore.edit { it[Keys.MASK_SCALE] = value }
    }
}
