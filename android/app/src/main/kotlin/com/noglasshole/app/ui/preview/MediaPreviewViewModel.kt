package com.noglasshole.app.ui.preview

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.noglasshole.app.data.AppSettingsData
import com.noglasshole.app.data.AppSettingsRepository
import com.noglasshole.app.data.MediaItem
import com.noglasshole.app.service.DetectedFace
import com.noglasshole.app.service.FaceDetectionService
import com.noglasshole.app.service.ImageBlurProcessor
import com.noglasshole.app.service.MediaLibraryManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class PreviewUiState(
    val item: MediaItem? = null,
    val originalBitmap: Bitmap? = null,
    val processedBitmap: Bitmap? = null,
    val detectedFaces: List<DetectedFace> = emptyList(),
    val isProcessing: Boolean = false,
    val isSaving: Boolean = false,
    val savedSuccessfully: Boolean = false,
    val error: String? = null,
    val settings: AppSettingsData = AppSettingsData()
)

class MediaPreviewViewModel(app: Application) : AndroidViewModel(app) {

    private val _uiState = MutableStateFlow(PreviewUiState())
    val uiState: StateFlow<PreviewUiState> = _uiState.asStateFlow()

    private val settingsRepo = AppSettingsRepository(app)

    fun loadMediaById(mediaId: Long) {
        viewModelScope.launch(Dispatchers.IO) {
            // Query MediaStore for this specific ID
            val context = getApplication<Application>()
            val uri = android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val itemUri = android.net.Uri.withAppendedPath(uri, mediaId.toString())
            val cursor = context.contentResolver.query(
                itemUri,
                arrayOf(
                    android.provider.MediaStore.Images.Media._ID,
                    android.provider.MediaStore.Images.Media.DISPLAY_NAME,
                    android.provider.MediaStore.Images.Media.MIME_TYPE,
                    android.provider.MediaStore.Images.Media.DATE_ADDED,
                    android.provider.MediaStore.Images.Media.WIDTH,
                    android.provider.MediaStore.Images.Media.HEIGHT
                ),
                null, null, null
            )
            val item = cursor?.use { c ->
                if (c.moveToFirst()) {
                    MediaItem(
                        id = mediaId,
                        uri = itemUri,
                        displayName = c.getString(c.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.DISPLAY_NAME)) ?: "",
                        mimeType = c.getString(c.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.MIME_TYPE)) ?: "image/jpeg",
                        dateAdded = c.getLong(c.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.DATE_ADDED)),
                        width = c.getInt(c.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.WIDTH)),
                        height = c.getInt(c.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.HEIGHT))
                    )
                } else null
            } ?: return@launch
            loadMedia(item)
        }
    }

    fun loadMedia(item: MediaItem) {
        viewModelScope.launch {
            val settings = settingsRepo.settings.first()
            _uiState.value = PreviewUiState(item = item, isProcessing = true, settings = settings)
            try {
                val bitmap = loadBitmap(item) ?: throw IllegalStateException("Failed to load image")
                val faces = FaceDetectionService.detectFaces(bitmap)
                val processed = ImageBlurProcessor.blurFaces(
                    bitmap, faces, settings.blurStyle, settings.blurIntensity, settings.maskScale
                )
                _uiState.value = _uiState.value.copy(
                    originalBitmap = bitmap,
                    processedBitmap = processed,
                    detectedFaces = faces,
                    isProcessing = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isProcessing = false,
                    error = "Failed to process image: ${e.message}"
                )
            }
        }
    }

    fun toggleFaceBlur(faceId: Int) {
        val current = _uiState.value
        val updated = current.detectedFaces.map { f ->
            if (f.id == faceId) f.copy(isBlurred = !f.isBlurred) else f
        }
        _uiState.value = current.copy(detectedFaces = updated)
        reprocess(updated)
    }

    private fun reprocess(faces: List<DetectedFace>) {
        val state = _uiState.value
        val bitmap = state.originalBitmap ?: return
        viewModelScope.launch(Dispatchers.Default) {
            val processed = ImageBlurProcessor.blurFaces(
                bitmap, faces, state.settings.blurStyle,
                state.settings.blurIntensity, state.settings.maskScale
            )
            _uiState.value = _uiState.value.copy(processedBitmap = processed)
        }
    }

    fun saveImage() {
        val state = _uiState.value
        val bitmap = state.processedBitmap ?: return
        val item = state.item ?: return
        viewModelScope.launch {
            _uiState.value = state.copy(isSaving = true, savedSuccessfully = false, error = null)
            try {
                MediaLibraryManager.saveImageToLibrary(getApplication(), bitmap, item.displayName)
                _uiState.value = _uiState.value.copy(isSaving = false, savedSuccessfully = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isSaving = false,
                    error = "Save failed: ${e.message}"
                )
            }
        }
    }

    private suspend fun loadBitmap(item: MediaItem): Bitmap? = withContext(Dispatchers.IO) {
        try {
            getApplication<Application>().contentResolver.openInputStream(item.uri)?.use { stream ->
                BitmapFactory.decodeStream(stream)
            }
        } catch (_: Exception) { null }
    }
}
